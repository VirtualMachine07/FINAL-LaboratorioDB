-- =============================================
-- SCRIPT DE VALIDACIÓN POST-BUNDLES - ESBIRROSDB
-- Verifica que todos los componentes estén instalados
-- correctamente después de ejecutar todos los bundles.
-- Negocio: Bodegón Los Esbirros de Claudio
-- Fecha: 2026
-- =============================================

USE EsbirrosDB;
GO

PRINT '======================================================='
PRINT 'VALIDACION POST-BUNDLES - ESBIRROSDB'
PRINT '======================================================='
PRINT 'Negocio: Bodegon Los Esbirros de Claudio'
PRINT 'Verificando instalacion completa...'
PRINT ''

DECLARE @TotalComponentes INT = 0
DECLARE @ComponentesOK    INT = 0
DECLARE @ComponentesError INT = 0

-- =============================================
-- 1. BUNDLE A1 - INFRAESTRUCTURA BASE
-- =============================================
PRINT '1. VALIDANDO BUNDLE A1 - INFRAESTRUCTURA BASE'
PRINT '=============================================='

-- Tablas esperadas (12 tablas de A1)
DECLARE @TablasEsperadas TABLE (tabla VARCHAR(50))
INSERT INTO @TablasEsperadas VALUES
('SUCURSALES'),('CANALES_VENTAS'),('ESTADOS_PEDIDOS'),('ROLES'),
('MESAS'),('EMPLEADOS'),
('CLIENTES'),('DOMICILIOS'),
('PLATOS'),('PRECIOS'),
('PEDIDOS'),('DETALLES_PEDIDOS')

DECLARE @TablasEncontradas INT
SELECT @TablasEncontradas = COUNT(*)
FROM INFORMATION_SCHEMA.TABLES t
INNER JOIN @TablasEsperadas te ON t.TABLE_NAME = te.tabla
WHERE t.TABLE_TYPE = 'BASE TABLE'

DECLARE @TablasTotal INT
SELECT @TablasTotal = COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_NAME NOT LIKE 'MSreplication%'
  AND TABLE_NAME NOT LIKE 'spt_%'

SET @TotalComponentes += 1
IF @TablasEncontradas >= 12
BEGIN
    PRINT 'TABLAS PRINCIPALES: ' + CAST(@TablasEncontradas AS VARCHAR) + '/12 - OK'
    PRINT '  Total tablas en BD: ' + CAST(@TablasTotal AS VARCHAR) + ' (incluye auxiliares de triggers)'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'TABLAS PRINCIPALES: ' + CAST(@TablasEncontradas AS VARCHAR) + '/12 - ERROR'
    SET @ComponentesError += 1
END

-- Verificar que COMBO y PROMOCION NO existen
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('COMBO','COMBO_DETALLE','PROMOCION','PROMOCION_PLATO'))
    PRINT 'ADVERTENCIA: Se encontraron tablas COMBO/PROMOCION que deberian estar eliminadas!'
ELSE
    PRINT 'Tablas COMBO/PROMOCION: Correctamente eliminadas OK'

-- Verificar datos de referencia
DECLARE @EstadosPedido INT, @CanalesVenta INT, @Roles INT
SELECT @EstadosPedido = COUNT(*) FROM ESTADOS_PEDIDOS
SELECT @CanalesVenta  = COUNT(*) FROM CANALES_VENTAS
SELECT @Roles         = COUNT(*) FROM ROLES

SET @TotalComponentes += 1
IF @EstadosPedido >= 3 AND @CanalesVenta >= 3 AND @Roles >= 3
BEGIN
    PRINT 'DATOS REFERENCIA: Estados(' + CAST(@EstadosPedido AS VARCHAR) +
          ') Canales(' + CAST(@CanalesVenta AS VARCHAR) +
          ') Roles(' + CAST(@Roles AS VARCHAR) + ') - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'DATOS REFERENCIA: ERROR - faltan datos iniciales'
    SET @ComponentesError += 1
END

-- Verificar platos del menú (bodegón)
DECLARE @Platos INT, @Precios INT
SELECT @Platos  = COUNT(*) FROM PLATOS
SELECT @Precios = COUNT(*) FROM PRECIOS

SET @TotalComponentes += 1
IF @Platos >= 10 AND @Precios >= 10
BEGIN
    PRINT 'MENU BODEGON: ' + CAST(@Platos AS VARCHAR) + ' platos, ' + CAST(@Precios AS VARCHAR) + ' precios - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'MENU BODEGON: Solo ' + CAST(@Platos AS VARCHAR) + ' platos / ' + CAST(@Precios AS VARCHAR) + ' precios - REVISAR'
    SET @ComponentesError += 1
