#Requires -Version 7.2
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$containerName='rutaexpress-aws-sql-test-'+[guid]::NewGuid().ToString('N')
$created=$false
$script:passed=0
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Test([string]$Name,[scriptblock]$Body) { & $Body; $script:passed++; "OK: $Name" }
function Query([string]$Sql) {
    $value=& docker exec $containerName psql -X -U postgres -d postgres -Atc $Sql 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Consulta de prueba SQL fallo (sin imprimir contenido privado).' }
    return ($value -join "`n").Trim()
}
try {
    # SOLO fixtures: sin puertos ni red, --pull never, sin volumenes de otros stacks.
    $null=& docker run --pull never --rm --detach --name $containerName --network none `
        --env POSTGRES_PASSWORD=FixtureMaster_01234567890123456789 `
        --env CATALOG_DB_PASSWORD=FixtureCatalog_01234567890123456789 `
        --env SHIPMENTS_DB_PASSWORD=FixtureShipments_01234567890123456789 `
        --env MESSAGING_DB_PASSWORD=FixtureMessaging_01234567890123456789 postgres:16-alpine 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar fixture postgres:16-alpine ya disponible; no se descargan imagenes.' }
    $created=$true
    $ready=$false
    for ($i=0;$i -lt 30;$i++) {
        # El servidor temporal del entrypoint solo escucha Unix; esperar TCP final.
        $null=& docker exec $containerName pg_isready -h 127.0.0.1 -U postgres 2>$null
        if ($LASTEXITCODE -eq 0) { $ready=$true;break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'Timeout de PostgreSQL efimero.' }
    $sql=Get-Content (Join-Path $repo 'deploy/aws/crear-bases.sql') -Raw
    Test 'Sin secretos definidos el SQL se detiene antes de crear recursos' {
        $null=$sql | & docker exec -i $containerName env -u CATALOG_DB_PASSWORD -u SHIPMENTS_DB_PASSWORD -u MESSAGING_DB_PASSWORD psql -X -U postgres -d postgres 2>$null
        Assert ($LASTEXITCODE -ne 0) 'SQL sin claves no fallo'
        Assert ((Query "SELECT count(*) FROM pg_roles WHERE rolname LIKE 'rx_%'") -eq '0') 'Se creo rol sin claves'
    }
    Test 'Crea tres roles y tres bases con propietarios separados' {
        $null=$sql | & docker exec -i $containerName psql -X -U postgres -d postgres 2>$null
        Assert ($LASTEXITCODE -eq 0) 'Creacion SQL fallo'
        Assert ((Query "SELECT count(*) FROM pg_database WHERE (datname,pg_get_userbyid(datdba)) IN (('catalog_db','rx_catalog'),('shipments_db','rx_shipments'),('messaging_db','rx_messaging'))") -eq '3') 'Propietarios incorrectos'
        Assert ((Query "SELECT count(*) FROM pg_roles WHERE rolname LIKE 'rx_%' AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole") -eq '3') 'Roles excesivos'
    }
    Test 'Repetir SQL no cambia password ni borra datos existentes' {
        $null=Query 'CREATE TABLE public.keep_fixture (id integer); INSERT INTO public.keep_fixture VALUES (42);'
        $before=Query "SELECT md5(string_agg(rolpassword,',' ORDER BY rolname)) FROM pg_authid WHERE rolname LIKE 'rx_%'"
        $null=$sql | & docker exec -i --env CATALOG_DB_PASSWORD=ChangedFixture_01234567890123456789 $containerName psql -X -U postgres -d postgres 2>$null
        Assert ($LASTEXITCODE -eq 0) 'Repeticion SQL fallo'
        $after=Query "SELECT md5(string_agg(rolpassword,',' ORDER BY rolname)) FROM pg_authid WHERE rolname LIKE 'rx_%'"
        Assert ($before -eq $after) 'Se cambio password existente'
        Assert ((Query 'SELECT id FROM public.keep_fixture') -eq '42') 'Se perdio dato'
    }
    Test 'Los tres usuarios pueden crear tablas en su propia base' {
        foreach ($component in @('catalog','shipments','messaging')) {
            $null=& docker exec $containerName psql -X -U "rx_$component" -d "${component}_db" -v ON_ERROR_STOP=1 -c 'CREATE TABLE own_fixture (id integer);' 2>$null
            Assert ($LASTEXITCODE -eq 0) 'Propietario no puede crear tablas'
        }
    }
    Test 'El SQL de verificacion es ejecutable y no muestra filas privadas' {
        $check=Get-Content (Join-Path $repo 'deploy/aws/verificar-rds.sql') -Raw
        $out=$check | & docker exec -i $containerName psql -X -U rx_messaging -d messaging_db 2>$null
        Assert ($LASTEXITCODE -eq 0 -and ($out -join ' ') -match 'own_fixture') 'Verificacion SQL fallo'
    }
    Test 'Usuario ajeno no puede leer tablas de otra base' {
        $null=& docker exec $containerName psql -X -U rx_shipments -d catalog_db -v ON_ERROR_STOP=1 -c 'SELECT * FROM own_fixture;' 2>$null
        Assert ($LASTEXITCODE -ne 0) 'Lectura cruzada permitida'
    }
} finally {
    if ($created) {
        if ($containerName -notmatch '^rutaexpress-aws-sql-test-[a-f0-9]{32}$') { throw 'Nombre de fixture inesperado; limpieza detenida.' }
        $null=& docker stop --time 5 $containerName 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "No se pudo detener el contenedor efimero $containerName; revisar solo ese fixture." }
    }
}
"TOTAL: $script:passed pruebas PostgreSQL efimero aprobadas. Sin RDS real; este fixture NO demuestra TLS cloud."
