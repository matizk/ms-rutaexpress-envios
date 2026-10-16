package duoc.rutaexpress.shipments.repository;

import duoc.rutaexpress.shipments.domain.Shipment;
import duoc.rutaexpress.shipments.domain.ShipmentStatus;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface ShipmentRepository extends JpaRepository<Shipment, Long>, JpaSpecificationExecutor<Shipment> {

    boolean existsByCodigoSeguimiento(String codigoSeguimiento);

    Optional<Shipment> findByCodigoSeguimiento(String codigoSeguimiento);

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("select s from Shipment s where s.id = :id")
    Optional<Shipment> findForUpdate(@org.springframework.data.repository.query.Param("id") Long id);

}