END

PRINT ''

-- =============================================
-- 2. BUNDLES B1/B2/B3 - LÓGICA DE NEGOCIO
-- =============================================
PRINT '2. VALIDANDO BUNDLES B1/B2/B3 - LOGICA DE NEGOCIO'
PRINT '==================================================='

DECLARE @SPsNegocio TABLE (sp_name VARCHAR(100))
INSERT INTO @SPsNegocio VALUES
('sp_CrearPedido'),('sp_AgregarItemPedido'),('sp_CalcularTotalPedido'),
('sp_CerrarPedido'),('sp_CancelarPedido'),('sp_ActualizarEstadoPedido')

DECLARE @SPsEncontrados INT
SELECT @SPsEncontrados = COUNT(*)
FROM sys.objects o
INNER JOIN @SPsNegocio sp ON o.name = sp.sp_name
WHERE o.type = 'P'

SET @TotalComponentes += 1
IF @SPsEncontrados = 6
BEGIN
    PRINT 'SPs NEGOCIO: ' + CAST(@SPsEncontrados AS VARCHAR) + '/6 - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'SPs NEGOCIO: ' + CAST(@SPsEncontrados AS VARCHAR) + '/6 - ERROR'
    SET @ComponentesError += 1
END

-- Verificar que sp_AgregarItemPedido no tiene @combo_id
-- (validación de que la adaptación fue correcta)
DECLARE @def_sp NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_AgregarItemPedido'))
SET @TotalComponentes += 1
IF @def_sp IS NOT NULL AND CHARINDEX('combo_id', @def_sp) = 0
BEGIN
    PRINT 'sp_AgregarItemPedido SIN combo_id: OK (adaptacion correcta)'
    SET @ComponentesOK += 1
END
ELSE IF @def_sp IS NULL
BEGIN
    PRINT 'sp_AgregarItemPedido: No encontrado'
    SET @ComponentesError += 1
END
ELSE
BEGIN
    PRINT 'ADVERTENCIA: sp_AgregarItemPedido aun tiene referencia a combo_id!'
    SET @ComponentesError += 1
END

PRINT ''

-- =============================================
-- 3. BUNDLE C - SEGURIDAD
-- =============================================
PRINT '3. VALIDANDO BUNDLE C - SEGURIDAD'
PRINT '==================================='

DECLARE @RolesSeguridad INT
SELECT @RolesSeguridad = COUNT(*)
FROM sys.database_principals
WHERE type = 'R' AND name LIKE 'rol_%'

SET @TotalComponentes += 1
IF @RolesSeguridad >= 9
BEGIN
    PRINT 'ROLES SEGURIDAD: ' + CAST(@RolesSeguridad AS VARCHAR) + '/9 roles - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'ROLES SEGURIDAD: ' + CAST(@RolesSeguridad AS VARCHAR) + '/9 roles - ERROR (esperados 9)'
    SET @ComponentesError += 1
END

-- Verificar función de seguridad
SET @TotalComponentes += 1
IF OBJECT_ID('fn_ValidarPermisoUsuario', 'FN') IS NOT NULL
BEGIN PRINT 'fn_ValidarPermisoUsuario: OK'; SET @ComponentesOK += 1 END
ELSE BEGIN PRINT 'fn_ValidarPermisoUsuario: ERROR'; SET @ComponentesError += 1 END

DECLARE @UsuariosApp INT
SELECT @UsuariosApp = COUNT(*) FROM sys.database_principals WHERE name LIKE 'app_esbirros%'

PRINT 'USUARIOS APLICACION (app_esbirros_*): ' + CAST(@UsuariosApp AS VARCHAR)

PRINT ''

-- =============================================
-- 4. BUNDLE D - CONSULTAS BÁSICAS
-- =============================================
PRINT '4. VALIDANDO BUNDLE D - CONSULTAS BASICAS'
PRINT '==========================================='

DECLARE @Vistas INT
SELECT @Vistas = COUNT(*) FROM sys.views WHERE name LIKE 'vw_%'

SET @TotalComponentes += 1
IF @Vistas >= 2
BEGIN
    PRINT 'VISTAS (vw_*): ' + CAST(@Vistas AS VARCHAR) + ' - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'VISTAS: ' + CAST(@Vistas AS VARCHAR) + ' - ERROR (esperadas al menos 2)'
    SET @ComponentesError += 1
END

PRINT ''

-- =============================================
-- 5. BUNDLES E1/E2 - AUTOMATIZACIÓN
-- =============================================
PRINT '5. VALIDANDO BUNDLES E1/E2 - AUTOMATIZACION'
PRINT '============================================='

