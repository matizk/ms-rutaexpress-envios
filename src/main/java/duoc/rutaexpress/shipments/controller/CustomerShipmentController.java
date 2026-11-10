package duoc.rutaexpress.shipments.controller;

import duoc.rutaexpress.shipments.dto.CustomerShipmentRequest;
import duoc.rutaexpress.shipments.dto.ShipmentResponse;
import duoc.rutaexpress.shipments.service.ShipmentService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/customer/shipments")
public class CustomerShipmentController {
    private final ShipmentService shipments;

    public CustomerShipmentController(ShipmentService shipments) {
        this.shipments = shipments;
    }

    @GetMapping
    public List<ShipmentResponse> list(@AuthenticationPrincipal Jwt customer) {
        return shipments.findForCustomer(customer.getSubject());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ShipmentResponse create(@AuthenticationPrincipal Jwt customer,
                                   @Valid @RequestBody CustomerShipmentRequest request) {
        return shipments.createForCustomer(customer.getSubject(), request);
    }
}
