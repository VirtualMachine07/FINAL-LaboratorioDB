# GUÍA DE DESPLIEGUE INICIAL - SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo** | **Descripción** |
|-----------|-----------|
| **Documento** | Guía de Despliegue Inicial - Sistema EsbirrosDB |
| **Proyecto** | Sistema de Gestión de Pedidos — Bodegón Porteño |
| **CLIENTES** | Bodegón Los Esbirros de Claudio |
| **Desarrollado por** | SQLeaders S.A. |
| **Versión** | 1.0 |
| **Estado** | Implementado y Funcional |
| **Instituto** | ISTEA |
| **Materia** | Laboratorio de Administración de Bases de Datos |
| **Profesor** | Carlos Alejandro Caraccio |

## **RESUMEN EJECUTIVO**

### **Objetivo del Documento**
Esta guía proporciona las instrucciones completas para el despliegue inicial del sistema EsbirrosDB, incluyendo la secuencia obligatoria de ejecución de bundles SQL, verificaciones y comandos específicos para una instalación exitosa.

---

## ESTRUCTURA DE BUNDLES DISPONIBLES

### **00_Reset_Completo** *(Opcional)*
- `Bundle_CERO_Reset_Completo.sql` — Limpieza total (solo para reinstalación)

### **01_Infraestructura_Base**
- `Bundle_A1_BaseDatos_Estructura.sql` — Creación de BD y 12 tablas principales
- `Bundle_A2_Indices_Datos.sql` — Índices, datos iniciales y menú del bodegón

### **02_Logica_Negocio**
- `Bundle_B1_Pedidos_Core.sql` — SP creación de pedidos
- `Bundle_B2_Items_Calculos.sql` — SP gestión ítems (sin combos)
- `Bundle_B3_Estados_Finalizacion.sql` — SP estados y finalización

### **03_Seguridad_Consultas**
- `Bundle_C_Seguridad.sql` — Roles y permisos de seguridad
- `Bundle_D_Consultas_Basicas.sql` — Consultas base del sistema

### **04_Automatizacion_Avanzada**
- `Bundle_E1_Triggers_Principales.sql` — Triggers de totales y auditoría
- `Bundle_E2_Control_Avanzado.sql` — Stock simulado y notificaciones

### **05_Reportes_Dashboard**
- `Bundle_R1_Reportes_Estructuras_SPs.sql` — Infraestructura de reportes
- `Bundle_R2_Reportes_Vistas_Dashboard.sql` — Vistas y dashboard ejecutivo

### **06_Script de Validación**
- `06_VALIDACION_POST_BUNDLES.sql` — Verificación final completa del sistema
- `TEST_Negocio.sql` — 25 pruebas funcionales end-to-end de lógica de negocio

### **07_Carga_Masiva_Datos** *(Opcional — Testing con volumen)*
- `Bundle_F_Carga_Masiva.sql` — Genera ~43.000 registros realistas (3.000 clientes, 10.000 pedidos, ~30.000 detalles)

---

## SECUENCIA DE DESPLIEGUE OBLIGATORIA

### **FASE 0: RESET (Solo si reinstalando)**

```sql
-- Archivo: 00_Reset_Completo/Bundle_CERO_Reset_Completo.sql
-- Conectar a: master (NO a EsbirrosDB)
-- PRECAUCIÓN: elimina TODOS los datos
```

```bash
sqlcmd -S [SERVIDOR] -d master -E -i "00_Reset_Completo/Bundle_CERO_Reset_Completo.sql"
```

---

### **FASE 1: INFRAESTRUCTURA BÁSICA** *(OBLIGATORIO)*

#### **Paso 1.1 - Estructura de Base de Datos**
```sql
-- Archivo: 01_Infraestructura_Base/Bundle_A1_BaseDatos_Estructura.sql
--  Tiempo estimado: 2-3 minutos
--  Crea: Base de datos EsbirrosDB + 12 tablas principales (sin COMBO/PROMOCION)
```

**Ejecutar:**
```bash
sqlcmd -S [SERVIDOR] -d master -E -i "Bundle_A1_BaseDatos_Estructura.sql"
```

