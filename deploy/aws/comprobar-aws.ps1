#Requires -Version 7.2
[CmdletBinding()]
param([string]$ArchivoEntorno=(Join-Path $PSScriptRoot '.env.aws'), [switch]$SinDocker)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/Ev2.Configuration.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '../../scripts/Aws.Deployment.psm1') -Force -DisableNameChecking
if (-not (Test-Path -LiteralPath $ArchivoEntorno -PathType Leaf)) { throw 'Falta .env.aws privado; copiar .env.aws.example y completar.' }
try { $settings=Read-Ev2Settings $ArchivoEntorno }
catch { throw '.env.aws invalido: revisar pares NOMBRE=valor y variables duplicadas (valores ocultos).' }
$result=Test-AwsRuntimeSettings $settings
if (-not $result.Ready) { $result.Errors | Write-Output; throw 'Configuracion AWS incompleta (valores privados ocultos).' }
foreach ($key in $settings.Keys) {
    $inherited=[Environment]::GetEnvironmentVariable($key,'Process')
    if ($null -ne $inherited -and $inherited -cne [string]$settings[$key]) {
        throw 'Una variable exportada por la shell contradice .env.aws; usar shell limpia o quitar ese override (valores ocultos).'
    }
}
$pem=Join-Path $PSScriptRoot 'certs/global-bundle.pem'
if (-not (Test-Path -LiteralPath $pem -PathType Leaf)) { throw 'Falta certificado CA publico de RDS en certs/global-bundle.pem.' }
try {
    # Bundle publico: ImportFromPemFile NO busca una clave privada como CreateFromPemFile.
    $bundle=[Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
    $bundle.ImportFromPemFile($pem)
    if ($bundle.Count -eq 0) { throw 'Bundle sin certificados.' }
    foreach ($certificate in $bundle) { $certificate.Dispose() }
}
catch { throw 'El archivo CA no contiene un certificado PEM valido. No desactivar TLS para resolverlo.' }
foreach ($repo in @('ms-rutaexpress-catalog','ms-rutaexpress-shipments','ms-rutaexpress-messaging','ms-rutaexpress-report','ms-rutaexpress-bff')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "../../../$repo/Dockerfile"))) { throw "Falta carpeta hermana $repo con Dockerfile." }
}
if (-not $SinDocker) {
    & docker info --format '{{.OSType}}' | ForEach-Object { if ($_ -ne 'linux') { throw 'Docker debe ejecutar contenedores Linux.' } }
    if ($LASTEXITCODE -ne 0) { throw 'Docker no responde.' }
    # --quiet: nunca mostrar la configuracion renderizada con contrasenas.
    & docker compose -p rutaexpress-ev2-aws --env-file $ArchivoEntorno -f (Join-Path $PSScriptRoot 'compose.aws.yml') config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Compose AWS invalido.' }
}
'OK: archivos/configuracion AWS comprobados sin mostrar secretos ni iniciar servicios.'
'PENDIENTE: conexion real a RDS, estado AWS/Azure, reglas de red, permisos, capacidad y pruebas cloud.'
