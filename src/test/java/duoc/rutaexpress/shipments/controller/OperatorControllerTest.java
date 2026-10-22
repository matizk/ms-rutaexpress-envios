package duoc.rutaexpress.shipments.controller;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import duoc.rutaexpress.shipments.domain.ShipmentStatus;
import duoc.rutaexpress.shipments.dto.ChangeShipmentStatusRequest;
import duoc.rutaexpress.shipments.security.OperatorSecurity;
import duoc.rutaexpress.shipments.service.ShipmentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(OperatorController.class)
@Import(OperatorSecurity.class)
class OperatorControllerTest {
    @Autowired MockMvc mvc;
    @MockitoBean ShipmentService service;
    @MockitoBean JwtDecoder decoder;

    @Test void deniesAnonymousAndNonOperator() throws Exception {
        mvc.perform(get("/api/operator/shipments")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/operator/shipments/1/accept").with(jwt()
                .authorities(new SimpleGrantedAuthority("ROLE_USER")))).andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }
    @Test void listsPendingRequestsAndAllowsOnlyAcceptanceAction() throws Exception {
        mvc.perform(get("/api/operator/shipments").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_OPERATOR"))))
                .andExpect(status().isOk());
        verify(service).findAll(ShipmentStatus.CREADO, null, null);
        mvc.perform(post("/api/operator/shipments/1/accept").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_OPERATOR"))))
                .andExpect(status().isOk());
        verify(service).changeStatus(1L, new ChangeShipmentStatusRequest(ShipmentStatus.ACEPTADO));
        mvc.perform(delete("/api/operator/shipments/1").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_OPERATOR"))))
                .andExpect(status().isForbidden());
    }
}
