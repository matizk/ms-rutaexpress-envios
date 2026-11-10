package duoc.rutaexpress.shipments.messaging;

import duoc.rutaexpress.shipments.domain.Shipment;
import java.time.LocalDateTime;
import java.util.UUID;

record ReportShipmentEvent(int schemaVersion, UUID eventId, String eventType, Long shipmentId,
                           String trackingCode, String destination, String status,
                           LocalDateTime createdAt, LocalDateTime updatedAt) {
    static ReportShipmentEvent from(UUID id, String type, Shipment shipment) {
        return new ReportShipmentEvent(1, id, type, shipment.getId(), shipment.getCodigoSeguimiento(),
                shipment.getDireccionDestino(), shipment.getEstado().name(),
                shipment.getFechaCreacion(), shipment.getFechaActualizacion());
    }
}
