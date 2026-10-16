[CmdletBinding(DefaultParameterSetName='Cloud')]
param(
    [Parameter(Mandatory=$true, ParameterSetName='Cloud')][string]$UrlApi,
    [Parameter(Mandatory=$true, ParameterSetName='Local')][switch]$Local,
    [switch]$SoloValidar
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'scripts\Ev2.Configuration.psm1') -Force -DisableNameChecking
$upstream = if ($Local) { 'http://bff:8080' } else { $UrlApi.TrimEnd('/') }
if (-not (Test-Ev2ApiUpstream $upstream)) {
    throw 'Usa una URL HTTPS del API Gateway/API Manager sin contrasenas, query ni fragmento; incluye su stage si corresponde.'
}
$envFile = Join-Path $PSScriptRoot '.env.ev2'
if (-not (Test-Path -LiteralPath $envFile)) { throw 'Ejecuta iniciar-ev2.ps1 -SoloConfigurar antes.' }
$null = Read-Ev2Settings $envFile
if ($SoloValidar) { Write-Output 'Formato local valido; no se contactaron servicios remotos ni se modificaron archivos.'; return }
$lines = @([IO.File]::ReadAllLines($envFile) | Where-Object { $_ -notmatch '^FRONTEND_API_UPSTREAM=' })
$lines += 'FRONTEND_API_UPSTREAM=' + $upstream
[IO.File]::WriteAllLines($envFile, $lines, (New-Object Text.UTF8Encoding $false))
Write-Output 'Destino API actualizado sin cambiar Azure, Cognito ni contrasenas. La URL no se muestra.'
Write-Output 'Ejecuta iniciar-ev2.ps1 -SinConstruir para recrear el frontend con el nuevo destino.'
Write-Output 'Solo usa la URL oficial del equipo: alli se enviaran las solicitudes y los bearer tokens.'
