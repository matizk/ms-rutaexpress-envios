Set-StrictMode -Version 3.0
Import-Module (Join-Path $PSScriptRoot 'Ev2.Configuration.psm1') -DisableNameChecking

function Get-AwsApiRoutes {
    # Un authorizer por ruta: Azure SOLO operador; Cognito + Admin del BFF para legado.
    $operator = @('GET /api/operator/shipments','GET /api/operator/shipments/{id}',
        'POST /api/operator/shipments/{id}/accept','GET /api/operator/confirmations/{trackingCode}')
    $public = @('GET /actuator/health','GET /api/shipments/track/{trackingCode}')
    $admin = @('GET /api/catalog/services','GET /api/catalog/services/{id}',
        'POST /api/catalog/services','PUT /api/catalog/services/{id}','DELETE /api/catalog/services/{id}',
        'GET /api/shipments','GET /api/shipments/{id}','POST /api/shipments','PUT /api/shipments/{id}/status',
        'POST /api/users','GET /api/report/kpis','GET /api/report/top-destinations',
        'GET /api/messaging/summary','GET /api/messaging/receipts','GET /api/rabbitmq/topology',
        'GET /api/rabbitmq/queues/{name}','POST /api/rabbitmq/queues','DELETE /api/rabbitmq/queues/{name}',
        'POST /api/rabbitmq/exchanges','DELETE /api/rabbitmq/exchanges/{name}',
        'POST /api/rabbitmq/bindings','DELETE /api/rabbitmq/bindings')
    foreach ($route in $operator) { [pscustomobject]@{Key=$route;Auth='Azure'} }
    foreach ($route in $public) { [pscustomobject]@{Key=$route;Auth='Public'} }
    foreach ($route in $admin) { [pscustomobject]@{Key=$route;Auth='Cognito'} }
}

function Test-AwsApiConfiguration {
    param([Parameter(Mandatory)][object]$Configuration)
    $errors = [Collections.Generic.List[string]]::new()
    $c = $Configuration
    $allowed = @('name','region','tenantId','apiClientId','spaClientId','scope','cognitoIssuer',
        'cognitoClientId','cognitoScope','integrationMode','vpcLinkId','listenerArn','backendHttpsOrigin')
    foreach ($field in $c.PSObject.Properties) {
        if ($field.Name -notin $allowed) { $errors.Add('Campo desconocido: no se permiten secretos ni opciones adicionales.') }
    }
    foreach ($name in $allowed) {
        if ($null -eq $c.PSObject.Properties[$name] -or $c.$name -isnot [string]) {
            $errors.Add("Falta el campo de texto $name.")
        }
    }
    if ($errors.Count) { return [pscustomobject]@{Ready=$false;Errors=@($errors)} }
    if ($c.name -cnotmatch '^[a-z][a-z0-9-]{2,40}\z') { $errors.Add('Nombre de API invalido.') }
    if ($c.region -cnotmatch '^[a-z]{2}-[a-z]+-[1-9]\z') { $errors.Add('Region AWS invalida.') }
    foreach ($name in @('tenantId','apiClientId','spaClientId')) {
        if (-not (Test-Ev2Uuid $c.$name)) { $errors.Add("UUID invalido: $name.") }
    }
    if ($c.apiClientId -eq $c.spaClientId) { $errors.Add('API y SPA deben ser registros distintos.') }
    if ($c.scope -cnotmatch '^[A-Za-z][A-Za-z0-9._-]{0,100}\z') { $errors.Add('Scope Azure debe ser nombre corto, no api://... ni URL.') }
    if ($c.cognitoScope -cnotmatch '^[A-Za-z][A-Za-z0-9._:/-]{0,150}\z') { $errors.Add('Scope Cognito invalido.') }
    $issuerPattern = '^https://cognito-idp\.' + [regex]::Escape($c.region) + '\.amazonaws\.com/' +
        [regex]::Escape($c.region) + '_[A-Za-z0-9]+\z'
    if ($c.cognitoIssuer -cnotmatch $issuerPattern) { $errors.Add('Issuer Cognito invalido o de otra region.') }
    if ($c.cognitoClientId -cnotmatch '^[a-z0-9]{10,128}\z') { $errors.Add('Cliente Cognito invalido.') }
    if ($c.integrationMode -ceq 'PRIVATE_ALB') {
        if ($c.vpcLinkId -cnotmatch '^[a-z0-9]{4,20}\z') { $errors.Add('Falta VPC Link real.') }
        $arnPattern = '^arn:aws:elasticloadbalancing:' + [regex]::Escape($c.region) +
            ':[0-9]{12}:listener/app/[A-Za-z0-9-]+/[a-f0-9]+/[a-f0-9]+\z'
        if ($c.listenerArn -cnotmatch $arnPattern) { $errors.Add('Falta ARN del listener ALB de la misma region.') }
        if ($c.backendHttpsOrigin) { $errors.Add('No mezclar ALB privado con un origen publico.') }
    } elseif ($c.integrationMode -ceq 'PUBLIC_HTTPS') {
        if ($c.backendHttpsOrigin -cnotmatch '^https://[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+\z' -or
            $c.backendHttpsOrigin -match '(?i)localhost|\.local\z|\.internal\z|^https://[0-9.]+\z') {
            $errors.Add('El backend publico necesita origen HTTPS DNS, sin rutas, puerto ni credenciales.')
        }
        if ($c.vpcLinkId -or $c.listenerArn) { $errors.Add('No mezclar HTTPS publico con VPC Link.') }
    } else { $errors.Add('integrationMode debe ser PRIVATE_ALB o PUBLIC_HTTPS.') }
    return [pscustomobject]@{Ready=($errors.Count -eq 0);Errors=@($errors)}
}

