Set-StrictMode -Version 2.0

function Read-Ev2Settings {
    param([Parameter(Mandatory=$true)][string]$Path)
    $settings = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $text = $line.Trim()
        if (-not $text -or $text.StartsWith('#')) { continue }
        if ($text -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
            throw 'Hay una linea invalida en .env.ev2; se esperan pares NOMBRE=valor.'
        }
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($settings.ContainsKey($name)) { throw "La variable $name esta duplicada en .env.ev2." }
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $settings[$name] = $value
    }
    return $settings
}

function Test-Ev2Uuid {
    param([object]$Value)
    $parsed = [guid]::Empty
    return $Value -is [string] -and $Value -match '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' -and
        [guid]::TryParse($Value, [ref]$parsed) -and $parsed -ne [guid]::Empty
}

function Get-Ev2Field {
    param([object]$Object, [string]$Name)
    if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $null
}

function Test-Ev2ApiUpstream {
    param([object]$Value)
    if ($Value -ceq 'http://bff:8080') { return $true }
    return $Value -is [string] -and $Value -cmatch '^https://[A-Za-z0-9.-]+(:443)?(/[A-Za-z0-9._~-]+)*\z'
}

function Test-Ev2Configuration {
    param([Parameter(Mandatory=$true)][string]$ShipmentsDirectory, [switch]$RequireAzure)
    $checks = New-Object 'System.Collections.Generic.List[object]'
    $root = [IO.Path]::GetFullPath($ShipmentsDirectory)
    $parent = Split-Path -Parent $root
    foreach ($repo in @('frontend-rutaexpress','ms-rutaexpress-bff','ms-rutaexpress-catalog',
            'ms-rutaexpress-shipments','ms-rutaexpress-messaging','ms-rutaexpress-report')) {
        $dockerfile = Join-Path (Join-Path $parent $repo) 'Dockerfile'
        $state = if (Test-Path -LiteralPath $dockerfile -PathType Leaf) { 'OK' } else { 'ERROR' }
        $checks.Add([pscustomobject]@{ State=$state; Name=$repo; Message="Carpeta hermana y Dockerfile: $repo" })
    }
    $compose = Test-Path -LiteralPath (Join-Path $root 'compose.ev2.yml') -PathType Leaf
    $checks.Add([pscustomobject]@{State=$(if ($compose) {'OK'} else {'ERROR'}); Name='compose'; Message='compose.ev2.yml presente'})
    $envFile = Join-Path $root '.env.ev2'
    $settings = @{}
    if (Test-Path -LiteralPath $envFile -PathType Leaf) {
        try {
            $settings = Read-Ev2Settings $envFile
            $checks.Add([pscustomobject]@{ State='OK'; Name='env'; Message='.env.ev2 legible, sin variables duplicadas' })
        } catch {
            $checks.Add([pscustomobject]@{ State='ERROR'; Name='env'; Message=$_.Exception.Message })
        }
    } else {
        $checks.Add([pscustomobject]@{ State='ERROR'; Name='env'; Message='Falta .env.ev2; ejecuta iniciar-ev2.ps1 -SoloConfigurar' })
    }
    foreach ($name in @('CATALOG_DB_PASSWORD','SHIPMENTS_DB_PASSWORD','MESSAGING_DB_PASSWORD','RABBITMQ_PASSWORD','RABBITMQ_ERLANG_COOKIE')) {
        $value = [string]$settings[$name]
        $valid = $value.Length -ge 16 -and $value -notmatch '(?i)CAMBIAR|REEMPLAZAR|CHANGEME|TU_PASSWORD|^<'
        $checks.Add([pscustomobject]@{ State=$(if ($valid) {'OK'} else {'ERROR'}); Name=$name
            Message="Variable $name definida sin marcador de ejemplo, minimo 16 caracteres (valor oculto)" })
    }
    $issuer = [string]$settings['COGNITO_ISSUER_URI']
    $validIssuer = $issuer -cmatch '^https://cognito-idp\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9-]+_[A-Za-z0-9]+$' -and
        $issuer -notmatch 'TU_POOL|REEMPLAZAR'
    $checks.Add([pscustomobject]@{ State=$(if ($validIssuer) {'OK'} else {'ERROR'}); Name='cognito-issuer'
        Message='Emisor Cognito con formato de User Pool; no certifica acceso remoto' })
    $client = [string]$settings['COGNITO_CLIENT_ID']
    $validClient = $client -cmatch '^[a-z0-9]{20,40}$'
    $checks.Add([pscustomobject]@{ State=$(if ($validClient) {'OK'} else {'ERROR'}); Name='cognito-client'
        Message='App Client publico de Cognito configurado; no se requieren client secrets' })
    $upstream = [string]$settings['FRONTEND_API_UPSTREAM']
    if (-not $upstream) { $upstream = 'http://bff:8080' }
    $validUpstream = Test-Ev2ApiUpstream $upstream
    $checks.Add([pscustomobject]@{ State=$(if ($validUpstream) {'OK'} else {'ERROR'}); Name='api-upstream'
        Message='Destino API: BFF local o HTTPS sin credenciales, query ni fragmento; URL no mostrada' })
    if ($validUpstream -and $upstream -ne 'http://bff:8080') {
        $checks.Add([pscustomobject]@{State='PENDIENTE'; Name='api-cloud'
            Message='Destino API externo configurado: comprobar acceso, certificado, rutas y JWT con el equipo'})
    }

    $frontend = $null
    $frontendPath = Join-Path (Join-Path $parent 'frontend-rutaexpress') 'public\azure-config.json'
    try {
        $frontend = [IO.File]::ReadAllText($frontendPath) | ConvertFrom-Json -ErrorAction Stop
        if ((Get-Ev2Field $frontend 'enabled') -isnot [bool]) { throw 'enabled debe ser booleano' }
        $checks.Add([pscustomobject]@{ State='OK'; Name='azure-json'; Message='azure-config.json legible con enabled booleano' })
    } catch {
        $checks.Add([pscustomobject]@{ State='ERROR'; Name='azure-json'; Message='Falta azure-config.json o su JSON/valor enabled no es valido' })
    }
    $flag = [string]$settings['AZURE_ENABLED']
    $flagValid = -not $flag -or $flag -in @('true', 'false')
    if (-not $flagValid) {
        $checks.Add([pscustomobject]@{ State='ERROR'; Name='azure-flag'; Message='AZURE_ENABLED debe ser true o false' })
    }
    $backendEnabled = $flag -eq 'true'
    $frontendEnabled = (Get-Ev2Field $frontend 'enabled') -eq $true
    if ($backendEnabled -ne $frontendEnabled) {
        $checks.Add([pscustomobject]@{ State='ERROR'; Name='azure-alignment'; Message='Azure debe estar habilitado o deshabilitado a la vez en frontend y backends' })
    }
    $azureValid = $false
    if ($backendEnabled -and $frontendEnabled) {
        $pairs = @{ AZURE_TENANT_ID='tenantId'; AZURE_SPA_CLIENT_ID='clientId'; AZURE_API_CLIENT_ID='apiClientId' }
        $azureValid = $true
        foreach ($name in $pairs.Keys) {
            $value = [string]$settings[$name]
            $valid = (Test-Ev2Uuid $value) -and $value -ceq [string](Get-Ev2Field $frontend $pairs[$name])
            if (-not $valid) { $azureValid = $false }
            $checks.Add([pscustomobject]@{ State=$(if ($valid) {'OK'} else {'ERROR'}); Name=$name
                Message="$name debe ser un UUID no vacio y coincidir exactamente en ambos archivos" })
        }
        $scope = [string]$settings['AZURE_OPERATOR_SCOPE']
        if (-not $scope) { $scope = 'operator.access' }
        $validScope = $scope -cmatch '^[A-Za-z0-9_.-]+$' -and $scope -ceq [string](Get-Ev2Field $frontend 'scope')
        $validRedirect = (Get-Ev2Field $frontend 'redirectPath') -ceq '/auth/azure'
        $checks.Add([pscustomobject]@{State=$(if ($validScope -and $validRedirect) {'OK'} else {'ERROR'}); Name='azure-scope-callback'
            Message='Scope delegado coincidente y callback /auth/azure; falta comprobar consentimiento remoto'})
        $azureValid = $azureValid -and $validScope -and $validRedirect -and $flagValid
    } else {
        $checks.Add([pscustomobject]@{State=$(if ($RequireAzure) {'ERROR'} else {'PENDIENTE'}); Name='azure'
            Message='Login institucional no habilitado; la revision local Cognito no acredita Azure'})
    }
    foreach ($name in @('AZURE_CLIENT_SECRET','CLIENT_SECRET','AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AZURE_JWK_SET_URI')) {
        if ($settings.ContainsKey($name) -and $settings[$name]) {
            $checks.Add([pscustomobject]@{State='ERROR'; Name=$name; Message="La variable $name no corresponde al arranque local estandar y requiere revision; valor oculto"})
        }
    }
    foreach ($name in @('clientSecret','client_secret','password','accessToken')) {
        if ($null -ne (Get-Ev2Field $frontend $name)) {
            $checks.Add([pscustomobject]@{State='ERROR'; Name='frontend-secret'; Message='No deben existir secretos, contrasenas ni tokens en la configuracion publica del frontend'})
        }
    }
    return [pscustomobject]@{ Ready=(@($checks | Where-Object State -eq 'ERROR').Count -eq 0)
        AzureConfigured=$azureValid; Checks=$checks.ToArray() }
}

