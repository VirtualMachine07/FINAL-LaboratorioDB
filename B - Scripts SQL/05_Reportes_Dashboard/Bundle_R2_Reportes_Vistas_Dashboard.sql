-- =============================================
-- BUNDLE R2 - REPORTES: VISTAS Y DASHBOARD
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Vistas de dashboard ejecutivo y monitoreo en tiempo real
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================
-- PREREQUISITO: Bundle_R1 debe estar ejecutado.
-- =============================================

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

USE EsbirrosDB;
GO

PRINT 'INICIANDO BUNDLE R2 - DASHBOARD Y VISTAS'
PRINT '==========================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- VERIFICACIÓN DE PREREQUISITOS
-- =============================================

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'REPORTES_GENERADOS')
BEGIN
    PRINT 'ERROR: Ejecutar Bundle_R1_Reportes_Estructuras_SPs.sql primero.'
    RETURN
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ReporteVentasDiario]') AND type in (N'P', N'PC'))
BEGIN
    PRINT 'ERROR: sp_ReporteVentasDiario no encontrado. Ejecutar Bundle_R1 primero.'
    RETURN
END

PRINT 'Prerequisitos Bundle_R1 verificados OK'
PRINT ''

-- =============================================
-- VISTA: DASHBOARD EJECUTIVO
-- =============================================

PRINT 'Creando vista: vw_DashboardEjecutivo...'

IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_DashboardEjecutivo]'))
    DROP VIEW [dbo].[vw_DashboardEjecutivo]
GO

CREATE VIEW [dbo].[vw_DashboardEjecutivo] AS
SELECT
    -- Métricas de hoy (estados Entregado + Cerrado)
    (SELECT COALESCE(SUM(total), 0)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE CAST(p.fecha_pedido AS DATE) = CAST(GETDATE() AS DATE)
       AND ep.nombre IN ('Entregado', 'Cerrado'))       AS ventas_hoy,

    (SELECT COUNT(*)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE CAST(p.fecha_pedido AS DATE) = CAST(GETDATE() AS DATE)
       AND ep.nombre IN ('Entregado', 'Cerrado'))       AS pedidos_hoy,

    (SELECT COALESCE(AVG(total), 0)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE CAST(p.fecha_pedido AS DATE) = CAST(GETDATE() AS DATE)
       AND ep.nombre IN ('Entregado', 'Cerrado'))       AS ticket_promedio_hoy,

    -- Métricas del mes
    (SELECT COALESCE(SUM(total), 0)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE YEAR(p.fecha_pedido)  = YEAR(GETDATE())
       AND MONTH(p.fecha_pedido) = MONTH(GETDATE())
       AND ep.nombre IN ('Entregado', 'Cerrado'))       AS ventas_mes,

    (SELECT COUNT(*)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE YEAR(p.fecha_pedido)  = YEAR(GETDATE())
       AND MONTH(p.fecha_pedido) = MONTH(GETDATE())
       AND ep.nombre IN ('Entregado', 'Cerrado'))       AS pedidos_mes,

    -- PLATOS más vendido hoy
    (SELECT TOP 1 pl.nombre
     FROM DETALLES_PEDIDOS dp
     INNER JOIN PEDIDOS        p  ON dp.pedido_id = p.pedido_id
     INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id  = ep.estado_id
     INNER JOIN PLATOS         pl ON dp.plato_id  = pl.plato_id
     WHERE CAST(p.fecha_pedido AS DATE) = CAST(GETDATE() AS DATE)
       AND ep.nombre IN ('Entregado', 'Cerrado')
     GROUP BY pl.plato_id, pl.nombre
     ORDER BY SUM(dp.cantidad) DESC)                   AS plato_top_hoy,

    -- Estado operativo actual
    (SELECT COUNT(DISTINCT mesa_id)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE CAST(p.fecha_pedido AS DATE) = CAST(GETDATE() AS DATE)
       AND ep.nombre NOT IN ('Entregado', 'Cerrado', 'Cancelado')) AS mesas_ocupadas,

    (SELECT COUNT(*)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE ep.nombre IN ('Pendiente', 'Confirmado', 'En Preparación', 'Listo')) AS pedidos_pendientes,

    GETDATE() AS ultima_actualizacion
GO

-- =============================================
-- VISTA: MONITOREO EN TIEMPO REAL
-- =============================================

PRINT 'Creando vista: vw_MonitoreoTiempoReal...'

IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_MonitoreoTiempoReal]'))
    DROP VIEW [dbo].[vw_MonitoreoTiempoReal]
GO