**Verificación:**
```sql
USE EsbirrosDB;
SELECT COUNT(*) AS 'Tablas_Creadas' FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';
-- Resultado esperado: 12
```

#### **Paso 1.2 - Índices y Datos Iniciales**
```sql
-- Archivo: 01_Infraestructura_Base/Bundle_A2_Indices_Datos.sql
--  Tiempo estimado: 1-2 minutos
--  Crea: Índices de performance + datos de referencia + menú del bodegón (22 platos)
```

**Ejecutar:**
```bash
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "Bundle_A2_Indices_Datos.sql"
```

**Verificación:**
```sql
SELECT COUNT(*) AS 'Estados_Pedido' FROM ESTADOS_PEDIDOS; -- Esperado: 8
SELECT COUNT(*) AS 'Roles_Sistema'  FROM ROLES;           -- Esperado: 7
SELECT COUNT(*) AS 'Canales_Venta'  FROM CANALES_VENTAS;   -- Esperado: 4
SELECT COUNT(*) AS 'Platos_Menu'    FROM PLATOS;          -- Esperado: 22
```

---

### **FASE 2: LÓGICA DE NEGOCIO** *(OBLIGATORIO)*

#### **Paso 2.1 - Core de Pedidos**
```sql
-- Archivo: 02_Logica_Negocio/Bundle_B1_Pedidos_Core.sql
--  Tiempo estimado: 1 minuto
--  Crea: sp_CrearPedido (funcionalidad principal)
```

**Dependencias:** Requiere Fase 1 completa

#### **Paso 2.2 - Gestión de Ítems**
```sql
-- Archivo: 02_Logica_Negocio/Bundle_B2_Items_Calculos.sql
--  Tiempo estimado: 1 minuto
--  Crea: sp_AgregarItemPedido (solo platos, sin combo_id), sp_CalcularTotalPedido
```

> **Nota:** `sp_AgregarItemPedido` fue simplificado respecto a v1.0: `@plato_id` es obligatorio,
> se eliminaron `@combo_id` y `@promocion_id`.

#### **Paso 2.3 - Estados y Finalización**
```sql
-- Archivo: 02_Logica_Negocio/Bundle_B3_Estados_Finalizacion.sql
--  Tiempo estimado: 1 minuto
--  Crea: sp_CerrarPedido, sp_CancelarPedido, sp_ActualizarEstadoPedido (transición secuencial)
```

**Verificación Fase 2:**
```sql
SELECT COUNT(*) AS 'SPs_Creados'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_NAME LIKE 'sp_%';
-- Resultado esperado: >= 5 SPs
```

---

### **FASE 3: SEGURIDAD Y CONSULTAS** *(OBLIGATORIO)*

#### **Paso 3.1 - Sistema de Seguridad**
```sql
-- Archivo: 03_Seguridad_Consultas/Bundle_C_Seguridad.sql
--  Tiempo estimado: 1-2 minutos
--  Crea: 8 roles + permisos granulares + usuarios app_esbirros_*
```

**IMPORTANTE:** Requiere permisos de `sysadmin`

**Dependencias:** Requiere Fases 1 y 2 completas

#### **Paso 3.2 - Consultas Básicas**
```sql
-- Archivo: 03_Seguridad_Consultas/Bundle_D_Consultas_Basicas.sql
--  Tiempo estimado: 1 minuto
--  Crea: Vistas y consultas frecuentes del sistema (sin referencias a COMBO)
```

**Verificación Fase 3:**
```sql
SELECT COUNT(*) AS 'Roles_Seguridad'
FROM sys.database_principals
WHERE type = 'R' AND name LIKE 'rol_%';
-- Resultado esperado: 8 roles
```

---

### **FASE 4: AUTOMATIZACIÓN** *(OPCIONAL - RECOMENDADO)*

#### **Paso 4.1 - Triggers Principales**
```sql
-- Archivo: 04_Automatizacion_Avanzada/Bundle_E1_Triggers_Principales.sql
--  Tiempo estimado: 1 minuto
--  Crea: tr_ActualizarTotales, tr_AuditoriaPedidos, tr_AuditoriaDetalle
--  Tabla: AUDITORIAS_SIMPLES
```

