package duoc.rutaexpress.shipments.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "shipment_report_outbox", indexes =
        @Index(name = "ix_report_outbox_pending", columnList = "published_at,next_attempt_at"))
public class ReportOutboxEvent {
    @Id
    private UUID id;
    @Column(nullable = false, length = 50)
    private String trackingCode;
    @Column(nullable = false, columnDefinition = "text")
    private String payload;
    @Column(nullable = false)
    private Instant createdAt;
    @Column(name = "next_attempt_at", nullable = false)
    private Instant nextAttemptAt;
    @Column(name = "published_at")
    private Instant publishedAt;
    private int attempts;
    @Version
    private Long version;

    protected ReportOutboxEvent() { }

    ReportOutboxEvent(ReportShipmentEvent event, String payload) {
        this.id = event.eventId();
        this.trackingCode = event.trackingCode();
        this.payload = payload;
        this.createdAt = Instant.now();
        this.nextAttemptAt = createdAt;
    }

    UUID id() { return id; }
    String trackingCode() { return trackingCode; }
    String payload() { return payload; }

    void markPublished() {
        publishedAt = Instant.now();
    }

    void scheduleRetry() {
        attempts++;
        nextAttemptAt = Instant.now().plusSeconds(Math.min(60, 1L << Math.min(attempts, 6)));
    }
}