CREATE VIEW [dbo].[vw_MonitoreoTiempoReal] AS
SELECT
    'TIEMPO_REAL' AS tipo_monitoreo,
    GETDATE()     AS momento,

    -- Pedidos por estado (cola de cocina)
    (SELECT COUNT(*) FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE ep.nombre = 'Pendiente')       AS pendientes,
    (SELECT COUNT(*) FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE ep.nombre = 'Confirmado')      AS confirmados,
    (SELECT COUNT(*) FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE ep.nombre = 'En Preparación') AS en_preparacion,
    (SELECT COUNT(*) FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE ep.nombre = 'Listo')           AS listos_entrega,
    (SELECT COUNT(*) FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE ep.nombre = 'En Reparto')      AS en_reparto,

    -- Ocupación de mesas
    (SELECT COUNT(DISTINCT p.mesa_id)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE ep.nombre NOT IN ('Entregado', 'Cerrado', 'Cancelado')) AS mesas_ocupadas,
    (SELECT COUNT(*) FROM MESAS WHERE activa = 1)                    AS mesas_totales,

    -- Facturación acumulada hoy
    (SELECT COALESCE(SUM(total), 0)
     FROM PEDIDOS p INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
     WHERE CAST(p.fecha_pedido AS DATE) = CAST(GETDATE() AS DATE)
       AND ep.nombre IN ('Entregado', 'Cerrado'))                   AS ventas_acumuladas_hoy,

    -- Personal activo
    (SELECT COUNT(DISTINCT tomado_por_empleado_id)
     FROM PEDIDOS
     WHERE CAST(fecha_pedido AS DATE) = CAST(GETDATE() AS DATE))    AS empleados_activos_hoy
GO

-- =============================================
-- VALIDACIÓN COMPLETA DEL SISTEMA
-- =============================================

PRINT ''
PRINT 'Validando sistema completo de reportes...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ReporteVentasDiario]')     AND type in (N'P',N'PC')) PRINT 'sp_ReporteVentasDiario    : OK' ELSE PRINT 'sp_ReporteVentasDiario    : ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_PlatosMasVendidosDiario]') AND type in (N'P',N'PC')) PRINT 'sp_PlatosMasVendidosDiario: OK' ELSE PRINT 'sp_PlatosMasVendidosDiario: ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RendimientoCanalDiario]')  AND type in (N'P',N'PC')) PRINT 'sp_RendimientoCanalDiario : OK' ELSE PRINT 'sp_RendimientoCanalDiario : ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_AnalisisVentasMensual]')   AND type in (N'P',N'PC')) PRINT 'sp_AnalisisVentasMensual  : OK' ELSE PRINT 'sp_AnalisisVentasMensual  : ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RankingProductosMensual]') AND type in (N'P',N'PC')) PRINT 'sp_RankingProductosMensual: OK' ELSE PRINT 'sp_RankingProductosMensual: ERROR'
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_DashboardEjecutivo]'))       PRINT 'vw_DashboardEjecutivo     : OK' ELSE PRINT 'vw_DashboardEjecutivo     : ERROR'
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_MonitoreoTiempoReal]'))      PRINT 'vw_MonitoreoTiempoReal    : OK' ELSE PRINT 'vw_MonitoreoTiempoReal    : ERROR'
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'REPORTES_GENERADOS')              PRINT 'REPORTES_GENERADOS        : OK' ELSE PRINT 'REPORTES_GENERADOS        : ERROR'

PRINT ''
PRINT 'Prueba de vistas...'

BEGIN TRY
    DECLARE @test1 INT; SELECT @test1 = COUNT(*) FROM vw_DashboardEjecutivo
    PRINT 'vw_DashboardEjecutivo  : Consultable'
END TRY BEGIN CATCH PRINT 'vw_DashboardEjecutivo  : Advertencia - ' + ERROR_MESSAGE() END CATCH

BEGIN TRY
    DECLARE @test2 INT; SELECT @test2 = COUNT(*) FROM vw_MonitoreoTiempoReal
    PRINT 'vw_MonitoreoTiempoReal : Consultable'
END TRY BEGIN CATCH PRINT 'vw_MonitoreoTiempoReal : Advertencia - ' + ERROR_MESSAGE() END CATCH

PRINT ''
PRINT 'BUNDLE R2 COMPLETADO!'
PRINT '================================================='
PRINT 'SISTEMA COMPLETO DE REPORTES ESBIRROSDB LISTO'
PRINT ''
PRINT 'Uso:'
PRINT '   EXEC sp_ReporteVentasDiario'
PRINT '   EXEC sp_PlatosMasVendidosDiario @top_cantidad = 5'
PRINT '   EXEC sp_RendimientoCanalDiario'
PRINT '   EXEC sp_AnalisisVentasMensual'
PRINT '   EXEC sp_RankingProductosMensual @top_cantidad = 10'
PRINT '   SELECT * FROM vw_DashboardEjecutivo'
PRINT '   SELECT * FROM vw_MonitoreoTiempoReal'
PRINT '   EXEC sp_ReporteVentasDiario @guardar_reporte = 1'
PRINT '================================================='
GO