#### **Paso 4.2 - Control Avanzado**
```sql
-- Archivo: 04_Automatizacion_Avanzada/Bundle_E2_Control_Avanzado.sql
--  Tiempo estimado: 1 minuto
--  Crea: tr_ValidarStock, tr_SistemaNotificaciones
--  Tablas: STOCKS_SIMULADOS, NOTIFICACIONES
--  SPs: sp_ConsultarNotificaciones, sp_MarcarNotificacionLeida, sp_ConsultarStock
```

---

### **FASE 5: REPORTES Y DASHBOARD** *(OPCIONAL)*

#### **Paso 5.1 - Infraestructura de Reportes**
```sql
-- Archivo: 05_Reportes_Dashboard/Bundle_R1_Reportes_Estructuras_SPs.sql
--  Tiempo estimado: 2 minutos
--  Crea: sp_ReporteVentasDiario, sp_PlatosMasVendidosDiario,
--         sp_RendimientoCanalDiario, sp_AnalisisVentasMensual,
--         sp_RankingProductosMensual
--  Tabla: REPORTES_GENERADOS
```

#### **Paso 5.2 - Vistas y Dashboard**
```sql
-- Archivo: 05_Reportes_Dashboard/Bundle_R2_Reportes_Vistas_Dashboard.sql
--  Tiempo estimado: 2 minutos
--  Crea: vw_DashboardEjecutivo, vw_MonitoreoTiempoReal
```

---

## VALIDACIÓN FINAL DEL SISTEMA

### **Script de Validación Completa**
```sql
-- Archivo: 06_VALIDACION_POST_BUNDLES.sql
--  Tiempo estimado: 1 minuto
--  Verifica: Todos los componentes instalados correctamente
```

### **Resultados Esperados:**
- **Tablas principales:** 12/12
- **Tablas auxiliares:** 4/4
- **Tablas COMBO/PROMOCION:** No deben existir
- **Índices:** 11 creados (8 de performance + 3 UIX filtrados de unicidad)
- **Datos de referencia:** Estados(8), Canales(4), Roles(7) completos
- **Stored procedures:** 19 funcionales (sp_*)
- **Roles de seguridad:** 9 roles configurados
- **Triggers:** 5 activos
- **Reportes:** Infraestructura operativa
- **Porcentaje de éxito:** >= 90%

---

## COMANDOS DE EJECUCIÓN COMPLETOS

### **Ejecución por SQL Server Management Studio (SSMS)**
```sql
-- 1. Conectar con permisos de sysadmin
-- 2. Abrir cada archivo en orden
-- 3. Verificar USE EsbirrosDB; al inicio (excepto Bundle_A1 y Bundle_CERO)
-- 4. Ejecutar (F5)
```

### **Ejecución por Línea de Comandos**
```bash
# Fase 1 - Infraestructura
sqlcmd -S [SERVIDOR] -E -i "01_Infraestructura_Base/Bundle_A1_BaseDatos_Estructura.sql"
sqlcmd -S [SERVIDOR] -E -i "01_Infraestructura_Base/Bundle_A2_Indices_Datos.sql"

# Fase 2 - Lógica de Negocio
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "02_Logica_Negocio/Bundle_B1_Pedidos_Core.sql"
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "02_Logica_Negocio/Bundle_B2_Items_Calculos.sql"
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "02_Logica_Negocio/Bundle_B3_Estados_Finalizacion.sql"

# Fase 3 - Seguridad
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "03_Seguridad_Consultas/Bundle_C_Seguridad.sql"
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "03_Seguridad_Consultas/Bundle_D_Consultas_Basicas.sql"

# Fase 4 - Automatización (Opcional)
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "04_Automatizacion_Avanzada/Bundle_E1_Triggers_Principales.sql"
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "04_Automatizacion_Avanzada/Bundle_E2_Control_Avanzado.sql"

# Fase 5 - Reportes (Opcional)
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "05_Reportes_Dashboard/Bundle_R1_Reportes_Estructuras_SPs.sql"
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "05_Reportes_Dashboard/Bundle_R2_Reportes_Vistas_Dashboard.sql"

# Validación Final
sqlcmd -S [SERVIDOR] -d EsbirrosDB -E -i "06_VALIDACION_POST_BUNDLES.sql"

# Pruebas funcionales de negocio (opcional pero recomendado)
sqlcmd -S [SERVIDOR] -E -i "06_Validacion_Post_Bundles/TEST_Negocio.sql"

# Carga masiva de datos (opcional — para testing con volumen)
sqlcmd -S [SERVIDOR] -E -i "07_Carga_Masiva_Datos/Bundle_F_Carga_Masiva.sql"
```

