package duoc.rutaexpress.shipments.messaging;

import duoc.rutaexpress.shipments.domain.Shipment;
import jakarta.persistence.EntityManager;
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
    private final ReportOutboxRepository reportRepository;
    private final EntityManager entityManager;
    private final boolean reportingEnabled;

    public OutboxRecorder(OutboxRepository repository, ObjectMapper json, ReportOutboxRepository reportRepository,
                          EntityManager entityManager,
                          @Value("${app.messaging.enabled:false}") boolean enabled,
                          @Value("${app.reporting.enabled:false}") boolean reportingEnabled) {
        this.repository = repository;
        this.json = json;
        this.enabled = enabled;
        this.reportRepository = reportRepository;
        this.entityManager = entityManager;
        this.reportingEnabled = reportingEnabled;
    }

    /** The shipment and its pending event commit or roll back in the same database transaction. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void record(Shipment shipment, String type) {
        if (!enabled && !reportingEnabled) return;
        UUID id = UUID.randomUUID();
        if (enabled) {
            ShipmentEvent event = new ShipmentEvent(1, id, type, shipment.getId(), shipment.getCodigoSeguimiento(),
                    shipment.getEstado().name(), Instant.now());
            repository.save(new OutboxEvent(id, type, json.writeValueAsString(event)));
        }
        if (reportingEnabled) {
            // La actualización de la fecha de JPA ocurre antes de tomar la foto del envío.
            entityManager.flush();
            saveReportEvent(id, type, shipment);
        }
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void recordReportSnapshot(Shipment shipment) {
        saveReportEvent(UUID.randomUUID(), "shipment.snapshot", shipment);
    }

    private void saveReportEvent(UUID id, String type, Shipment shipment) {
        ReportShipmentEvent event = ReportShipmentEvent.from(id, type, shipment);
        reportRepository.save(new ReportOutboxEvent(event, json.writeValueAsString(event)));
    }
}