DECLARE @TriggersEsperados TABLE (trigger_name VARCHAR(100))
INSERT INTO @TriggersEsperados VALUES
('tr_ActualizarTotales'),('tr_AuditoriaPedidos'),('tr_AuditoriaDetalle'),
('tr_ValidarStock'),('tr_SistemaNotificaciones')

DECLARE @TriggersEncontrados INT
SELECT @TriggersEncontrados = COUNT(*)
FROM sys.triggers t
INNER JOIN @TriggersEsperados te ON t.name = te.trigger_name
WHERE t.is_disabled = 0

SET @TotalComponentes += 1
IF @TriggersEncontrados = 5
BEGIN
    PRINT 'TRIGGERS: ' + CAST(@TriggersEncontrados AS VARCHAR) + '/5 - OK'
    SET @ComponentesOK += 1
END
ELSE IF @TriggersEncontrados >= 3
BEGIN
    PRINT 'TRIGGERS: ' + CAST(@TriggersEncontrados AS VARCHAR) + '/5 - PARCIAL (Bundle_E2 puede estar incompleto)'
    SET @ComponentesError += 1
END
ELSE
BEGIN
    PRINT 'TRIGGERS: ' + CAST(@TriggersEncontrados AS VARCHAR) + '/5 - ERROR'
    SET @ComponentesError += 1
END

DECLARE @TablasControl INT = 0
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AUDITORIAS_SIMPLES')  SET @TablasControl += 1
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'STOCKS_SIMULADOS')    SET @TablasControl += 1
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'NOTIFICACIONES')    SET @TablasControl += 1

SET @TotalComponentes += 1
IF @TablasControl >= 2
BEGIN
    PRINT 'TABLAS CONTROL: ' + CAST(@TablasControl AS VARCHAR) + '/3 - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'TABLAS CONTROL: ' + CAST(@TablasControl AS VARCHAR) + '/3 - ERROR'
    SET @ComponentesError += 1
END

-- Verificar SPs de Bundle_E2
DECLARE @SPsE2 INT = 0
IF OBJECT_ID('sp_ConsultarNotificaciones', 'P') IS NOT NULL SET @SPsE2 += 1
IF OBJECT_ID('sp_MarcarNotificacionLeida',  'P') IS NOT NULL SET @SPsE2 += 1
IF OBJECT_ID('sp_ConsultarStock',           'P') IS NOT NULL SET @SPsE2 += 1

SET @TotalComponentes += 1
IF @SPsE2 = 3
BEGIN
    PRINT 'SPs BUNDLE E2: 3/3 (Notificaciones + Stock) - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'SPs BUNDLE E2: ' + CAST(@SPsE2 AS VARCHAR) + '/3 - ERROR'
    SET @ComponentesError += 1
END

PRINT ''

-- =============================================
-- 6. BUNDLES R1/R2 - REPORTES
-- =============================================
PRINT '6. VALIDANDO BUNDLES R1/R2 - REPORTES'
PRINT '======================================='

DECLARE @SPsReportes TABLE (sp_name VARCHAR(100))
INSERT INTO @SPsReportes VALUES
('sp_ReporteVentasDiario'),('sp_PlatosMasVendidosDiario'),
('sp_RendimientoCanalDiario'),('sp_AnalisisVentasMensual'),
('sp_RankingProductosMensual')

DECLARE @SPsReportesOK INT
SELECT @SPsReportesOK = COUNT(*)
FROM sys.objects o
INNER JOIN @SPsReportes sp ON o.name = sp.sp_name
WHERE o.type = 'P'

SET @TotalComponentes += 1
IF @SPsReportesOK = 5
BEGIN
    PRINT 'SPs REPORTES: ' + CAST(@SPsReportesOK AS VARCHAR) + '/5 - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'SPs REPORTES: ' + CAST(@SPsReportesOK AS VARCHAR) + '/5 - ERROR'
    SET @ComponentesError += 1
END

DECLARE @VistasDashboard INT
SELECT @VistasDashboard = COUNT(*)
FROM sys.views WHERE name IN ('vw_DashboardEjecutivo','vw_MonitoreoTiempoReal')

SET @TotalComponentes += 1
IF @VistasDashboard = 2
BEGIN
    PRINT 'VISTAS DASHBOARD: 2/2 - OK'
    SET @ComponentesOK += 1
END
ELSE
BEGIN
    PRINT 'VISTAS DASHBOARD: ' + CAST(@VistasDashboard AS VARCHAR) + '/2 - ERROR'
    SET @ComponentesError += 1
END

