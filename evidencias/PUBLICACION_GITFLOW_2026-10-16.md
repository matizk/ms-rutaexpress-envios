# Publicacion EV2 y Gitflow - 16-10-2026

## Estado publicado

El alumno autorizo publicar el avance y crear Mensajeria publico, igual que los repositorios existentes. Los seis repositorios tienen develop. Frontend/BFF/Envios/Mensajeria tienen `codex/feature-ev2-mensajeria`, commits por cambios reales y PR **borrador hacia develop**. No se fusionaron ni se hicieron force-push. Los cinco main existentes conservan exactamente los commits previos; el main de Mensajeria contiene solo el bootstrap de ese repositorio nuevo.

| Componente | PR de avance |
| --- | --- |
| Frontend Angular | https://github.com/matizk/frontend-rutaexpress/pull/1 |
| BFF | https://github.com/matizk/ms-rutaexpress-bff/pull/2 |
| Envios y paquete de despliegue | https://github.com/matizk/ms-rutaexpress-shipments/pull/2 |
| Mensajeria nuevo | https://github.com/matizk/ms-rutaexpress-messaging/pull/1 |

Catalogo y Reportes no tienen cambios funcionales en esta pasada; develop apunta al mismo commit que main. No se crearon PR vacios ni commits para aparentar participacion.

## Revision y CI

Los cuatro PR incluyen CI con permisos de lectura, acciones oficiales fijadas por SHA y sin credenciales cloud. Angular: test/build/audit; Java: verify; Envios: herramientas PowerShell y SQL PostgreSQL aislado. Los resultados ACTUALES deben consultarse en Checks/Actions de cada PR: son ejecuciones remotas, no una captura de tests locales.

La primera ejecucion detecto un problema de salida de los tests Windows: todos los casos pasaban pero una prueba negativa dejaba LASTEXITCODE=1. Se corrigio con salida exitosa explicita solo al terminar todos los casos y la limpieza; un error real sigue deteniendo el script. Se actualizan las acciones a Node 24 para retirar advertencias de compatibilidad. Esa correccion queda visible como commit separado, no se borra el intento fallido.

Antes del push pasaron localmente Maven verify de BFF (38), Envios (20) y Mensajeria (23), 15 tests Angular, build y audit de produccion sin alertas conocidas. Las pruebas del paquete AWS previas estan en EV2_PAQUETE_AWS_2026-10-16.md. No confundir esos resultados con el login institucional o el despliegue real.

Gitleaks 8.30.1 (binario oficial con checksum comprobado) reviso archivos y commits nuevos con salida redactada. No se detectaron secretos reales. La lista de excepciones de Envios contiene SOLO valores exactos de fixtures temporales; no ignora carpetas de tests ni reglas completas. Se excluyeron .env privados, target/node_modules, certificados/claves y fotos/audios/PDF de clase. La autoria usa la cuenta matizk y su correo noreply; no se inventaron commits de companeros.

## Como continuar

1. Ver [descarga y arranque](../PREPARACION_EQUIPO_EV2.md): cuatro features coordinadas + develop de Catalogo/Reportes, como carpetas hermanas.
2. Revisar los PR y sus checks. El historial por si solo no significa que se cumpla toda la evaluacion.
3. Coordinar Azure real, AWS EC2/Rabbit/RDS/API Gateway y pruebas completas sin secretos.
4. Cuando corresponda, dejar de borrador, revisar e integrar features a develop con merge commit. Despues crear release aprobada hacia main y sincronizar develop.
5. No existen aun release/tag finales, ni cambios de proteccion/permisos de colaboradores. El repositorio nuevo es publico para lectura; para que otro integrante haga push necesita ser colaborador autorizado.

No se modificaron cuentas AWS/Azure ni se desplego por publicar estas ramas. Los informes anteriores que dicen "sin push" describen su pasada historica, no el estado actual de GitHub.
