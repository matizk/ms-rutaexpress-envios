#Requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][string]$UrlApi,[switch]$ConOperador)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/Aws.Deployment.psm1') -Force -DisableNameChecking
if (-not (Test-AwsApiUrl $UrlApi)) {
    throw 'Usar URL HTTPS oficial execute-api de AWS, sin slash final, query ni credenciales. No se envio ningun token.'
}
function Assert-Http([string]$Path,[int[]]$Expected,[string]$Token,[string]$Name) {
    $headers=@{Accept='application/json'}
    if ($Token) { $headers.Authorization='Bearer ' + $Token }
    try {
        $response=Invoke-WebRequest -Uri ($UrlApi+$Path) -Headers $headers -Method Get -TimeoutSec 20 `
            -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction Stop
        $code=[int]$response.StatusCode
    } catch { throw "Fallo de red/TLS o redireccion en $Name. No se muestra la respuesta privada. No usar SkipCertificateCheck." }
    finally { $headers.Clear() }
    if ($code -notin $Expected) { throw "ERROR: $Name devolvio HTTP $code; esperado $($Expected -join '/')." }
    Write-Output "OK: $Name HTTP $code (sin cuerpo ni token en la salida)."
}
Assert-Http '/actuator/health' @(200) '' 'Salud por API Gateway'
Assert-Http '/api/operator/shipments' @(401) '' 'Operador sin token'
Assert-Http '/api/operator/shipments' @(401) 'invalid.fixture.not-a-real-token' 'Operador con token invalido'
Assert-Http '/api/catalog/services' @(401) '' 'Administracion sin token'
if ($ConOperador) {
    $secure=Read-Host 'Pegar ACCESS TOKEN Azure de NUESTRA API (no ID token, no Graph; no se muestra)' -AsSecureString
    $pointer=[IntPtr]::Zero
    try {
        $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token vacio.' }
        Assert-Http '/api/operator/shipments' @(200) $token 'Operador Azure autorizado'
        Assert-Http '/api/catalog/services' @(401,403) $token 'Operador sin privilegios administrativos'
    } finally {
        $token=$null
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        $secure.Dispose()
    }
}
'No se crearon envios, no se aceptaron solicitudes y no se modifico ningun recurso.'
if (-not $ConOperador) { 'Falta prueba positiva con login real: repetir -ConOperador y completar el recorrido de la guia.' }
