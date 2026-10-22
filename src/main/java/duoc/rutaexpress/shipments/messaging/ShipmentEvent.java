package duoc.rutaexpress.shipments.messaging;

import java.time.Instant;
import java.util.UUID;

/** Versioned wire contract: no recipient email, name or address is published. */
public record ShipmentEvent(int schemaVersion, UUID eventId, String eventType, Long shipmentId,
                            String trackingCode, String status, Instant occurredAt) { }
