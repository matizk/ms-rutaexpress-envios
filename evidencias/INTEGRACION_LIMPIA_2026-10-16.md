# Integración local desde descarga limpia - 16-10-2026

## Procedencia y aislamiento

Se clonaron de GitHub los seis repositorios en un directorio nuevo de verificación, como carpetas hermanas. No se copiaron `.env`, contraseñas, target ni node_modules de la instalación anterior. El arranque generó secretos aleatorios propios. Se construyeron las seis imágenes Docker desde esas fuentes (Docker pudo reutilizar capas públicas/caché; no se afirma una compilación sin caché).

| Componente | Commit funcional descargado y probado |
| --- | --- |
| Frontend | 5dcc4b1804c2d239bc2e86ff83777c76caef1792 |
| BFF | 2f2b0a403341919480898655e00deaff3e6fb617 |
| Catálogo | 2ddf87e (develop, sin cambios EV2) |
| Envíos | c2ece63 (incluye aislamiento de scripts y 48 pruebas de configuración) |
| Mensajería | 92175914291cd50a4300418e6f44782a9c2f50ae |
| Reportes | 154cd42 (develop, sin cambios EV2) |

Las actualizaciones posteriores de README/guías/CONTRIBUTING no cambian esas implementaciones. La integración propuesta conserva los PR y utiliza merge commit hacia develop, no main. Ver el estado vivo en los PR enlazados por [CONTINUAR_EV2_EQUIPO.md](../CONTINUAR_EV2_EQUIPO.md).

Proyecto exclusivo de laboratorio: `rutaexpress-ev2-prueba-limpia`. Once contenedores y cinco volúmenes NUEVOS; los proyectos/volúmenes anteriores EV1/EV2 permanecieron detenidos y no fueron alterados. Puertos enlazados a loopback. Solo datos ficticios `example.test`; no correo externo.

## Ejecución reproducible

Desde la copia limpia de Envíos, con los puertos libres y Docker Linux:

```powershell
./iniciar-ev2.ps1 -SoloConfigurar
./comprobar-ev2.ps1 -SoloArchivos
docker compose -p rutaexpress-ev2-prueba-limpia --env-file .env.ev2 -f compose.ev2.yml up -d --build
./probar-ev2.ps1 -Proyecto rutaexpress-ev2-prueba-limpia
```

Se esperó salud UP en frontend y cinco backends antes del smoke. El informe generado terminó a las **19:10:10 -03:00 del 16-10-2026**. Las tres DB y ambos Rabbit respondieron saludables; los once contenedores quedaron running al completar la prueba.

## Resultado observado

- Dos nodos Rabbit activos, tres colas funcionales y tres DLQ; exchanges direct y topic.
- Envío ficticio `RX-EV2-20261016190807922`: tres resultados de creación y tres adicionales al cambiar a ACEPTADO, persistidos en PostgreSQL.
- Reenviar el evento no agregó registros duplicados.
- Contrato inválido terminó en las tres DLQ, conservado para inspección.
- Un único ticket de aceptación persistido; rutas de operador/admin rechazaron falta de JWT y JWT inválido.
- Tracking público por BFF devolvió ACEPTADO.
- Con ambos Rabbit detenidos se creó otro envío y su outbox quedó pendiente; al volver el broker se procesó sin perder ese evento.
- Reiniciar las tres bases conservó catálogo, envíos y comprobantes.
- HTTP adicional contra :4200: Angular y /operador sirvieron la SPA; tracking atravesó Nginx → BFF → Envíos sin nombre ni correo; cinco rutas privadas devolvieron 401. Azure siguió deshabilitado, no se inventó una sesión.

El smoke de negocio utiliza APIs internas LOCALES para crear/cambiar estado; no equivale a aceptar mediante un token institucional real. Los tests Java verifican aparte permisos, firmas/JWKS de laboratorio, endpoint de aceptación y concurrencia. Falta repetir el flujo con identidad Microsoft real contra AWS.

## Pruebas de herramientas repetidas en esta revisión

- 48 casos de configuración, incluidos rechazo del proyecto AWS/ajeno antes de ejecutar Docker.
- 74 casos de reglas/plantillas AWS y render de Compose, sin llamadas AWS.
- 10 casos de scripts con archivos efímeros.
- 6 casos SQL sobre PostgreSQL efímero sin red/puertos: creación, idempotencia y aislamiento de propietarios. NO prueba RDS/TLS remoto.
- 12 casos de proxy en contenedores efímeros sin red.

Total de estas herramientas: **150 casos correctos**, aparte del smoke real y de Java/Angular. Los CI enlazados en cada PR ejecutan además Maven verify (38 BFF, 20 Envíos, 23 Mensajería) y 15 pruebas Angular/build/audit; consultar su última ejecución, no presentar este archivo como estado eterno de CI.

## Límites y conservación

No se configuró un tenant, no hubo login Duoc ni acceso a AWS/RDS/API Gateway reales. No hay release final ni validación docente por pasar este smoke. No se modificaron permisos de compañeros/protecciones de ramas. La revisión técnica asistida no simula aprobación humana de otro integrante.

Los contenedores de laboratorio se detienen al finalizar la revisión para liberar recursos; sus volúmenes se conservan, con los datos ficticios y mensajes DLQ. No se ejecuta `down -v`, no se purgan colas ni se borran bases del usuario. Para reabrir esta copia, usar el mismo `.env.ev2` privado y el mismo nombre de proyecto; no regenerar contraseñas con sus volúmenes existentes.