function New-AwsApiTemplate {
    param([Parameter(Mandatory)][object]$Configuration)
    $result = Test-AwsApiConfiguration $Configuration
    if (-not $result.Ready) { throw ('Configuracion API incompleta. ' + ($result.Errors -join ' ')) }
    $c = $Configuration
    $refApi = @{Ref='HttpApi'}
    $integration = [ordered]@{
        ApiId=$refApi;IntegrationType='HTTP_PROXY';IntegrationMethod='ANY';PayloadFormatVersion='1.0'
        TimeoutInMillis=29000;RequestParameters=@{'overwrite:path'='$request.path'}
    }
    if ($c.integrationMode -ceq 'PRIVATE_ALB') {
        $integration.ConnectionType='VPC_LINK';$integration.ConnectionId=$c.vpcLinkId
        $integration.IntegrationUri=$c.listenerArn
    } else { $integration.ConnectionType='INTERNET';$integration.IntegrationUri=$c.backendHttpsOrigin }
    $resources = [ordered]@{
        HttpApi=@{Type='AWS::ApiGatewayV2::Api';Properties=@{
            Name=$c.name;ProtocolType='HTTP';CorsConfiguration=@{
                AllowOrigins=@('http://localhost:4200');AllowHeaders=@('authorization','content-type','accept')
                AllowMethods=@('GET','POST','PUT','DELETE','OPTIONS');AllowCredentials=$false;MaxAge=3600
            }
        }}
        BackendIntegration=@{Type='AWS::ApiGatewayV2::Integration';Properties=$integration}
        AzureAuthorizer=@{Type='AWS::ApiGatewayV2::Authorizer';Properties=@{
            ApiId=$refApi;Name='azure-operator';AuthorizerType='JWT';IdentitySource=@('$request.header.Authorization')
            JwtConfiguration=@{Issuer="https://login.microsoftonline.com/$($c.tenantId)/v2.0";Audience=@($c.apiClientId)}
        }}
        CognitoAuthorizer=@{Type='AWS::ApiGatewayV2::Authorizer';Properties=@{
            ApiId=$refApi;Name='cognito-legacy-admin';AuthorizerType='JWT';IdentitySource=@('$request.header.Authorization')
            JwtConfiguration=@{Issuer=$c.cognitoIssuer;Audience=@($c.cognitoClientId)}
        }}
        AccessLogs=@{Type='AWS::Logs::LogGroup';DeletionPolicy='Retain';UpdateReplacePolicy='Retain';Properties=@{RetentionInDays=7}}
        DefaultStage=@{Type='AWS::ApiGatewayV2::Stage';Properties=@{
            ApiId=$refApi;StageName='$default';AutoDeploy=$true
            DefaultRouteSettings=@{ThrottlingBurstLimit=20;ThrottlingRateLimit=10}
            AccessLogSettings=@{DestinationArn=@{'Fn::GetAtt'=@('AccessLogs','Arn')}
                Format='{"requestId":"$context.requestId","routeKey":"$context.routeKey","status":"$context.status","latency":"$context.responseLatency"}'}
        }}
    }
    $index = 0
    foreach ($route in Get-AwsApiRoutes) {
        $index++
        $properties = [ordered]@{ApiId=$refApi;RouteKey=$route.Key
            Target=@{'Fn::Join'=@('/',@('integrations',@{Ref='BackendIntegration'}))}}
        if ($route.Auth -eq 'Public') { $properties.AuthorizationType='NONE' } else {
            $properties.AuthorizationType='JWT'
            $properties.AuthorizerId=@{Ref=($route.Auth + 'Authorizer')}
            $properties.AuthorizationScopes=@($(if ($route.Auth -eq 'Azure') {$c.scope} else {$c.cognitoScope}))
        }
        $resources[('Route{0:D2}' -f $index)]=@{Type='AWS::ApiGatewayV2::Route';Properties=$properties}
    }
    return [ordered]@{
        AWSTemplateFormatVersion='2010-09-09'
        Description='RutaExpress EV2 - PLAN NO DESPLEGADO. HTTP API, Azure/Cognito y rutas explicitas; recursos de red existentes.'
        Resources=$resources
        Outputs=@{ApiUrl=@{Value=@{'Fn::GetAtt'=@('HttpApi','ApiEndpoint')}}}
    }
}

