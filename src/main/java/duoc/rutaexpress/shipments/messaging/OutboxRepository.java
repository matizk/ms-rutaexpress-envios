package duoc.rutaexpress.shipments.messaging;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OutboxRepository extends JpaRepository<OutboxEvent, UUID> {
    List<OutboxEvent> findTop20ByPublishedAtIsNullAndNextAttemptAtBeforeOrderByCreatedAtAsc(Instant now);
}
