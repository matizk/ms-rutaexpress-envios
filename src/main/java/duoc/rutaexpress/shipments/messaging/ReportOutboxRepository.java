package duoc.rutaexpress.shipments.messaging;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReportOutboxRepository extends JpaRepository<ReportOutboxEvent, UUID> {
    List<ReportOutboxEvent> findTop20ByPublishedAtIsNullAndNextAttemptAtLessThanEqualOrderByCreatedAtAsc(
            Instant now);
}
