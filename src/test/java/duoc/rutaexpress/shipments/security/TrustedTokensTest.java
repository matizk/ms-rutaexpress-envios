package duoc.rutaexpress.shipments.security;

import static org.junit.jupiter.api.Assertions.*;
import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.*;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.*;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.security.oauth2.jwt.*;

class TrustedTokensTest {
    static final String TENANT = "11111111-1111-4111-8111-111111111111";
    static final String API = "22222222-2222-4222-8222-222222222222";
    static final String SPA = "33333333-3333-4333-8333-333333333333";
    static HttpServer server;
    static RSAKey key, otherKey;
    String issuer;
    AzureTokenPolicy azure;
    JwtDecoder decoder;
    @BeforeAll static void startKeys() throws Exception {
        key = new RSAKeyGenerator(2048).keyID("test-key").generate();
        otherKey = new RSAKeyGenerator(2048).keyID("test-key").generate();
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            byte[] body = new JWKSet(key.toPublicJWK()).toString().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, body.length);
            try (var stream = exchange.getResponseBody()) { stream.write(body); }
        });
        server.start();
    }
    @AfterAll static void stopKeys() { server.stop(0); }
    @BeforeEach void setup() {
        issuer = "http://127.0.0.1:" + server.getAddress().getPort();
        azure = new AzureTokenPolicy(true, TENANT, API, SPA, "operator.access", issuer + "/keys");
        decoder = new TrustedTokens().jwtDecoder(issuer, "cognito-client", azure);
    }
    @Test void validatesAzureSignatureAndDelegatedClaimsWithoutGrantingAdmin() throws Exception {
        Jwt jwt = decoder.decode(sign(claims().claim("cognito:groups", List.of("Admin")), key));
        assertEquals("ROLE_OPERATOR", TrustedTokens.authorities(jwt, azure).iterator().next().getAuthority());
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims(), otherKey)));
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims().audience(SPA), key)));
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims().claim("tid", "other"), key)));
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims().claim("azp", "other"), key)));
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims().claim("scp", null), key)));
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims().claim("oid", null), key)));
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims().expirationTime(Date.from(Instant.now().minusSeconds(900))), key)));
    }
    @Test void preservesCognitoAndRejectsUnknownIssuersAndDisabledAzure() throws Exception {
        var claims = new JWTClaimsSet.Builder().issuer(issuer).subject("admin")
                .expirationTime(Date.from(Instant.now().plusSeconds(600)))
                .claim("token_use", "access").claim("client_id", "cognito-client").claim("cognito:groups", List.of("Admin"));
        Jwt jwt = decoder.decode(sign(claims, key));
        assertEquals("ROLE_ADMIN", TrustedTokens.authorities(jwt, azure).iterator().next().getAuthority());
        assertThrows(JwtException.class, () -> decoder.decode(sign(claims().issuer("https://untrusted.example"), key)));
        var disabled = new TrustedTokens().jwtDecoder(issuer, "cognito-client",
                new AzureTokenPolicy(false, "", "", "", "", ""));
        assertThrows(JwtException.class, () -> disabled.decode(sign(claims(), key)));
    }
    @Test void incompleteAzureConfigurationFailsClosed() {
        assertThrows(IllegalArgumentException.class, () -> new AzureTokenPolicy(true, "common", API, SPA, "operator.access", ""));
    }
    JWTClaimsSet.Builder claims() {
        return new JWTClaimsSet.Builder().issuer(azure.issuer()).audience(API).subject("operator")
                .issueTime(Date.from(Instant.now())).expirationTime(Date.from(Instant.now().plusSeconds(600)))
                .claim("tid", TENANT).claim("azp", SPA).claim("ver", "2.0")
                .claim("oid", "44444444-4444-4444-8444-444444444444").claim("scp", "operator.access");
    }
    String sign(JWTClaimsSet.Builder claims, RSAKey signingKey) throws Exception {
        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("test-key").build(), claims.build());
        jwt.sign(new RSASSASigner(signingKey)); return jwt.serialize();
    }
}
