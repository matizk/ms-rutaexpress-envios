package duoc.rutaexpress.shipments.security;

import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

/** Existing service-to-service endpoints stay internal; new operator endpoints validate JWT independently. */
@Configuration
@EnableWebSecurity
@Import(TrustedTokens.class)
public class OperatorSecurity {
    @Bean SecurityFilterChain operatorFilterChain(HttpSecurity http, AzureTokenPolicy azure) throws Exception {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> TrustedTokens.authorities(jwt, azure));
        return http.securityMatcher("/api/operator/**")
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .requestCache(cache -> cache.disable())
                .authorizeHttpRequests(request -> request
                        .requestMatchers(HttpMethod.GET, "/api/operator/shipments", "/api/operator/shipments/*")
                            .hasAnyRole("ADMIN", "OPERATOR")
                        .requestMatchers(HttpMethod.POST, "/api/operator/shipments/*/accept")
                            .hasAnyRole("ADMIN", "OPERATOR")
                        .anyRequest().denyAll())
                .oauth2ResourceServer(oauth -> oauth.jwt(jwt -> jwt.jwtAuthenticationConverter(converter)))
                .build();
    }
}
