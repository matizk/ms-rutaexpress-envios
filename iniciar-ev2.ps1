param(
    [switch]$SoloInfraestructura,
    [switch]$SoloConfigurar,
    [switch]$SinConstruir,
    [ValidateRange(5,600)][int]$TiempoEsperaSegundos=120
)
$ErrorActionPreference = 'Stop'
if ($SoloConfigurar -and ($SoloInfraestructura -or $SinConstruir)) { throw 'SoloConfigurar no se combina con opciones de arranque.' }
$envFile = Join-Path $PSScriptRoot '.env.ev2'
if (-not (Test-Path -LiteralPath $envFile)) {
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $settings = @('CATALOG_DB_PASSWORD', 'SHIPMENTS_DB_PASSWORD', 'MESSAGING_DB_PASSWORD', 'RABBITMQ_PASSWORD', 'RABBITMQ_ERLANG_COOKIE') | ForEach-Object {
            $buffer = New-Object byte[] 24
            $rng.GetBytes($buffer)
            $_ + '=' + [BitConverter]::ToString($buffer).Replace('-', '').ToLowerInvariant()
        }
        $settings += 'COGNITO_ISSUER_URI=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_omx1k5huI'
        $settings += 'COGNITO_CLIENT_ID=41v988atubk0lrcmto285tk77i'
        [IO.File]::WriteAllLines($envFile, $settings, (New-Object Text.UTF8Encoding $false))
    } finally { $rng.Dispose() }
    Write-Output 'Configuracion local generada en .env.ev2 (ignorada por Git).'
}
if ($SoloConfigurar) { return }
& (Join-Path $PSScriptRoot 'comprobar-ev2.ps1')
$dockerPath = (Get-Command docker -ErrorAction Stop).Source
$composeFile = Join-Path $PSScriptRoot 'compose.ev2.yml'
if ($SoloInfraestructura) {
    & $dockerPath compose --env-file $envFile -f $composeFile up -d --wait catalog-db shipments-db messaging-db rabbitmq-1 rabbitmq-2
} else {
    if ($SinConstruir) { & $dockerPath compose --env-file $envFile -f $composeFile up -d }
    else { & $dockerPath compose --env-file $envFile -f $composeFile up -d --build }
}
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose fallo. Revisa espacio, Internet y puertos ocupados; no detengas otros proyectos sin identificarlos.' }
if (-not $SoloInfraestructura) {
    Import-Module (Join-Path $PSScriptRoot 'scripts\Ev2.Configuration.psm1') -Force -DisableNameChecking
    Write-Output 'Esperando frontend y cinco backends con health UP...'
    Wait-Ev2HttpServices -TimeoutSeconds $TiempoEsperaSegundos
    Write-Output 'Stack local listo: http://localhost:4200/operador'
    Write-Output 'El login Azure real y los servicios cloud requieren su configuracion y pruebas del equipo.'
}