### **Script PowerShell Automatizado**
```powershell
# Variables de configuración
$Server     = "localhost"
$BundlesPath = "C:\Entrega_Parcial\B - Scripts SQL"

# Función de ejecución
function Execute-Bundle($BundlePath, $Database = "EsbirrosDB") {
    Write-Host "Ejecutando: $BundlePath" -ForegroundColor Yellow
    sqlcmd -S $Server -d $Database -E -i "$BundlesPath\$BundlePath"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Completado: $BundlePath" -ForegroundColor Green
    } else {
        Write-Host "Error en: $BundlePath" -ForegroundColor Red
        exit 1
    }
}

# Ejecución secuencial
Write-Host "INICIANDO DESPLIEGUE ESBIRROSDB" -ForegroundColor Cyan

Execute-Bundle "01_Infraestructura_Base\Bundle_A1_BaseDatos_Estructura.sql" "master"
Execute-Bundle "01_Infraestructura_Base\Bundle_A2_Indices_Datos.sql"
Execute-Bundle "02_Logica_Negocio\Bundle_B1_Pedidos_Core.sql"
Execute-Bundle "02_Logica_Negocio\Bundle_B2_Items_Calculos.sql"
Execute-Bundle "02_Logica_Negocio\Bundle_B3_Estados_Finalizacion.sql"
Execute-Bundle "03_Seguridad_Consultas\Bundle_C_Seguridad.sql"
Execute-Bundle "03_Seguridad_Consultas\Bundle_D_Consultas_Basicas.sql"
Execute-Bundle "04_Automatizacion_Avanzada\Bundle_E1_Triggers_Principales.sql"
Execute-Bundle "04_Automatizacion_Avanzada\Bundle_E2_Control_Avanzado.sql"
Execute-Bundle "05_Reportes_Dashboard\Bundle_R1_Reportes_Estructuras_SPs.sql"
Execute-Bundle "05_Reportes_Dashboard\Bundle_R2_Reportes_Vistas_Dashboard.sql"
Execute-Bundle "06_VALIDACION_POST_BUNDLES.sql"

Write-Host "DESPLIEGUE COMPLETADO EXITOSAMENTE" -ForegroundColor Green
```

---

## SOLUCIÓN DE PROBLEMAS COMUNES

### **Error: "Database already exists"**
```sql
-- Solución: Ejecutar Bundle CERO para limpiar, luego reinstalar
USE master;
-- Conectar a master y ejecutar Bundle_CERO_Reset_Completo.sql
```

### **Error: "Permission denied"**
```sql
-- Verificar permisos del usuario
SELECT IS_SRVROLEMEMBER('sysadmin') AS 'Es_SysAdmin';
-- Debe retornar 1
```

### **Error: "Object already exists"**
```sql
-- Los scripts incluyen verificaciones IF EXISTS / DROP IF EXISTS
-- Es seguro re-ejecutar bundles individuales
```

### **Error: "Foreign key constraint"**
```sql
-- Verificar orden de ejecución
-- Bundle_A1 DEBE ejecutarse antes que Bundle_A2
-- Fases 1-3 son OBLIGATORIAS y en orden
```

### **Validación muestra tablas COMBO/PROMOCION**
```sql
-- Esto indica que hay una instalación previa con tablas residuales
-- Ejecutar Bundle_CERO y reinstalar desde cero
```

---

**Desarrollado por:** SQLeaders S.A.  
**Proyecto Educativo ISTEA:** Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v2.0 — Proyecto Educativo ISTEA**
