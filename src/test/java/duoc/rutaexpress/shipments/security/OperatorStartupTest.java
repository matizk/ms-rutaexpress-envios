package duoc.rutaexpress.shipments.security;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import duoc.rutaexpress.shipments.client.CatalogClient;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Full component scan catches configuration bean-name collisions that MVC slices do not. */
@SpringBootTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:operator-startup;DB_CLOSE_DELAY=-1",
    "spring.datasource.driver-class-name=org.h2.Driver", "spring.datasource.username=sa",
    "spring.datasource.password=", "app.messaging.enabled=false"
})
class OperatorStartupTest {
    @Autowired ApplicationContext context;
    @MockitoBean CatalogClient catalog;
    @Test void fullApplicationStartsWithTheOperatorSecurityChain() {
        assertNotNull(context.getBean("operatorFilterChain"));
    }
}
