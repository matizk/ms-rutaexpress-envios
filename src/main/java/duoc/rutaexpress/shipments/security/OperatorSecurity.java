package duoc.rutaexpress.shipments.security;

import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

/** Verifica el JWT en las rutas de operador y cliente. Las rutas internas pasan por el BFF. */
@Configuration
@EnableWebSecurity
@Import(TrustedTokens.class)
public class OperatorSecurity {
    @Bean SecurityFilterChain operatorFilterChain(HttpSecurity http, AzureTokenPolicy azure) throws Exception {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> TrustedTokens.authorities(jwt, azure));
        return http.securityMatcher("/api/operator/**", "/api/customer/**")
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .requestCache(cache -> cache.disable())
                .authorizeHttpRequests(request -> request
                        .requestMatchers(HttpMethod.GET, "/api/operator/shipments", "/api/operator/shipments/*")
                            .hasAnyRole("ADMIN", "OPERATOR")
                        .requestMatchers(HttpMethod.POST, "/api/operator/shipments/*/accept")
                            .hasAnyRole("ADMIN", "OPERATOR")
                        .requestMatchers(HttpMethod.GET, "/api/customer/shipments").hasRole("CUSTOMER")
                        .requestMatchers(HttpMethod.POST, "/api/customer/shipments").hasRole("CUSTOMER")
                        .anyRequest().denyAll())
                .oauth2ResourceServer(oauth -> oauth.jwt(jwt -> jwt.jwtAuthenticationConverter(converter)))
                .build();
    }
}
