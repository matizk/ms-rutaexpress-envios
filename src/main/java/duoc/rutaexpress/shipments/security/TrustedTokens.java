package duoc.rutaexpress.shipments.security;

import com.nimbusds.jwt.JWTParser;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.*;

@Configuration
@EnableConfigurationProperties(AzureTokenPolicy.class)
public class TrustedTokens {
    @Bean
    JwtDecoder jwtDecoder(@Value("${COGNITO_ISSUER_URI:https://cognito-idp.us-east-1.amazonaws.com/us-east-1_omx1k5huI}") String issuer,
                          @Value("${COGNITO_CLIENT_ID:41v988atubk0lrcmto285tk77i}") String clientId,
                          AzureTokenPolicy azure) {
        NimbusJwtDecoder cognito = decoder(issuer + "/.well-known/jwks.json",
                new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer(issuer), token ->
                        "access".equals(token.getClaims().get("token_use"))
                        && clientId.equals(token.getClaims().get("client_id")) && token.getExpiresAt() != null
                        ? OAuth2TokenValidatorResult.success()
                        : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token"))));
        NimbusJwtDecoder operator = azure.enabled() ? decoder(azure.keys(),
                new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer(azure.issuer()), azure)) : null;
        return token -> {
            try {
                // The unverified issuer only chooses among trusted, preconfigured decoders.
                String tokenIssuer = JWTParser.parse(token).getJWTClaimsSet().getIssuer();
                if (issuer.equals(tokenIssuer)) return cognito.decode(token);
                if (operator != null && azure.issuer().equals(tokenIssuer)) return operator.decode(token);
            } catch (java.text.ParseException ignored) { }
            throw new BadJwtException("Untrusted token issuer");
        };
    }
    private NimbusJwtDecoder decoder(String keys, OAuth2TokenValidator<Jwt> validator) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(keys).jwsAlgorithm(SignatureAlgorithm.RS256).build();
        decoder.setJwtValidator(validator);
        return decoder;
    }
    public static Collection<GrantedAuthority> authorities(Jwt jwt, AzureTokenPolicy azure) {
        if (azure.isAzure(jwt)) return List.of(new SimpleGrantedAuthority("ROLE_OPERATOR"));
        Object groups = jwt.getClaims().get("cognito:groups");
        return groups instanceof Collection<?> values && values.contains("Admin")
                ? List.of(new SimpleGrantedAuthority("ROLE_ADMIN")) : List.of();
    }
}
