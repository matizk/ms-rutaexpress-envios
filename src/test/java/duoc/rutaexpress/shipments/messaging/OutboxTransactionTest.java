package duoc.rutaexpress.shipments.messaging;

import static org.junit.jupiter.api.Assertions.*;
import duoc.rutaexpress.shipments.domain.Shipment;
import duoc.rutaexpress.shipments.repository.ShipmentRepository;
import java.math.BigDecimal;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

@DataJpaTest(properties = {"spring.datasource.password=", "app.messaging.enabled=true"})
@Import({OutboxRecorder.class, OutboxTransactionTest.JsonConfig.class})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class OutboxTransactionTest {
    @Autowired ShipmentRepository shipments;
    @Autowired OutboxRepository outbox;
    @Autowired OutboxRecorder recorder;
    @Autowired PlatformTransactionManager transactionManager;
    @AfterEach void cleanTestDatabase() { outbox.deleteAll(); shipments.deleteAll(); }
    @Test void commitsShipmentAndPendingEventTogether() {
        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            Shipment shipment = shipments.saveAndFlush(newShipment());
            recorder.record(shipment, "shipment.created");
        });
        assertEquals(1, shipments.count());
        assertEquals(1, outbox.count());
        String payload = outbox.findAll().getFirst().getPayload();
        assertTrue(payload.contains("RX-TX-TEST"));
        assertFalse(payload.contains("private@example.test"));
        assertFalse(payload.contains("Private Name"));
    }
    @Test void rollsBackBothRowsWhenTheBusinessTransactionFails() {
        assertThrows(IllegalStateException.class, () -> new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            Shipment shipment = shipments.saveAndFlush(newShipment());
            recorder.record(shipment, "shipment.created");
            throw new IllegalStateException("force rollback");
        }));
        assertEquals(0, shipments.count());
        assertEquals(0, outbox.count());
    }
    private Shipment newShipment() {
        return new Shipment("RX-TX-TEST", "Private Name", "private@example.test", "Origin", "Destination",
                BigDecimal.ONE, 1L, "Express");
    }
    @TestConfiguration static class JsonConfig {
        @Bean ObjectMapper json() { return JsonMapper.builder().build(); }
    }
}
