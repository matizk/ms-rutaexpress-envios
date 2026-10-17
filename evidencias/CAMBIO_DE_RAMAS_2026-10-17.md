# Cambio de organización de ramas - 17-10-2026

## Decisión y alcance

El propietario pidió continuar su trabajo en **matizk** y llamar **desarrollo** a la rama de integración. Se renombra develop a desarrollo en GitHub y en las seis copias activas, sin modificar main ni reescribir commits. Cada compañero conserva sus propias ramas; no se cambian Daniel-BFF, Daniel-Catalogo ni Daniel-Shipments.

Matizk ya existía en cinco repositorios. Se comprobó que no tenía commits exclusivos frente a la integración: cuatro ramas estaban atrasadas y Reportes coincidía. Se actualizaron por fast-forward; en Mensajería se creó matizk desde el mismo código integrado. No hubo force-push ni descarte de trabajo.

## Puntos de partida preservados

| Repositorio | Integración al renombrar | main conservado |
| --- | --- | --- |
| Frontend | e1e7a6e21fa799dc7c289478061ac461ff7bf8a3 | b2cfbbf6f0cd2cf82207877c695353c8b0279fe4 |
| BFF | 378ed06d3109fe7ead3bff02f6861b544445ec19 | 84d4274e540ef91bc8c70d0bca33ca1450184ac3 |
| Catálogo | 2ddf87e59ca3736e380313d5b5d9193da350f4e2 | 2ddf87e59ca3736e380313d5b5d9193da350f4e2 |
| Envíos | d78ed7c6b71dbb605663ed11349611abdd12bb0e | 890e3297bde54183e2e8db0721f7cfa85d7fec76 |
| Mensajería | c108335aaa52eabf047ebf618df002299c70caf5 | dc04cadc915819557f6d144b070d4146e03e3bfa |
| Reportes | 154cd42acb48d804008e5cf066bd0d6a1433b549 | 154cd42acb48d804008e5cf066bd0d6a1433b549 |

Estos son commits ANTERIORES a los nuevos ajustes de documentación/CI, no necesariamente las puntas posteriores de desarrollo. Permanecen como ancestros verificables; los PR nuevos registran los ajustes.

## Flujo actual

- Trabajo de esta copia: matizk → PR hacia desarrollo → revisión/pruebas → merge commit.
- Integración compartida: desarrollo. Los demás integrantes envían sus ramas, no editan automáticamente matizk.
- Estable: main, sin cambios en esta operación; release real después de comprobar Azure/AWS y la entrega.
- Release/hotfix futuros: `release/<version>` y `hotfix/<descripcion>`; no se crean etapas ficticias.

Se actualizan README, CONTRIBUTING, instrucciones de descarga y plantillas de PR. Los cuatro CI existentes pasan a escuchar PR hacia desarrollo/main y push a desarrollo; mantienen permisos de lectura, acciones fijadas y pruebas sin credenciales cloud. El guard de main admite solo release/hotfix, no una rama personal directamente. No se cambian protecciones/permisos ni se añade despliegue automático.

Las modificaciones de esta operación se limitan a documentación y configuración del flujo; no cambian Java, Angular, dependencias, Compose, bases ni autenticación. Las pruebas funcionales completas del 16-10-2026 conservan su fecha y alcance; no son pruebas nuevas de cloud.

## Retiro seguro de referencias anteriores

Solo se retiran las cuatro referencias de features antiguas después de comprobar que sus puntas son ancestros de desarrollo y que no tienen PR abiertos. No se eliminan PR, commits, archivos de aplicación, bases ni volúmenes. Los commits siguen accesibles desde la integración y sus PR; las referencias se pueden recuperar desde esos commits si se necesitan.

Los informes fechados del 16-10-2026 y los PR originales conservan sus nombres anteriores para no alterar el registro de lo ocurrido. No son órdenes para recrear ramas retiradas. El nombre anterior develop también puede aparecer en registros históricos, aunque ya no sea una rama activa.

## Actualizar las copias del equipo

Seguir [PREPARACION_EQUIPO_EV2.md](../PREPARACION_EQUIPO_EV2.md), sección de migración de una copia existente. No clonar encima, resetear ni borrar ramas con trabajo local no publicado. La guía vigente de continuación está en [CONTINUAR_EV2_EQUIPO.md](../CONTINUAR_EV2_EQUIPO.md).

Referencia oficial sobre efectos del renombrado y actualización de clones: [GitHub, renombrar una rama](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-branches-in-your-repository/renaming-a-branch). Los nombres de los PR/commits anteriores no se reescriben para aparentar otro flujo.

Pendientes académicos sin cambios: login Duoc/Azure real, servicios/Rabbit/RDS/API Gateway en AWS y prueba integrada con evidencias. Cambiar ramas no acredita ninguno de esos pasos.
