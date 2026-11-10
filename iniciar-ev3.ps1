param(
    [switch]$SoloReportes,
    [switch]$SinConstruir
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'iniciar-ev2.ps1') -SoloConfigurar
$ev3Env = Join-Path $PSScriptRoot '.env.ev3.local'
if (-not (Test-Path -LiteralPath $ev3Env)) {
    $reportPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    $grafanaPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    [IO.File]::WriteAllLines($ev3Env, @(
        "REPORT_DB_PASSWORD=$reportPassword",
        "GRAFANA_ADMIN_PASSWORD=$grafanaPassword"
    ))
}

$cognitoPath = Join-Path $PSScriptRoot '../frontend-rutaexpress/src/app/core/auth/cognito-settings.json'
$cognito = Get-Content -LiteralPath $cognitoPath -Raw | ConvertFrom-Json
if ($cognito.userPoolId -notmatch '^([a-z]{2}-[a-z0-9-]+-[0-9]+)_[A-Za-z0-9]+$' -or
    $cognito.userPoolClientId -notmatch '^[a-z0-9]+$') {
    throw 'Revisa el pool y el cliente de Cognito en cognito-settings.json.'
}
$region = ($cognito.userPoolId -split '_', 2)[0]
$azurePath = Join-Path $PSScriptRoot '../frontend-rutaexpress/public/azure-config.json'
$azure = Get-Content -LiteralPath $azurePath -Raw | ConvertFrom-Json
if ($azure.enabled -isnot [bool]) { throw 'Revisa enabled en azure-config.json.' }
if ($azure.enabled) {
    $azureIds = @($azure.tenantId, $azure.apiClientId, $azure.clientId)
    if (@($azureIds | Where-Object { [string]$_ -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' }).Count -ne 0 -or
        $azure.scope -notmatch '^[A-Za-z0-9_.-]+$' -or $azure.redirectPath -ne '/auth/azure') {
        throw 'Revisa tenantId, apiClientId, clientId, scope y redirectPath en azure-config.json.'
    }
}

$compose = @('-p', 'rutaexpress-ev3',
    '--env-file', (Join-Path $PSScriptRoot '.env.ev2'), '--env-file', $ev3Env,
    '-f', (Join-Path $PSScriptRoot 'compose.ev2.yml'),
    '-f', (Join-Path $PSScriptRoot 'compose.kafka.yml'),
    '-f', (Join-Path $PSScriptRoot 'compose.ev3.yml'))
$arguments = @('up', '-d', '--wait', '--wait-timeout', '250')
if (-not $SinConstruir) { $arguments += '--build' }
if ($SoloReportes) { $arguments += @('report', 'shipments', 'messaging', 'kafka-admin', 'kafka-ui', 'prometheus', 'grafana') }

$identity = @{
    COGNITO_ISSUER_URI = "https://cognito-idp.$region.amazonaws.com/$($cognito.userPoolId)"
    COGNITO_CLIENT_ID = $cognito.userPoolClientId
    AZURE_ENABLED = $azure.enabled.ToString().ToLowerInvariant()
    AZURE_TENANT_ID = $azure.tenantId
    AZURE_API_CLIENT_ID = $azure.apiClientId
    AZURE_SPA_CLIENT_ID = $azure.clientId
    AZURE_OPERATOR_SCOPE = $azure.scope
}
$previousIdentity = @{}
foreach ($key in $identity.Keys) {
    $previousIdentity[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
try {
    # Usar la misma configuración pública de identidad que Angular.
    foreach ($key in $identity.Keys) {
        [Environment]::SetEnvironmentVariable($key, $identity[$key], 'Process')
    }
    docker compose @compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'La configuración de Docker Compose no es válida.' }

    docker compose @compose @arguments
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo levantar la EV3. Revisa el estado de los contenedores y los puertos locales.' }
} finally {
    foreach ($key in $previousIdentity.Keys) {
        [Environment]::SetEnvironmentVariable($key, $previousIdentity[$key], 'Process')
    }
}

Write-Output 'Kafka UI   http://localhost:18089'
Write-Output 'Reportes   http://localhost:8082/api/report/kpis'
Write-Output 'Kafka Admin http://localhost:8085/actuator/health'
Write-Output 'Prometheus http://localhost:19090'
Write-Output 'Grafana    http://localhost:3000/d/rutaexpress-ev3/rutaexpress-ev3'
if (-not $SoloReportes) { Write-Output 'RutaExpress http://localhost:4200/reportes' }
