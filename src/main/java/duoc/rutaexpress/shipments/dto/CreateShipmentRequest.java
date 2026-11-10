package duoc.rutaexpress.shipments.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;
import java.util.Locale;

public record CreateShipmentRequest(
        @NotBlank(message = "El código de seguimiento es obligatorio")
        @Pattern(regexp = "RX-[A-Z0-9-]{1,47}", message = "El código de seguimiento debe tener el formato RX- seguido de letras, números o guiones") String codigoSeguimiento,
        @NotBlank(message = "El nombre del destinatario es obligatorio") String nombreDestinatario,
        @NotBlank(message = "El email del destinatario es obligatorio")
        @Email(message = "El email del destinatario no es válido") String emailDestinatario,
        @NotBlank(message = "La dirección de origen es obligatoria") String direccionOrigen,
        @NotBlank(message = "La dirección de destino es obligatoria") String direccionDestino,
        @NotNull(message = "El peso es obligatorio")
        @Positive(message = "El peso debe ser mayor que cero") BigDecimal pesoKg,
        @NotNull(message = "Debes seleccionar un servicio")
        @Positive(message = "El servicio seleccionado no es válido") Long servicioId) {
    public CreateShipmentRequest {
        if (codigoSeguimiento != null) codigoSeguimiento = codigoSeguimiento.trim().toUpperCase(Locale.ROOT);
    }
}
