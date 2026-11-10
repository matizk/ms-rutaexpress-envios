package duoc.rutaexpress.shipments.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record CustomerShipmentRequest(
        @NotBlank @Size(max = 120) String nombreDestinatario,
        @NotBlank @Email @Size(max = 160) String emailDestinatario,
        @NotBlank @Size(max = 250) String direccionOrigen,
        @NotBlank @Size(max = 250) String direccionDestino,
        @NotNull @DecimalMin("0.01") @Digits(integer = 8, fraction = 2) BigDecimal pesoKg,
        @NotNull @Positive Long servicioId) { }
