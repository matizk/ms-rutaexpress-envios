#Requires -Version 7.2
[CmdletBinding()]
param([switch]$ConDocker)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'scripts/Aws.Deployment.psm1') -Force -DisableNameChecking
$script:passed=0
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Test([string]$Name,[scriptblock]$Body) { & $Body; $script:passed++; "OK: $Name" }
function Config {
    return [pscustomobject]@{
        name='rutaexpress-test';region='us-east-1';tenantId='11111111-1111-4111-8111-111111111111'
        apiClientId='22222222-2222-4222-8222-222222222222';spaClientId='33333333-3333-4333-8333-333333333333'
        scope='operator.access';cognitoIssuer='https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool'
        cognitoClientId='abcdefghijklmnopqrstuvw123';cognitoScope='openid';integrationMode='PRIVATE_ALB'
        vpcLinkId='abc123';listenerArn='arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/rutaexpress/123abc/456def'
        backendHttpsOrigin=''
    }
}
function Settings {
    return @{
        RDS_HOST='fixture.abcdefgh.us-east-1.rds.amazonaws.com';BFF_BIND_ADDRESS='127.0.0.1'
        CATALOG_DB_PASSWORD='CAT_012345678901234567890123456789'
        SHIPMENTS_DB_PASSWORD='SHP_012345678901234567890123456789'
        MESSAGING_DB_PASSWORD='MSG_012345678901234567890123456789'
        RABBITMQ_PASSWORD='RAB_012345678901234567890123456789'
        RABBITMQ_ERLANG_COOKIE='CKE_012345678901234567890123456789'
        AZURE_TENANT_ID='11111111-1111-4111-8111-111111111111'
        AZURE_API_CLIENT_ID='22222222-2222-4222-8222-222222222222'
        AZURE_SPA_CLIENT_ID='33333333-3333-4333-8333-333333333333'
        AZURE_OPERATOR_SCOPE='operator.access'
        COGNITO_ISSUER_URI='https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool'
        COGNITO_CLIENT_ID='abcdefghijklmnopqrstuvw123'
    }
}
Test 'Configuracion privada completa aceptada sin llamar AWS' { Assert (Test-AwsApiConfiguration (Config)).Ready 'Config privada valida rechazada' }
foreach ($name in @('tenantId','apiClientId','spaClientId','region','cognitoIssuer','cognitoClientId','scope','vpcLinkId','listenerArn')) {
    $field=$name
    Test "API rechaza $field vacio" { $c=Config; $c.$field=''; Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Campo vacio aceptado' }
}
Test 'API rechaza campo desconocido sin mostrar su valor' {
    $c=Config;$secret='DoNotPrintSecret_123456789012345';$c | Add-Member NoteProperty clientSecret $secret
    $r=Test-AwsApiConfiguration $c
    Assert (-not $r.Ready) 'Se acepto secreto';Assert (($r.Errors -join ' ') -notmatch $secret) 'Se filtro secreto'
}
Test 'API rechaza UUID cero' { $c=Config;$c.tenantId=[guid]::Empty.ToString();Assert (-not (Test-AwsApiConfiguration $c).Ready) 'UUID cero aceptado' }
Test 'API y SPA deben ser distintos' { $c=Config;$c.apiClientId=$c.spaClientId;Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Mismo registro aceptado' }
Test 'API rechaza tipo no textual' { $c=Config;$c.scope=@('operator.access');Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Array aceptado' }
Test 'API rechaza issuer de otro proveedor' { $c=Config;$c.cognitoIssuer='https://evil.invalid';Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Issuer libre aceptado' }
Test 'API rechaza ARN de otra region' { $c=Config;$c.listenerArn=$c.listenerArn.Replace('us-east-1','us-west-2');Assert (-not (Test-AwsApiConfiguration $c).Ready) 'ARN cruzado aceptado' }
Test 'API rechaza scope con salto de linea' { $c=Config;$c.scope="operator.access`n";Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Scope con newline aceptado' }
Test 'Scope Azure debe ser corto, no identificador MSAL completo' {
    $c=Config;$c.scope='api://22222222-2222-4222-8222-222222222222/operator.access';Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Scope completo aceptado'
    $s=Settings;$s.AZURE_OPERATOR_SCOPE=$c.scope;Assert (-not (Test-AwsRuntimeSettings $s).Ready) 'Scope runtime completo aceptado'
}
Test 'API rechaza mezclar publico y privado' { $c=Config;$c.backendHttpsOrigin='https://backend.example.com';Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Modos mezclados' }
function PublicConfig { $c=Config;$c.integrationMode='PUBLIC_HTTPS';$c.vpcLinkId='';$c.listenerArn='';$c.backendHttpsOrigin='https://backend.example.com';return $c }
Test 'HTTPS publico DNS valido aceptado como plan, sin resolver DNS' { Assert (Test-AwsApiConfiguration (PublicConfig)).Ready 'Origen valido rechazado' }
foreach ($origin in @('http://backend.example.com','https://127.0.0.1','https://localhost','https://backend.example.com/path',
    'https://user:pass@backend.example.com','https://backend.example.com?token=private','https://backend.example.com:443',"https://backend.example.com`n")) {
    $bad=$origin
    Test 'API rechaza origen inseguro/malformado sin imprimirlo' { $c=PublicConfig;$c.backendHttpsOrigin=$bad;Assert (-not (Test-AwsApiConfiguration $c).Ready) 'Origen inseguro aceptado' }
}
$plan=New-AwsApiTemplate (Config)
$routes=@($plan.Resources.Values | Where-Object Type -eq 'AWS::ApiGatewayV2::Route')
Test '28 rutas explicitas, ninguna default/catch-all' {
    Assert ($routes.Count -eq 28) 'Cantidad de rutas inesperada'
    Assert (@($routes | Where-Object {$_.Properties.RouteKey -match '\$default|ANY|\{proxy\+'}).Count -eq 0) 'Ruta comodin'
}
Test 'Solo salud y tracking son publicos' {
    $open=@($routes | Where-Object {$_.Properties.AuthorizationType -eq 'NONE'})
    Assert ($open.Count -eq 2) 'Ruta sin auth extra'
    Assert (@($open | Where-Object {$_.Properties.RouteKey -notin @('GET /actuator/health','GET /api/shipments/track/{trackingCode}')}).Count -eq 0) 'Publicacion extra'
}
Test 'Cuatro rutas operador requieren Azure y scope delegado' {
    $ops=@($routes | Where-Object {$_.Properties.RouteKey -match '/api/operator/'})
    Assert ($ops.Count -eq 4) 'Falta ruta operador'
    foreach ($r in $ops) {
        Assert ($r.Properties.AuthorizationType -eq 'JWT' -and $r.Properties.AuthorizerId.Ref -eq 'AzureAuthorizer') 'Operador sin Azure'
        Assert ($r.Properties.AuthorizationScopes[0] -eq 'operator.access') 'Scope omitido'
    }
}
Test 'Administracion usa Cognito con scope y BFF preservado' {
    $admin=@($routes | Where-Object {$_.Properties.RouteKey -notmatch '/api/operator/' -and $_.Properties.AuthorizationType -ne 'NONE'})
    Assert ($admin.Count -eq 22) 'Cantidad admin inesperada'
    foreach ($r in $admin) { Assert ($r.Properties.AuthorizerId.Ref -eq 'CognitoAuthorizer' -and $r.Properties.AuthorizationScopes[0] -eq 'openid') 'Admin sin JWT/scope' }
}
Test 'JWT Azure usa audience API, no SPA/Graph' { Assert ($plan.Resources.AzureAuthorizer.Properties.JwtConfiguration.Audience[0] -eq (Config).apiClientId) 'Audience incorrecta' }
Test 'Authorizer solo lee header, no token en query' { Assert ($plan.Resources.AzureAuthorizer.Properties.IdentitySource[0] -ceq '$request.header.Authorization') 'Fuente peligrosa' }
Test 'Ruta elimina stage sin reescribir Authorization' {
    $p=$plan.Resources.BackendIntegration.Properties.RequestParameters
    Assert ($p['overwrite:path'] -ceq '$request.path' -and $p.Count -eq 1) 'Mapeo peligroso'
}
Test 'CORS exacto, sin cookies ni comodin' {
    $cors=$plan.Resources.HttpApi.Properties.CorsConfiguration
    Assert ($cors.AllowOrigins.Count -eq 1 -and $cors.AllowOrigins[0] -ceq 'http://localhost:4200' -and -not $cors.AllowCredentials) 'CORS inseguro'
}
Test 'No crea IAM/EC2/RDS/usuarios/ALB y logs no incluyen token/cuerpo' {
    $types=@($plan.Resources.Values | ForEach-Object Type)
    Assert (@($types | Where-Object {$_ -notmatch '^AWS::ApiGatewayV2::|^AWS::Logs::LogGroup$'}).Count -eq 0) 'Provisionamiento extra'
    Assert ($plan.Resources.DefaultStage.Properties.AccessLogSettings.Format -notmatch '(?i)authorization|token|body|request.path') 'Log privado'
}
Test 'Roundtrip JSON conserva variables AWS sin expansion PowerShell' {
    $json=$plan | ConvertTo-Json -Depth 25 | ConvertFrom-Json
    Assert ($json.Resources.DefaultStage.Properties.StageName -ceq '$default') 'Stage alterado'
    Assert ($json.Resources.AzureAuthorizer.Properties.IdentitySource[0] -ceq '$request.header.Authorization') 'Variable alterada'
}
Test 'Plan publico usa HTTPS y no incluye VPC Link' {
    $p=(New-AwsApiTemplate (PublicConfig)).Resources.BackendIntegration.Properties
    Assert ($p.ConnectionType -eq 'INTERNET' -and $p.IntegrationUri -eq 'https://backend.example.com' -and -not $p.Contains('ConnectionId')) 'Integracion publica incorrecta'
}
Test 'Runtime ficticio valido sin certificar conexion' { Assert (Test-AwsRuntimeSettings (Settings)).Ready 'Runtime valido rechazado' }
foreach ($key in @('CATALOG_DB_PASSWORD','SHIPMENTS_DB_PASSWORD','MESSAGING_DB_PASSWORD','RABBITMQ_PASSWORD','RABBITMQ_ERLANG_COOKIE')) {
    $field=$key
    Test "Runtime rechaza secreto incompleto $field" { $s=Settings;$s[$field]='';Assert (-not (Test-AwsRuntimeSettings $s).Ready) 'Secreto vacio aceptado' }
}
foreach ($hostName in @('localhost','127.0.0.1','https://fixture.rds.amazonaws.com','evil.invalid',"fixture.abc.us-east-1.rds.amazonaws.com`n")) {
    $bad=$hostName
    Test 'RDS necesita hostname AWS, no URL/IP/local' { $s=Settings;$s.RDS_HOST=$bad;Assert (-not (Test-AwsRuntimeSettings $s).Ready) 'Host RDS inseguro aceptado' }
}
foreach ($ip in @('0.0.0.0','8.8.8.8','::','not-an-ip','167772161','010.0.0.1')) {
    $bad=$ip
    Test 'BFF no acepta bind publico/invalido' { $s=Settings;$s.BFF_BIND_ADDRESS=$bad;Assert (-not (Test-AwsRuntimeSettings $s).Ready) 'Bind inseguro aceptado' }
}
foreach ($ip in @('10.0.1.25','172.16.0.1','172.31.255.254','192.168.1.5')) {
    $good=$ip
    Test 'BFF admite IPv4 privada para ALB' { $s=Settings;$s.BFF_BIND_ADDRESS=$good;Assert (Test-AwsRuntimeSettings $s).Ready 'Bind privado rechazado' }
}
Test 'Cinco secretos distintos y sin expansion Compose' {
    $s=Settings;$s.RABBITMQ_PASSWORD=$s.MESSAGING_DB_PASSWORD;Assert (-not (Test-AwsRuntimeSettings $s).Ready) 'Secretos reutilizados'
    $s=Settings;$s.RABBITMQ_PASSWORD='ABC_$DO_NOT_EXPAND_012345678901234';Assert (-not (Test-AwsRuntimeSettings $s).Ready) 'Expansion Compose aceptada'
}
Test 'Runtime rechaza override JWKS y claves AWS' {
    foreach ($key in @('AZURE_JWK_SET_URI','AWS_SECRET_ACCESS_KEY')) {
        $s=Settings;$s[$key]='DoNotPrintPrivateValue';$r=Test-AwsRuntimeSettings $s
        Assert (-not $r.Ready -and ($r.Errors -join ' ') -notmatch 'DoNotPrintPrivateValue') 'Override o filtracion'
    }
}
Test 'Probe acepta solo HTTPS execute-api, con stage opcional' {
    foreach ($url in @('https://abcdef123.execute-api.us-east-1.amazonaws.com','https://abcdef123.execute-api.us-east-1.amazonaws.com/ev2')) {
        Assert (Test-AwsApiUrl $url) 'URL AWS valida rechazada'
    }
}
foreach ($url in @('http://abcdef123.execute-api.us-east-1.amazonaws.com','https://evil.invalid','https://abcdef123.execute-api.us-east-1.amazonaws.com.evil.invalid',
    'https://user:pass@abcdef123.execute-api.us-east-1.amazonaws.com','https://abcdef123.execute-api.us-east-1.amazonaws.com?token=private',"https://abcdef123.execute-api.us-east-1.amazonaws.com`n")) {
    $bad=$url
    Test 'Probe rechaza destino de token no autorizado' { Assert (-not (Test-AwsApiUrl $bad)) 'Destino no autorizado' }
}

if ($ConDocker) {
    $temporary=Join-Path ([IO.Path]::GetTempPath()) ('rutaexpress-aws-tests-'+[guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $temporary
    try {
        $envPath=Join-Path $temporary '.env.fixture'
        $s=Settings
        [IO.File]::WriteAllLines($envPath,@($s.GetEnumerator() | ForEach-Object {$_.Key+'='+$_.Value}))
        $raw=& docker compose --env-file $envPath -f (Join-Path $repo 'deploy/aws/compose.aws.yml') config --format json 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'Compose AWS no valida con datos ficticios.' }
        $render=$raw | ConvertFrom-Json
        Test 'Compose renderiza siete servicios sin frontend ni PostgreSQL local' {
            Assert (@($render.services.PSObject.Properties).Count -eq 7) 'Cantidad de servicios inesperada'
            Assert ($null -eq $render.services.PSObject.Properties['frontend'] -and $null -eq $render.services.PSObject.Properties['shipments-db']) 'Servicio local en AWS'
        }
        Test 'Tres JDBC RDS usan verify-full y CA montada, nunca maestro' {
            foreach ($service in @('catalog','shipments','messaging')) {
                $sv=$render.services.$service
                Assert ($sv.environment.SPRING_DATASOURCE_URL -match 'sslmode=verify-full&sslrootcert=/run/rds-ca/global-bundle.pem\z') 'Falta TLS'
                Assert ($sv.environment.SPRING_DATASOURCE_USERNAME -eq ('rx_'+$service)) 'Usuario maestro incorrecto'
                Assert ($sv.volumes[0].read_only -and -not $sv.volumes[0].bind.create_host_path) 'CA escribible/creada automaticamente'
            }
        }
        Test 'Unicamente BFF y management loopback publican puertos' {
            foreach ($p in $render.services.PSObject.Properties) {
                if ($p.Name -in @('bff','rabbitmq-1','rabbitmq-2')) {
                    Assert ($p.Value.ports[0].host_ip -eq '127.0.0.1') 'Puerto publico'
                } else { Assert ($null -eq $p.Value.PSObject.Properties['ports']) 'Microservicio expuesto' }
            }
        }
        Test 'Compose exige Azure real en BFF/Envios/Mensajeria' {
            foreach ($name in @('bff','shipments','messaging')) { Assert ($render.services.$name.environment.AZURE_ENABLED -ceq 'true') 'Azure desactivado' }
        }
        [IO.File]::AppendAllText($envPath,"`nFRONTEND_API_UPSTREAM=https://abcdef123.execute-api.us-east-1.amazonaws.com`n")
        $frontRaw=& docker compose --env-file $envPath -f (Join-Path $repo 'deploy/aws/compose.frontend-cloud.yml') config --format json 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'Compose solo frontend no valida.' }
        $front=$frontRaw | ConvertFrom-Json
        Test 'Modo nube mantiene solo Angular en el PC hacia API Gateway' {
            Assert (@($front.services.PSObject.Properties).Count -eq 1) 'Hay backends locales en frontend cloud'
            Assert ($front.services.frontend.environment.BFF_UPSTREAM -eq 'https://abcdef123.execute-api.us-east-1.amazonaws.com') 'Destino API perdido'
            Assert ($front.services.frontend.ports[0].host_ip -eq '127.0.0.1') 'Frontend expuesto'
        }
    } finally {
        # Solo nuestro directorio efimero, comprobado antes de limpieza recursiva.
        $absolute=[IO.Path]::GetFullPath($temporary)
        $parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
        if ((Split-Path -Parent $absolute).TrimEnd('\','/') -ne $parent -or (Split-Path -Leaf $absolute) -notmatch '^rutaexpress-aws-tests-[a-f0-9]{32}$') {
            throw 'Limpieza detenida: destino temporal inesperado.'
        }
        Remove-Item -LiteralPath $absolute -Recurse -Force
    }
}
"TOTAL: $script:passed pruebas AWS locales aprobadas. Ninguna llamada AWS/Azure/RDS ni despliegue real."
exit 0