function Wait-Ev2HttpServices {
    param([ValidateRange(5,600)][int]$TimeoutSeconds = 120)
    $pending = @{
        frontend='http://127.0.0.1:4200/health'; bff='http://127.0.0.1:8080/actuator/health'
        catalog='http://127.0.0.1:8081/actuator/health'; shipments='http://127.0.0.1:5000/actuator/health'
        messaging='http://127.0.0.1:8084/actuator/health'; report='http://127.0.0.1:8082/actuator/health'
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($pending.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline) {
        foreach ($name in @($pending.Keys)) {
            if ([DateTime]::UtcNow -ge $deadline) { break }
            try {
                $response = Invoke-RestMethod -Uri $pending[$name] -TimeoutSec 2 -ErrorAction Stop
                $healthy = if ($name -eq 'frontend') { $response -is [string] -and $response.Trim() -eq 'UP' }
                    else { $response.status -eq 'UP' }
                if ($healthy) { $pending.Remove($name) }
            } catch { }
        }
        if ($pending.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 500 }
    }
    if ($pending.Count -gt 0) { throw ('Servicios sin health UP: ' + (($pending.Keys | Sort-Object) -join ', ') + '. Ejecuta diagnosticar-ev2.ps1.') }
}

Export-ModuleMember -Function Read-Ev2Settings, Test-Ev2Uuid, Test-Ev2ApiUpstream, Test-Ev2Configuration, Wait-Ev2HttpServices
