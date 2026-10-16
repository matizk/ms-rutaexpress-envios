package duoc.rutaexpress.shipments.messaging;

import duoc.rutaexpress.shipments.domain.Shipment;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

@Service
public class OutboxRecorder {
    private final OutboxRepository repository;
    private final ObjectMapper json;
    private final boolean enabled;

    public OutboxRecorder(OutboxRepository repository, ObjectMapper json,
                          @Value("${app.messaging.enabled:false}") boolean enabled) {
        this.repository = repository;
        this.json = json;
        this.enabled = enabled;
    }

    /** The shipment and its pending event commit or roll back in the same database transaction. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void record(Shipment shipment, String type) {
        if (!enabled) return;
        UUID id = UUID.randomUUID();
        ShipmentEvent event = new ShipmentEvent(1, id, type, shipment.getId(), shipment.getCodigoSeguimiento(),
                shipment.getEstado().name(), Instant.now());
        repository.save(new OutboxEvent(id, type, json.writeValueAsString(event)));
    }
}
