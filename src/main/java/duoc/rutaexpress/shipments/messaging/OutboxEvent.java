package duoc.rutaexpress.shipments.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Index;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "shipment_outbox", indexes = @Index(name = "ix_outbox_pending", columnList = "published_at,next_attempt_at"))
public class OutboxEvent {
    @Id private UUID id;
    @Column(nullable = false, length = 60) private String eventType;
    @Column(nullable = false, columnDefinition = "text") private String payload;
    @Column(nullable = false) private Instant createdAt;
    @Column(name = "published_at") private Instant publishedAt;
    @Column(name = "next_attempt_at", nullable = false) private Instant nextAttemptAt;
    @Column(nullable = false) private int attempts;
    @Column(length = 120) private String lastError;
    @Version private Long version;

    protected OutboxEvent() { }
    public OutboxEvent(UUID id, String eventType, String payload) {
        this.id = id;
        this.eventType = eventType;
        this.payload = payload;
        this.createdAt = Instant.now();
        this.nextAttemptAt = createdAt;
    }
    public UUID getId() { return id; }
    public String getEventType() { return eventType; }
    public String getPayload() { return payload; }
    public Instant getPublishedAt() { return publishedAt; }
    public int getAttempts() { return attempts; }
    public Instant getNextAttemptAt() { return nextAttemptAt; }
    public void published() { publishedAt = Instant.now(); lastError = null; }
    public void failed(Exception failure) {
        attempts++;
        lastError = failure.getClass().getSimpleName();
        nextAttemptAt = Instant.now().plusSeconds(Math.min(60, 1L << Math.min(attempts, 6)));
    }
}
