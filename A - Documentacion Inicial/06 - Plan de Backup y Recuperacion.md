# PLAN DE BACKUP Y RECUPERACIÓN — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**        | **Descripción**                                     |
|------------------|-----------------------------------------------------|
| **Documento**    | Plan de Backup y Recuperación — Sistema EsbirrosDB  |
| **Proyecto**     | Sistema de Gestión de Pedidos — Bodegón Porteño     |
| **Cliente**      | Bodegón Los Esbirros de Claudio                     |
| **Desarrollado por** | SQLeaders S.A.                                  |
| **Versión**      | 1.0                                                 |
| **Fecha**        | Abril 2026                                          |
| **Instituto**    | ISTEA                                               |
| **Materia**      | Laboratorio de Administración de Bases de Datos     |
| **Profesor**     | Carlos Alejandro Caraccio                           |
| **Estado**       | Implementado y Funcional                            |

---

## ¿POR QUÉ HACER BACKUP?

La base de datos EsbirrosDB es el núcleo operativo del Bodegón Los Esbirros de Claudio. Sin un plan de backup, cualquier falla de hardware, error humano o corrupción de datos podría resultar en la pérdida permanente de toda la información: clientes, pedidos, historial de precios y auditoría.

El plan de backup garantiza que, ante cualquier escenario de falla, el sistema pueda recuperarse en el menor tiempo posible y con la menor pérdida de datos.

---

## HERRAMIENTA UTILIZADA

**SQLBackupAndFTP Free v12.7.35**

Es una herramienta especializada para automatizar backups de SQL Server, con interfaz gráfica que no requiere escribir comandos. La versión **Free** soporta hasta 2 bases de datos programadas, lo cual es suficiente para EsbirrosDB.

---

## CONFIGURACIÓN ACTUAL IMPLEMENTADA

### Datos del Job activo

| **Parámetro**            | **Valor configurado**                      |
|--------------------------|---------------------------------------------|
| **Nombre del job**       | Backup Job - 2                              |
| **Base de datos**        | EsbirrosDB                                  |
| **Tipo de conexión**     | Microsoft SQL Server (Standard backup)      |
| **Tipo de backup**       | Full (completo)                             |
| **Frecuencia**           | Diaria — cada 24 horas                      |
| **Horario**              | 20:00 (8:00 PM)                             |
| **Días activos**         | Todos los días — Lunes a Domingo            |
| **Backup perdido**       | Se recupera automáticamente ("Run missed backups" activado) |
| **Destino**              | Local/Network Folder — `E:\EsbirrosBkp`    |
| **Confirmación por email** | Desactivada                               |
| **Estado del job**       | ✅ Activo y programado                      |

### Último backup ejecutado

| **Fecha**     | **Tipo** | **Resultado** | **Tamaño** |
|---------------|----------|---------------|------------|
| 26/04/2026 20:00 | Full  | ✅ Exitoso    | 3.6 MB     |

> El tamaño de 3.6 MB corresponde a una base con datos de prueba. Con la carga masiva activa (~96.000 registros) el tamaño crecerá, pero sigue siendo manejable en almacenamiento local.

---

## DESTINO DEL BACKUP

Los archivos de backup se almacenan en:

```
E:\EsbirrosBkp\
```

Esta carpeta está en el mismo servidor donde corre SQL Server, lo que permite una **recuperación rápida y sin dependencia de internet**.

### Recomendación futura
Para mayor seguridad, se recomienda agregar un segundo destino en la nube (Google Drive, OneDrive o similar) como copia offsite. SQLBackupAndFTP lo soporta de forma nativa y no requiere costo adicional en la versión Free.

---

## ¿QUÉ CONTIENE UN BACKUP FULL?

Un backup full de EsbirrosDB incluye una copia completa de:
- Todas las tablas y sus datos (pedidos, clientes, platos, precios, etc.)
- Todos los stored procedures, triggers y vistas
- Los roles de seguridad y permisos
- Los índices y constraints

Con un backup full se puede restaurar el sistema completo desde cero.

---

## PROCEDIMIENTO DE RESTAURACIÓN

En caso de falla, el procedimiento para restaurar EsbirrosDB es:

**Paso 1 — Localizar el archivo de backup más reciente:**
```
E:\EsbirrosBkp\
```
Buscar el archivo `.bak` con la fecha más reciente.

**Paso 2 — Restaurar desde SSMS:**
1. Abrir SQL Server Management Studio
2. Click derecho en "Databases" → "Restore Database"
3. Seleccionar "Device" y apuntar al archivo `.bak`
4. Confirmar nombre de base de datos: `EsbirrosDB`
5. Ejecutar la restauración

**Paso 3 — Verificar integridad:**
```sql
DBCC CHECKDB('EsbirrosDB');
```
Si no reporta errores, la base está lista para usar.

---

## ESCENARIOS Y TIEMPOS DE RECUPERACIÓN

| **Escenario**                    | **Pérdida máxima de datos** | **Tiempo estimado de recuperación** |
|----------------------------------|-----------------------------|--------------------------------------|
| Corrupción parcial de datos      | Hasta 24 horas              | 15 a 30 minutos                      |
| Pérdida total de la base         | Hasta 24 horas              | 30 a 60 minutos                      |
| Falla total del servidor         | Hasta 24 horas              | 1 a 2 horas (incluye reinstalación)  |

> Con backup diario, la pérdida máxima posible es de 24 horas de operación. Para un bodegón, esto significa perder como máximo los pedidos del día anterior al fallo.

---

## MEJORAS RECOMENDADAS

| **Mejora**                              | **Impacto**                                    | **Costo** |
|-----------------------------------------|------------------------------------------------|-----------|
| Agregar destino en nube (Google Drive)  | Protección ante pérdida física del servidor    | $0        |
| Activar notificaciones por email        | Alerta inmediata ante falla del backup         | $0        |


---

## RESPONSABILIDADES

| **Rol**             | **Responsabilidad**                                              |
|---------------------|------------------------------------------------------------------|
| **Administrador**   | Verificar mensualmente que los backups se ejecutaron correctamente |
| **SQLeaders S.A.**  | Configuración inicial, documentación y soporte técnico           |

---

## BACKUP INCLUIDO EN ESTA ENTREGA

Como parte de la entrega parcial se incluye un backup real de EsbirrosDB generado con SQLBackupAndFTP el **1 de mayo de 2026 a las 18:47 hs**.

| Campo | Detalle |
|---|---|
| **Archivo** | `C - Backups/EsbirrosDB202605011847.zip` |
| **Tipo** | Full Backup |
| **Contenido** | Archivo `.bak` de EsbirrosDB lista para restaurar |
| **Generado con** | SQLBackupAndFTP Free v12.7.35 |
| **Servidor origen** | Entorno local de desarrollo |

**Para restaurar:**
1. Descomprimir `EsbirrosDB202605011847.zip`
2. Copiar el `.bak` a una ruta accesible por SQL Server
3. Ejecutar desde SSMS o sqlcmd:
```sql
RESTORE DATABASE EsbirrosDB 
FROM DISK = 'C:\ruta\al\archivo.bak'
WITH REPLACE, RECOVERY;
```

---

**Desarrollado por:** SQLeaders S.A.  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — Abril 2026**
