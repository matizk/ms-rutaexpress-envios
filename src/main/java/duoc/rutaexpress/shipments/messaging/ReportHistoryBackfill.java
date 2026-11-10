package duoc.rutaexpress.shipments.messaging;

import duoc.rutaexpress.shipments.domain.Shipment;
import duoc.rutaexpress.shipments.repository.ShipmentRepository;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component
@ConditionalOnProperty(prefix = "app.reporting", name = {"enabled", "backfill"}, havingValue = "true")
class ReportHistoryBackfill implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(ReportHistoryBackfill.class);
    private final ShipmentRepository shipments;
    private final OutboxRecorder outbox;
    private final TransactionTemplate transactions;

    ReportHistoryBackfill(ShipmentRepository shipments, OutboxRecorder outbox, TransactionTemplate transactions) {
        this.shipments = shipments;
        this.outbox = outbox;
        this.transactions = transactions;
    }

    @Override
    public void run(ApplicationArguments args) {
        long lastId = 0;
        long count = 0;
        List<Shipment> batch = shipments.findTop200ByIdGreaterThanOrderByIdAsc(lastId);
        while (!batch.isEmpty()) {
            List<Shipment> pending = batch;
            transactions.executeWithoutResult(status -> pending.forEach(outbox::recordReportSnapshot));
            count += batch.size();
            lastId = batch.getLast().getId();
            batch = shipments.findTop200ByIdGreaterThanOrderByIdAsc(lastId);
        }
        log.info("REPORT_KAFKA_BACKFILL_ENQUEUED count={}", count);
    }
}
