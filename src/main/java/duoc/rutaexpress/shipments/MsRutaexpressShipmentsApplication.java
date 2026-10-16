package duoc.rutaexpress.shipments;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class MsRutaexpressShipmentsApplication {

	public static void main(String[] args) {
		SpringApplication.run(MsRutaexpressShipmentsApplication.class, args);
	}

}
