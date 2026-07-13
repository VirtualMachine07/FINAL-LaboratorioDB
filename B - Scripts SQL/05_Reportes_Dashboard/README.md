# REPORTES Y DASHBOARD - EsbirrosDB

**Orden de ejecución:** PASO 5  
**Dependencias:** Todos los pasos anteriores (1-4) completados

## CONTENIDO DE LA CARPETA

### **Bundle_R1_Reportes_Estructuras_SPs.sql**
- **Propósito:** Infraestructura completa de reportes analíticos
- **Tiempo estimado:** 2 minutos
- **Crea:**
  - Tabla: `REPORTES_GENERADOS` (almacena reportes históricos en JSON)
  - `sp_ReporteVentasDiario` — Ventas del día por canal y estado
  - `sp_PlatosMasVendidosDiario` — Ranking de platos más vendidos hoy
  - `sp_RendimientoCanalDiario` — Comparativa por canal de venta
  - `sp_AnalisisVentasMensual` — Análisis mensual con comparativa semanal
  - `sp_RankingProductosMensual` — Top productos del mes

### **Bundle_R2_Reportes_Vistas_Dashboard.sql**
- **Propósito:** Vistas de dashboard ejecutivo y monitoreo en tiempo real
- **Tiempo estimado:** 2 minutos
- **Crea:**
  - `vw_DashboardEjecutivo` — KPIs del día y del mes (ventas, pedidos, ticket promedio, PLATOS top)
  - `vw_MonitoreoTiempoReal` — Estado operativo actual (mesas, cocina, facturación en curso)

## ORDEN DE EJECUCIÓN

1. Bundle_R1_Reportes_Estructuras_SPs.sql
2. Bundle_R2_Reportes_Vistas_Dashboard.sql

## VALIDACIÓN

```sql
USE EsbirrosDB;

-- Verificar SPs de reportes
SELECT COUNT(*) as SPs_Reportes
FROM sys.objects
WHERE type = 'P' AND name IN (
    'sp_ReporteVentasDiario','sp_PlatosMasVendidosDiario',
    'sp_RendimientoCanalDiario','sp_AnalisisVentasMensual',
    'sp_RankingProductosMensual'
)
-- Esperado: 5

-- Verificar vistas de dashboard
SELECT COUNT(*) as Vistas_Dashboard
FROM sys.views
WHERE name IN ('vw_DashboardEjecutivo','vw_MonitoreoTiempoReal')
-- Esperado: 2

-- Probar vistas
SELECT * FROM vw_DashboardEjecutivo
SELECT * FROM vw_MonitoreoTiempoReal
```

## USO DEL SISTEMA DE REPORTES

```sql
-- Reporte de ventas del día
EXEC sp_ReporteVentasDiario

-- Top 5 platos más vendidos hoy
EXEC sp_PlatosMasVendidosDiario @top_cantidad = 5

-- Rendimiento por canal (MESAS, Mostrador, Delivery)
EXEC sp_RendimientoCanalDiario

-- Análisis mensual completo
EXEC sp_AnalisisVentasMensual

-- Top 10 productos del mes
EXEC sp_RankingProductosMensual @top_cantidad = 10

-- Guardar reporte para historial
EXEC sp_ReporteVentasDiario @guardar_reporte = 1

-- Dashboard en tiempo real
SELECT * FROM vw_DashboardEjecutivo
SELECT * FROM vw_MonitoreoTiempoReal
```
