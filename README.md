# EsbirrosDB — Bodegón Los Esbirros de Claudio
## Entrega Parcial — Laboratorio de Administración de Bases de Datos

| Campo | Detalle |
|---|---|
| **Institución** | ISTEA |
| **Materia** | Laboratorio de Administración de Bases de Datos |
| **Profesor** | Carlos Alejandro Caraccio |
| **Grupo** | 2 |
| **Fecha de entrega** | Abril 2026 |

---

## Integrantes

| Apellido y Nombre |
|---|
| Acosta, Agustín Alejandro |
| Barletta, Adrian |
| Emmert, Franco |
| Miedwiediew, Lucas |
| Ortiz, Gabriela Mariapia |
| Hettinger, Natalia Beatriz |

---

## Contenido de la Entrega

### `A - Documentacion Inicial/`
Documentación técnica y académica del proyecto.

| # | Documento | Descripción |
|---|---|---|
| 01 | Resumen Ejecutivo | Descripción del negocio, problema y solución implementada |
| 02 | Modelo Entidad-Relación (DER) | Diagrama y descripción de todas las entidades y relaciones |
| 03 | Reglas de Negocio y Validaciones | Reglas implementadas a nivel de base de datos |
| 04 | Guía de Despliegue Inicial | Pasos para reproducir la base desde cero |
| 05 | Carga Masiva de Datos | Descripción de Bundle F (~96.000 registros) y Bundle H (BULK INSERT 10.000 clientes) |
| 06 | Plan de Backup y Recuperación | Estrategia de backup implementada con SQLBackupAndFTP |
| 07 | Prompts de IA Utilizados | Registro de uso de GitHub Copilot (Claude Sonnet 4.6) durante el proyecto |
| 08 | Informe de Despliegue AWS | Implementación de EsbirrosDB en Amazon RDS — SQL Server 2019 Express |

### `B - Scripts SQL/`
Scripts de despliegue organizados en orden de ejecución.

| Carpeta | Contenido |
|---|---|
| `00_Reset_Completo` | Script para resetear la base desde cero |
| `01_Infraestructura_Base` | DDL de tablas, índices y datos maestros |
| `02_Logica_Negocio` | Stored procedures de pedidos, ítems y estados |
| `03_Seguridad_Consultas` | Roles, usuarios y consultas básicas |
| `04_Automatizacion_Avanzada` | Triggers de auditoría y control |
| `05_Reportes_Dashboard` | Stored procedures de reportes y vistas |
| `06_Validacion_Post_Bundles` | Scripts de validación y demo paso a paso |
| `07_Carga_Masiva_Datos` | INSERT masivo de datos de prueba (~96.000 registros) |
| `08_BulkInsert_Clientes_Domicilios` | BULK INSERT + script Python + CSV (10.000 clientes) |

### `C - Backups/`
Backup real de EsbirrosDB generado con SQLBackupAndFTP.

| Archivo | Descripción |
|---|---|
| `EsbirrosDB202605011847.zip` | Backup completo (FULL) de EsbirrosDB — 1 de mayo de 2026, 18:47 hs. Contiene el archivo `.bak` listo para restaurar en SQL Server. |

> Para restaurar: descomprimir el `.zip` y ejecutar `RESTORE DATABASE EsbirrosDB FROM DISK = 'ruta\EsbirrosDB.bak'` desde SSMS o sqlcmd. Ver `A - Documentacion Inicial/06 - Plan de Backup y Recuperacion.md` para el procedimiento completo.

---

## Orden de Ejecución

```
00 → 01 (A1 → A2) → 02 (B1 → B2 → B3) → 03 (C → D) → 04 (E1 → E2) → 05 (R1 → R2) → 06 → 07 (F → G) → 08 (H)
```

> Ver `A - Documentacion Inicial/04 - Guia de Despliegue Inicial.md` para instrucciones detalladas.

---

*Proyecto Educativo ISTEA — Laboratorio de Administración de Bases de Datos 2026*
