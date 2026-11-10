package duoc.rutaexpress.shipments.messaging;

import java.time.Instant;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "app.reporting.enabled", havingValue = "true")
class ReportEventPublisher {
    private static final Logger log = LoggerFactory.getLogger(ReportEventPublisher.class);
    private final ReportOutboxRepository repository;
    private final KafkaTemplate<String, String> kafka;
    private final String topic;

    ReportEventPublisher(ReportOutboxRepository repository, KafkaTemplate<String, String> kafka,
                         @Value("${app.reporting.topic}") String topic) {
        this.repository = repository;
        this.kafka = kafka;
        this.topic = topic;
    }

    @Scheduled(fixedDelayString = "${app.reporting.publish-delay-ms:1000}", initialDelay = 1000)
    void publishPending() {
        for (ReportOutboxEvent event :
                repository.findTop20ByPublishedAtIsNullAndNextAttemptAtLessThanEqualOrderByCreatedAtAsc(Instant.now())) {
            try {
                kafka.send(topic, event.trackingCode(), event.payload()).get(10, TimeUnit.SECONDS);
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            } catch (Exception failure) {
                event.scheduleRetry();
                repository.save(event);
                log.warn("REPORT_KAFKA_RETRY eventId={} error={}", event.id(), failure.getClass().getSimpleName());
                return;
            }
            event.markPublished();
            repository.save(event);
            log.info("REPORT_KAFKA_PUBLISHED eventId={} topic={}", event.id(), topic);
        }
    }
}
