package duoc.rutaexpress.shipments.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import duoc.rutaexpress.shipments.client.CatalogClient;
import duoc.rutaexpress.shipments.client.CatalogServiceSnapshot;
import duoc.rutaexpress.shipments.domain.Shipment;
import duoc.rutaexpress.shipments.domain.ShipmentStatus;
import duoc.rutaexpress.shipments.dto.ChangeShipmentStatusRequest;
import duoc.rutaexpress.shipments.dto.CreateShipmentRequest;
import duoc.rutaexpress.shipments.dto.ShipmentResponse;
import duoc.rutaexpress.shipments.dto.PublicTrackingResponse;
import duoc.rutaexpress.shipments.exception.BusinessRuleException;
import duoc.rutaexpress.shipments.repository.ShipmentRepository;
import duoc.rutaexpress.shipments.messaging.OutboxRecorder;
import java.math.BigDecimal;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ShipmentServiceTest {

    @Mock
    private ShipmentRepository shipmentRepository;

    @Mock
    private CatalogClient catalogClient;

    @Mock
    private OutboxRecorder outbox;

    private ShipmentService shipmentService;

    @BeforeEach
    void setUp() {
        shipmentService = new ShipmentService(shipmentRepository, catalogClient, outbox);
    }

    @Test
    void createsShipmentWithCreatedStatus() {
        CreateShipmentRequest request = validRequest();
        when(shipmentRepository.existsByCodigoSeguimiento(request.codigoSeguimiento())).thenReturn(false);
        when(catalogClient.reserveCapacity(request.servicioId()))
                .thenReturn(new CatalogServiceSnapshot(1L, "Express", 4));
        when(shipmentRepository.save(any(Shipment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ShipmentResponse response = shipmentService.create(request);

        ArgumentCaptor<Shipment> shipmentCaptor = ArgumentCaptor.forClass(Shipment.class);
        verify(shipmentRepository).save(shipmentCaptor.capture());
        assertEquals(ShipmentStatus.CREADO, shipmentCaptor.getValue().getEstado());
        assertEquals("RX-0001", response.codigoSeguimiento());
        assertEquals("Express", response.servicioNombre());
        assertEquals(ShipmentStatus.CREADO, response.estado());
        verify(catalogClient).reserveCapacity(1L);
        verify(outbox).record(shipmentCaptor.getValue(), "shipment.created");
    }

    @Test
    void allowsTransitionFromCreatedToAccepted() {
        Shipment shipment = shipmentInStatus(ShipmentStatus.CREADO);
        when(shipmentRepository.findForUpdate(10L)).thenReturn(Optional.of(shipment));
        when(shipmentRepository.save(shipment)).thenReturn(shipment);

        ShipmentResponse response = shipmentService.changeStatus(10L,
                new ChangeShipmentStatusRequest(ShipmentStatus.ACEPTADO));

        assertEquals(ShipmentStatus.ACEPTADO, response.estado());
        verify(shipmentRepository).save(shipment);
        verify(outbox).record(shipment, "shipment.status_changed");
    }

    @Test
    void tracksShipmentByCodeWithoutExposingRecipientData() {
        Shipment shipment = shipmentInStatus(ShipmentStatus.EN_RUTA);
        when(shipmentRepository.findByCodigoSeguimiento("RX-0001")).thenReturn(Optional.of(shipment));

        PublicTrackingResponse response = shipmentService.track(" rx-0001 ");

        assertEquals("RX-0001", response.codigoSeguimiento());
        assertEquals(ShipmentStatus.EN_RUTA, response.estado());
        assertEquals("Valparaíso", response.direccionDestino());
    }

    @Test
    void rejectsRouteStatusBeforeAcceptance() {
        Shipment shipment = shipmentInStatus(ShipmentStatus.CREADO);
        when(shipmentRepository.findForUpdate(10L)).thenReturn(Optional.of(shipment));

        assertThrows(BusinessRuleException.class, () -> shipmentService.changeStatus(10L,
                new ChangeShipmentStatusRequest(ShipmentStatus.EN_RUTA)));

        verify(shipmentRepository, never()).save(any(Shipment.class));
        verify(outbox, never()).record(any(), any());
    }

    private CreateShipmentRequest validRequest() {
        return new CreateShipmentRequest("RX-0001", "Ana Pérez", "ana@example.com", "Santiago",
                "Valparaíso", new BigDecimal("2.50"), 1L);
    }

    @Test void doesNotConfirmAnAlreadyAcceptedOrCancelledRequestTwice() {
        for (ShipmentStatus status : new ShipmentStatus[]{ShipmentStatus.ACEPTADO, ShipmentStatus.CANCELADO}) {
            Shipment shipment = shipmentInStatus(status);
            when(shipmentRepository.findForUpdate(10L)).thenReturn(Optional.of(shipment));
            assertThrows(BusinessRuleException.class, () -> shipmentService.changeStatus(10L,
                    new ChangeShipmentStatusRequest(ShipmentStatus.ACEPTADO)));
        }
        verify(shipmentRepository, never()).save(any());
        verify(outbox, never()).record(any(), any());
    }

    private Shipment shipmentInStatus(ShipmentStatus status) {
        Shipment shipment = new Shipment("RX-0001", "Ana Pérez", "ana@example.com", "Santiago",
                "Valparaíso", new BigDecimal("2.50"), 1L, "Express");
        if (status != ShipmentStatus.CREADO) {
            shipment.cambiarEstado(status);
        }
        return shipment;
    }
}
