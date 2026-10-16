package duoc.rutaexpress.shipments.messaging;

import static org.junit.jupiter.api.Assertions.*;
import duoc.rutaexpress.shipments.client.CatalogClient;
import duoc.rutaexpress.shipments.domain.*;
import duoc.rutaexpress.shipments.dto.ChangeShipmentStatusRequest;
import duoc.rutaexpress.shipments.exception.BusinessRuleException;
import duoc.rutaexpress.shipments.repository.ShipmentRepository;
import duoc.rutaexpress.shipments.service.ShipmentService;
import java.math.BigDecimal;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.*;

@DataJpaTest(properties = {"spring.datasource.password=", "app.messaging.enabled=true"})
@Import({ShipmentService.class, OutboxRecorder.class, OutboxTransactionTest.JsonConfig.class})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class OperatorAcceptanceTransactionTest {
    @Autowired ShipmentService service;
    @Autowired ShipmentRepository shipments;
    @Autowired OutboxRepository outbox;
    @MockitoBean CatalogClient catalog;
    @AfterEach void cleanTestDatabase() { outbox.deleteAll(); shipments.deleteAll(); }

    @Test void concurrentOperatorsProduceOnlyOneAcceptanceAndOneOutboxEvent() throws Exception {
        Shipment request = shipments.saveAndFlush(new Shipment("RX-OP-CONCURRENT", "Ficticio", "test@example.test",
                "Origen", "Destino", BigDecimal.ONE, 1L, "Express"));
        CountDownLatch start = new CountDownLatch(1);
        Callable<Boolean> accept = () -> {
            start.await();
            try { service.changeStatus(request.getId(), new ChangeShipmentStatusRequest(ShipmentStatus.ACEPTADO)); return true; }
            catch (BusinessRuleException conflict) { return false; }
        };
        try (var threads = Executors.newFixedThreadPool(2)) {
            var first = threads.submit(accept); var second = threads.submit(accept); start.countDown();
            int accepted = (first.get(15, TimeUnit.SECONDS) ? 1 : 0) + (second.get(15, TimeUnit.SECONDS) ? 1 : 0);
            assertEquals(1, accepted);
        }
        assertEquals(ShipmentStatus.ACEPTADO, shipments.findById(request.getId()).orElseThrow().getEstado());
        assertEquals(1, outbox.count());
        assertEquals("shipment.status_changed", outbox.findAll().getFirst().getEventType());
    }
}
