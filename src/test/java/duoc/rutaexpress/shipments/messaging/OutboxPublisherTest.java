package duoc.rutaexpress.shipments.messaging;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.ReturnedMessage;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

class OutboxPublisherTest {
    private final OutboxRepository repository = mock(OutboxRepository.class);
    private final RabbitTemplate rabbit = mock(RabbitTemplate.class);
    private final OutboxEvent event = new OutboxEvent(UUID.randomUUID(), "shipment.created", "{}");
    private OutboxPublisher publisher;
    @BeforeEach void setUp() {
        publisher = new OutboxPublisher(repository, rabbit, "events", "commands", "ticket.generate");
        when(repository.findTop20ByPublishedAtIsNullAndNextAttemptAtBeforeOrderByCreatedAtAsc(any())).thenReturn(List.of(event));
    }
    @Test void marksPublishedOnlyAfterBothBrokerConfirmations() {
        doAnswer(call -> { ((CorrelationData) call.getArgument(3)).getFuture().complete(new CorrelationData.Confirm(true, null)); return null; })
                .when(rabbit).send(anyString(), anyString(), any(Message.class), any(CorrelationData.class));
        publisher.publishPending();
        assertNotNull(event.getPublishedAt());
        verify(rabbit, times(2)).send(anyString(), anyString(), any(Message.class), any(CorrelationData.class));
    }
    @Test void keepsUnroutableMessagePendingEvenIfTheBrokerAcknowledgesIt() {
        doAnswer(call -> {
            CorrelationData data = call.getArgument(3);
            data.setReturned(new ReturnedMessage(call.getArgument(2), 312, "NO_ROUTE", "events", "shipment.created"));
            data.getFuture().complete(new CorrelationData.Confirm(true, null)); return null;
        }).when(rabbit).send(anyString(), anyString(), any(Message.class), any(CorrelationData.class));
        publisher.publishPending();
        assertNull(event.getPublishedAt());
        assertEquals(1, event.getAttempts());
        assertTrue(event.getNextAttemptAt().isAfter(java.time.Instant.now()));
    }
    @Test void keepsMessagePendingWhenTheBrokerNacks() {
        doAnswer(call -> { ((CorrelationData) call.getArgument(3)).getFuture().complete(new CorrelationData.Confirm(false, "rejected")); return null; })
                .when(rabbit).send(anyString(), anyString(), any(Message.class), any(CorrelationData.class));
        publisher.publishPending();
        assertNull(event.getPublishedAt());
        assertEquals(1, event.getAttempts());
    }
}
