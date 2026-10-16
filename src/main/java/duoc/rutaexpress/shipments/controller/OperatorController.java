package duoc.rutaexpress.shipments.controller;

import duoc.rutaexpress.shipments.domain.ShipmentStatus;
import duoc.rutaexpress.shipments.dto.*;
import duoc.rutaexpress.shipments.service.ShipmentService;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/operator/shipments")
public class OperatorController {
    private final ShipmentService service;
    public OperatorController(ShipmentService service) { this.service = service; }

    @GetMapping
    public List<ShipmentResponse> list(@RequestParam(defaultValue = "CREADO") ShipmentStatus status) {
        return service.findAll(status, null, null);
    }
    @GetMapping("/{id}")
    public ShipmentResponse detail(@PathVariable Long id) { return service.findById(id); }

    @PostMapping("/{id}/accept")
    public ShipmentResponse accept(@PathVariable Long id) {
        return service.changeStatus(id, new ChangeShipmentStatusRequest(ShipmentStatus.ACEPTADO));
    }
}
