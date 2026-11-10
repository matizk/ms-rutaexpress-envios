package duoc.rutaexpress.shipments.messaging;

import duoc.rutaexpress.shipments.client.CatalogClient;
import duoc.rutaexpress.shipments.client.CatalogServiceSnapshot;
import duoc.rutaexpress.shipments.domain.Shipment;
import duoc.rutaexpress.shipments.repository.ShipmentRepository;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:customer-flow",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
    "app.reporting.enabled=true",
    "app.messaging.enabled=false"
})
@AutoConfigureMockMvc
class CustomerShipmentFlowTest {
    private static final String PATH = "/api/customer/shipments";
    private static final String REQUEST = """
            {"nombreDestinatario":"Destinatario de prueba","emailDestinatario":"entregas@example.test",
             "direccionOrigen":"Santiago","direccionDestino":"Valparaíso","pesoKg":1.5,"servicioId":1}
            """;
    @Autowired MockMvc mvc;
    @Autowired ShipmentRepository shipments;
    @Autowired ReportOutboxRepository reportEvents;
    @MockitoBean CatalogClient catalog;
    @MockitoBean JwtDecoder decoder;
    @MockitoBean ReportEventPublisher publisher;

    @Test void customerOrdersStayPrivateAndEnterTheReportingOutbox() throws Exception {
        when(decoder.decode("cliente-a")).thenReturn(customer("cliente-a"));
        when(decoder.decode("cliente-b")).thenReturn(customer("cliente-b"));
        when(catalog.reserveCapacity(1L)).thenReturn(new CatalogServiceSnapshot(1L, "Express", 9));
        shipments.saveAndFlush(new Shipment("RX-LEGACY", "Envío anterior", "entregas@example.test",
                "Santiago", "Valparaíso", BigDecimal.ONE, 1L, "Express"));

        mvc.perform(get(PATH)).andExpect(status().isUnauthorized());
        mvc.perform(post(PATH).header("Authorization", "Bearer cliente-a")
                .contentType(MediaType.APPLICATION_JSON).content(REQUEST))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.estado").value("CREADO"))
                .andExpect(jsonPath("$.codigoSeguimiento").isNotEmpty());
        mvc.perform(get(PATH).header("Authorization", "Bearer cliente-b"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
        mvc.perform(post(PATH).header("Authorization", "Bearer cliente-b")
                .contentType(MediaType.APPLICATION_JSON).content(REQUEST.replace("Valparaíso", "Rancagua")))
                .andExpect(status().isCreated());

        mvc.perform(get(PATH).header("Authorization", "Bearer cliente-a"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].direccionDestino").value("Valparaíso"));
        mvc.perform(get(PATH).header("Authorization", "Bearer cliente-b"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].direccionDestino").value("Rancagua"));
        mvc.perform(put(PATH + "/1/status").header("Authorization", "Bearer cliente-a"))
                .andExpect(status().isForbidden());

        assertEquals(2, reportEvents.count());
        for (ReportOutboxEvent event : reportEvents.findAll()) {
            assertFalse(event.payload().contains("entregas@example.test"));
            assertFalse(event.payload().contains("cliente-a"));
            assertFalse(event.payload().contains("cliente-b"));
        }
    }

    private static Jwt customer(String subject) {
        return Jwt.withTokenValue(subject).header("alg", "RS256").subject(subject).build();
    }
}