SET @TotalComponentes += 1
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'REPORTES_GENERADOS')
BEGIN PRINT 'TABLA REPORTES_GENERADOS: OK'; SET @ComponentesOK += 1 END
ELSE BEGIN PRINT 'TABLA REPORTES_GENERADOS: ERROR'; SET @ComponentesError += 1 END

PRINT ''

-- =============================================
-- 7. PRUEBAS FUNCIONALES RÁPIDAS
-- =============================================
PRINT '7. PRUEBAS FUNCIONALES'
PRINT '========================'

BEGIN TRY
    DECLARE @t1 INT; SELECT @t1 = COUNT(*) FROM vw_DashboardEjecutivo
    PRINT 'vw_DashboardEjecutivo  : Funcional'
END TRY BEGIN CATCH PRINT 'vw_DashboardEjecutivo  : ERROR - ' + ERROR_MESSAGE() END CATCH

BEGIN TRY
    DECLARE @t2 INT; SELECT @t2 = COUNT(*) FROM vw_MonitoreoTiempoReal
    PRINT 'vw_MonitoreoTiempoReal : Funcional'
END TRY BEGIN CATCH PRINT 'vw_MonitoreoTiempoReal : ERROR - ' + ERROR_MESSAGE() END CATCH

BEGIN TRY
    DECLARE @t3 INT; SELECT @t3 = COUNT(*) FROM vw_PedidosCompletos
    PRINT 'vw_PedidosCompletos    : Funcional'
END TRY BEGIN CATCH PRINT 'vw_PedidosCompletos    : ERROR - ' + ERROR_MESSAGE() END CATCH

PRINT ''

-- =============================================
-- RESUMEN FINAL
-- =============================================
PRINT '======================================================='
PRINT 'RESUMEN FINAL DE VALIDACION'
PRINT '======================================================='

DECLARE @PctExito DECIMAL(5,2) = (@ComponentesOK * 100.0) / NULLIF(@TotalComponentes, 0)

PRINT 'Total evaluados  : ' + CAST(@TotalComponentes AS VARCHAR)
PRINT 'Exitosos         : ' + CAST(@ComponentesOK    AS VARCHAR)
PRINT 'Con errores      : ' + CAST(@ComponentesError AS VARCHAR)
PRINT 'Porcentaje exito : ' + CAST(@PctExito AS VARCHAR) + '%'
PRINT ''

IF @PctExito >= 90
BEGIN
    PRINT 'ESTADO: SISTEMA COMPLETAMENTE FUNCIONAL'
    PRINT 'EsbirrosDB listo para uso.'
    PRINT ''
    PRINT 'PROXIMOS PASOS:'
    PRINT '1. Cargar 10.000+ registros con BULK INSERT (mejorespracticas.md §3)'
    PRINT '2. Configurar AWS RDS (SQL Server Express, T3 micro)'
    PRINT '3. Realizar backup inicial (.bak)'
    PRINT '4. Documentar prompt de IA utilizado en la carga masiva'
END
ELSE IF @PctExito >= 70
BEGIN
    PRINT 'ESTADO: SISTEMA FUNCIONAL CON OBSERVACIONES'
    PRINT 'Verificar componentes con error antes de continuar.'
END
ELSE
BEGIN
    PRINT 'ESTADO: SISTEMA INCOMPLETO'
    PRINT 'Re-ejecutar los bundles en orden: A1→A2→B1→B2→B3→C→D→E1→E2→R1→R2'
END

-- Estadísticas reales
DECLARE @TablasReales INT, @VistasReales INT, @TriggersReales INT, @SPsReales INT
SELECT @TablasReales   = COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME NOT LIKE 'MSreplication%' AND TABLE_NAME NOT LIKE 'spt_%'
SELECT @VistasReales   = COUNT(*) FROM sys.views
SELECT @TriggersReales = COUNT(*) FROM sys.triggers WHERE is_disabled = 0 AND parent_class = 1
SELECT @SPsReales      = COUNT(*) FROM sys.objects WHERE type = 'P' AND is_ms_shipped = 0

PRINT ''
PRINT 'ESTADISTICAS REALES:'
PRINT '  Tablas de usuario : ' + CAST(@TablasReales   AS VARCHAR)
PRINT '  Vistas            : ' + CAST(@VistasReales   AS VARCHAR)
PRINT '  Triggers activos  : ' + CAST(@TriggersReales AS VARCHAR)
PRINT '  Stored Procedures : ' + CAST(@SPsReales      AS VARCHAR)
PRINT ''
PRINT 'Fecha validacion: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT 'Base de datos   : ' + DB_NAME()
PRINT 'Negocio         : Bodegon Los Esbirros de Claudio'
PRINT 'Sistema         : EsbirrosDB v2.0'
PRINT '======================================================='
GO