function Test-AwsRuntimeSettings {
    param([Parameter(Mandatory)][hashtable]$Settings)
    $errors = [Collections.Generic.List[string]]::new()
    $s = $Settings
    $allowed=@('RDS_HOST','CATALOG_DB_PASSWORD','SHIPMENTS_DB_PASSWORD','MESSAGING_DB_PASSWORD',
        'RABBITMQ_PASSWORD','RABBITMQ_ERLANG_COOKIE','AZURE_TENANT_ID','AZURE_SPA_CLIENT_ID',
        'AZURE_API_CLIENT_ID','AZURE_OPERATOR_SCOPE','COGNITO_ISSUER_URI','COGNITO_CLIENT_ID','BFF_BIND_ADDRESS')
    foreach ($key in $s.Keys) { if ($key -notin $allowed) { $errors.Add('Variable adicional no permitida en .env.aws.') } }
    if ([string]$s.RDS_HOST -cnotmatch '^[a-z0-9-]+\.[a-z0-9.-]+\.rds\.amazonaws\.com\z') {
        $errors.Add('RDS_HOST debe ser el endpoint DNS de RDS, no una IP, URL o servidor local.')
    }
    $secretNames=@('CATALOG_DB_PASSWORD','SHIPMENTS_DB_PASSWORD','MESSAGING_DB_PASSWORD','RABBITMQ_PASSWORD','RABBITMQ_ERLANG_COOKIE')
    foreach ($key in $secretNames) {
        # Subconjunto seguro para Compose/env/psql: evita expansion de $, # y escapes.
        if ([string]$s[$key] -cnotmatch '^[A-Za-z0-9_-]{24,128}\z' -or [string]$s[$key] -match '(?i)REEMPLAZAR|CAMBIAR|EXAMPLE|CHANGEME') {
            $errors.Add("Definir $key con 24-128 caracteres aleatorios alfanumericos, _ o - (valor oculto).")
        }
    }
    $distinct=@($secretNames | ForEach-Object {[string]$s[$_]} | Select-Object -Unique)
    if ($distinct.Count -ne $secretNames.Count) { $errors.Add('Usar cinco secretos distintos.') }
    foreach ($key in @('AZURE_TENANT_ID','AZURE_SPA_CLIENT_ID','AZURE_API_CLIENT_ID')) {
        if (-not (Test-Ev2Uuid $s[$key])) { $errors.Add("Falta UUID real: $key.") }
    }
    if ($s.AZURE_API_CLIENT_ID -eq $s.AZURE_SPA_CLIENT_ID) { $errors.Add('API y SPA no pueden ser el mismo registro.') }
    if ([string]$s.AZURE_OPERATOR_SCOPE -cnotmatch '^[A-Za-z][A-Za-z0-9._-]{0,100}\z') { $errors.Add('Scope Azure debe ser nombre corto, no URL.') }
    if ([string]$s.COGNITO_ISSUER_URI -cnotmatch '^https://cognito-idp\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9-]+_[A-Za-z0-9]+\z' -or
        [string]$s.COGNITO_CLIENT_ID -cnotmatch '^[a-z0-9]{10,128}\z') { $errors.Add('Faltan identificadores Cognito existentes.') }
    $address = [Net.IPAddress]::None
    $validIp = [Net.IPAddress]::TryParse([string]$s.BFF_BIND_ADDRESS,[ref]$address)
    $bytes = if ($validIp) { $address.GetAddressBytes() } else { @() }
    $canonical = $validIp -and ([string]$s.BFF_BIND_ADDRESS -ceq $address.ToString())
    if (-not $canonical -or $bytes.Length -ne 4 -or -not ($address.ToString() -eq '127.0.0.1' -or
        $bytes[0] -eq 10 -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or
        ($bytes[0] -eq 192 -and $bytes[1] -eq 168))) { $errors.Add('BFF_BIND_ADDRESS solo admite loopback o IPv4 privada RFC1918.') }
    return [pscustomobject]@{Ready=($errors.Count -eq 0);Errors=@($errors)}
}

function Test-AwsApiUrl {
    param([string]$Url)
    return $Url -cmatch '^https://[a-z0-9]{5,30}\.execute-api\.[a-z]{2}-[a-z]+-[1-9]\.amazonaws\.com(?:/[A-Za-z0-9_-]+)?\z'
}

Export-ModuleMember -Function Get-AwsApiRoutes,Test-AwsApiConfiguration,New-AwsApiTemplate,Test-AwsRuntimeSettings,Test-AwsApiUrl
