param(
    [Parameter(Mandatory=$true)][guid]$TenantId,
    [Parameter(Mandatory=$true)][guid]$FrontendClientId,
    [Parameter(Mandatory=$true)][guid]$ApiClientId,
    [ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$Scope = 'operator.access',
    [switch]$SoloValidar
)
$ErrorActionPreference = 'Stop'
foreach ($id in @($TenantId, $FrontendClientId, $ApiClientId)) {
    if ($id -eq [guid]::Empty) { throw 'Los identificadores deben ser los UUID reales de Azure, no ceros ni ejemplos.' }
}
$envFile = Join-Path $PSScriptRoot '.env.ev2'
$frontendFolder = Join-Path (Split-Path -Parent $PSScriptRoot) 'frontend-rutaexpress'
$frontendConfig = Join-Path $frontendFolder 'public\azure-config.json'
if (-not (Test-Path -LiteralPath $envFile)) { throw 'Ejecuta iniciar-ev2.ps1 -SoloConfigurar antes.' }
if (-not (Test-Path -LiteralPath $frontendConfig)) { throw 'No se encontro el frontend junto a Envios.' }
$configuration = [ordered]@{
    enabled=$true; tenantId=$TenantId.ToString(); clientId=$FrontendClientId.ToString()
    apiClientId=$ApiClientId.ToString(); scope=$Scope; redirectPath='/auth/azure'
}
if ($SoloValidar) {
    Write-Output 'Formato y archivos locales validos. No se modificaron archivos ni se comprobo el tenant remoto.'
    return
}
$settings = [ordered]@{
    AZURE_ENABLED='true'; AZURE_TENANT_ID=$TenantId.ToString(); AZURE_SPA_CLIENT_ID=$FrontendClientId.ToString()
    AZURE_API_CLIENT_ID=$ApiClientId.ToString(); AZURE_OPERATOR_SCOPE=$Scope
}
$existing = [IO.File]::ReadAllLines($envFile)
Import-Module (Join-Path $PSScriptRoot 'scripts\Ev2.Configuration.psm1') -Force -DisableNameChecking
$null = Read-Ev2Settings $envFile
$updated = @($existing | Where-Object { $_ -notmatch '^AZURE_(ENABLED|TENANT_ID|SPA_CLIENT_ID|API_CLIENT_ID|OPERATOR_SCOPE)=' })
$updated += @($settings.Keys | ForEach-Object { $_ + '=' + $settings[$_] })
$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllLines($envFile, $updated, $utf8)
[IO.File]::WriteAllText($frontendConfig, ($configuration | ConvertTo-Json) + [Environment]::NewLine, $utf8)
& (Join-Path $PSScriptRoot 'comprobar-ev2.ps1') -SoloArchivos -ExigirAzure
Write-Output 'Configurados frontend y tres backends. Se conservaron las otras variables y contrasenas.'
Write-Output 'Esto no registra aplicaciones ni permisos en Azure ni prueba el login.'
Write-Output 'Ahora ejecuta iniciar-ev2.ps1 para reconstruir el frontend y recrear los servicios.'
