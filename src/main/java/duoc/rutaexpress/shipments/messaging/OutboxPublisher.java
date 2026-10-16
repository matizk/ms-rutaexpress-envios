package duoc.rutaexpress.shipments.messaging;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "app.messaging.enabled", havingValue = "true")
public class OutboxPublisher {
    private static final Logger log = LoggerFactory.getLogger(OutboxPublisher.class);
    private final OutboxRepository repository;
    private final RabbitTemplate rabbit;
    private final String eventsExchange;
    private final String commandsExchange;
    private final String ticketKey;

    public OutboxPublisher(OutboxRepository repository, RabbitTemplate rabbit,
            @Value("${app.messaging.events-exchange}") String eventsExchange,
            @Value("${app.messaging.commands-exchange}") String commandsExchange,
            @Value("${app.messaging.ticket-routing-key}") String ticketKey) {
        this.repository = repository;
        this.rabbit = rabbit;
        this.eventsExchange = eventsExchange;
        this.commandsExchange = commandsExchange;
        this.ticketKey = ticketKey;
    }

    @Scheduled(fixedDelayString = "${app.messaging.publish-delay-ms:2000}", initialDelay = 2000)
    public void publishPending() {
        for (OutboxEvent event : repository.findTop20ByPublishedAtIsNullAndNextAttemptAtBeforeOrderByCreatedAtAsc(Instant.now())) {
            try {
                confirmedSend(event, eventsExchange, event.getEventType());
                confirmedSend(event, commandsExchange, ticketKey);
                event.published();
                repository.save(event);
                log.info("OUTBOX_PUBLISHED eventId={}", event.getId());
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            } catch (Exception failure) {
                // A partial publication may be retried. Consumers deduplicate by eventId and domain.
                event.failed(failure);
                repository.save(event);
                log.warn("OUTBOX_RETRY eventId={} attempt={} error={}", event.getId(), event.getAttempts(), failure.getClass().getSimpleName());
            }
        }
    }

    private void confirmedSend(OutboxEvent event, String exchange, String key) throws Exception {
        MessageProperties properties = new MessageProperties();
        properties.setContentType(MessageProperties.CONTENT_TYPE_JSON);
        properties.setContentEncoding(StandardCharsets.UTF_8.name());
        properties.setDeliveryMode(MessageDeliveryMode.PERSISTENT);
        properties.setMessageId(event.getId().toString());
        CorrelationData correlation = new CorrelationData();
        rabbit.send(exchange, key, new Message(event.getPayload().getBytes(StandardCharsets.UTF_8), properties), correlation);
        CorrelationData.Confirm confirm = correlation.getFuture().get(5, TimeUnit.SECONDS);
        if (!confirm.ack() || correlation.getReturned() != null) {
            throw new IllegalStateException("Broker did not confirm a routed message");
        }
    }
}
