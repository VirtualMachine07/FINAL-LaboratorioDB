-- =============================================
-- BUNDLE R1 - REPORTES Y ESTRUCTURAS
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Tabla REPORTES_GENERADOS + SPs de reportes diarios y mensuales
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

USE EsbirrosDB;
GO

PRINT 'INICIANDO BUNDLE R1 - REPORTES (PARTE 1/2)'
PRINT '============================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- VERIFICACIÓN DE PREREQUISITOS
-- =============================================

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PEDIDOS')
BEGIN PRINT 'ERROR: Tabla PEDIDOS no encontrada. Ejecutar Bundle_A1 primero.'; RETURN END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DETALLES_PEDIDOS')
BEGIN PRINT 'ERROR: Tabla DETALLES_PEDIDOS no encontrada. Ejecutar Bundle_A1 primero.'; RETURN END

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ESTADOS_PEDIDOS')
BEGIN PRINT 'ERROR: Tabla ESTADOS_PEDIDOS no encontrada. Ejecutar Bundle_A1 primero.'; RETURN END

PRINT 'Prerequisitos verificados OK'
PRINT ''

-- =============================================
-- PASO 1: TABLA REPORTES_GENERADOS
-- =============================================

PRINT 'Paso 1/3: Creando tabla REPORTES_GENERADOS...'

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'REPORTES_GENERADOS')
BEGIN
    CREATE TABLE REPORTES_GENERADOS (
        reporte_id       INT           IDENTITY(1,1) PRIMARY KEY,
        tipo_reporte     NVARCHAR(50)  NOT NULL,
        fecha_generacion DATETIME      NOT NULL DEFAULT GETDATE(),
        fecha_reporte    DATE          NOT NULL,
        sucursal_id      INT           NULL,
        datos_json       NVARCHAR(MAX) NULL,
        ejecutado_por    NVARCHAR(100) DEFAULT SYSTEM_USER,
        estado           NVARCHAR(20)  DEFAULT 'COMPLETADO',
        observaciones    NVARCHAR(500) NULL,
        CONSTRAINT FK_REPORTES_sucursal FOREIGN KEY (sucursal_id) REFERENCES SUCURSALES(sucursal_id)
    );

    -- Índices para consultas frecuentes (mejorespracticas.md §4)
    CREATE INDEX IX_REPORTES_tipo_fecha  ON REPORTES_GENERADOS(tipo_reporte, fecha_reporte);
    CREATE INDEX IX_REPORTES_sucursal    ON REPORTES_GENERADOS(sucursal_id, fecha_reporte);
    CREATE INDEX IX_REPORTES_generacion  ON REPORTES_GENERADOS(fecha_generacion DESC);

    PRINT 'Tabla REPORTES_GENERADOS creada con índices'
END
ELSE PRINT 'Tabla REPORTES_GENERADOS ya existe'
GO

-- =============================================
-- PASO 2: SP REPORTE VENTAS DIARIO
-- =============================================

PRINT 'Paso 2/3: Creando SPs de reportes diarios...'
PRINT 'Creando SP: sp_ReporteVentasDiario...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ReporteVentasDiario]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_ReporteVentasDiario]
GO

CREATE PROCEDURE [dbo].[sp_ReporteVentasDiario]
    @fecha          DATE = NULL,
    @sucursal_id    INT  = NULL,
    @guardar_reporte BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha IS NULL SET @fecha = CAST(GETDATE() AS DATE);
    DECLARE @fecha_anterior DATE = DATEADD(DAY, -1, @fecha);

    DECLARE @facturacion_actual DECIMAL(18,2) = (
        SELECT SUM(p.total)
        FROM PEDIDOS p
        INNER JOIN ESTADOS_PEDIDOS ep  ON p.estado_id = ep.estado_id
        LEFT JOIN  MESAS           m   ON p.mesa_id   = m.mesa_id
        LEFT JOIN  EMPLEADOS       emp ON p.tomado_por_empleado_id = emp.empleado_id
        WHERE CAST(p.fecha_pedido AS DATE) = @fecha
          AND ep.nombre IN ('Entregado', 'Cerrado')
          AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id OR (p.mesa_id IS NULL AND emp.sucursal_id = @sucursal_id))
    );

    DECLARE @facturacion_ayer DECIMAL(18,2) = (
        SELECT SUM(p.total)
        FROM PEDIDOS p
        INNER JOIN ESTADOS_PEDIDOS ep  ON p.estado_id = ep.estado_id
        LEFT JOIN  MESAS           m   ON p.mesa_id   = m.mesa_id
        LEFT JOIN  EMPLEADOS       emp ON p.tomado_por_empleado_id = emp.empleado_id
        WHERE CAST(p.fecha_pedido AS DATE) = @fecha_anterior
          AND ep.nombre IN ('Entregado', 'Cerrado')
          AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id OR (p.mesa_id IS NULL AND emp.sucursal_id = @sucursal_id))
    );

    CREATE TABLE #ResultadoVentas (
        tipo_reporte            NVARCHAR(50),
        fecha_reporte           DATE,
        sucursal_nombre         NVARCHAR(100),
        facturacion_total       DECIMAL(18,2),
        pedidos_completados     INT,
        ticket_promedio         DECIMAL(18,2),
        facturacion_anterior    DECIMAL(18,2),
        porcentaje_crecimiento  DECIMAL(9,2),
        total_items_vendidos    INT,
        mesas_utilizadas        INT
    );

    INSERT INTO #ResultadoVentas
    SELECT
        'VENTAS_DIARIO',
        @fecha,
        s.nombre,
        ISNULL(@facturacion_actual, 0),
        (
            SELECT COUNT(DISTINCT p.pedido_id)
            FROM PEDIDOS p
            INNER JOIN ESTADOS_PEDIDOS ep  ON p.estado_id = ep.estado_id
            LEFT JOIN  MESAS           m  ON p.mesa_id   = m.mesa_id
            LEFT JOIN  EMPLEADOS     emp  ON p.tomado_por_empleado_id = emp.empleado_id
            WHERE CAST(p.fecha_pedido AS DATE) = @fecha
              AND ep.nombre IN ('Entregado', 'Cerrado')
              AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id OR (p.mesa_id IS NULL AND emp.sucursal_id = @sucursal_id))
        ),
        (
            SELECT AVG(sub.total)
            FROM (
                SELECT DISTINCT p.pedido_id, p.total
                FROM PEDIDOS p
                INNER JOIN ESTADOS_PEDIDOS ep  ON p.estado_id = ep.estado_id
                LEFT JOIN  MESAS           m  ON p.mesa_id   = m.mesa_id
                LEFT JOIN  EMPLEADOS     emp  ON p.tomado_por_empleado_id = emp.empleado_id
                WHERE CAST(p.fecha_pedido AS DATE) = @fecha
                  AND ep.nombre IN ('Entregado', 'Cerrado')
                  AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id OR (p.mesa_id IS NULL AND emp.sucursal_id = @sucursal_id))
            ) sub
        ),
        ISNULL(@facturacion_ayer, 0),
        CASE
            WHEN ISNULL(@facturacion_ayer, 0) > 0
            THEN ROUND((@facturacion_actual - @facturacion_ayer) * 100.0 / NULLIF(@facturacion_ayer, 0), 2)
            ELSE 0
        END,
        (
            SELECT SUM(dp.cantidad)
            FROM DETALLES_PEDIDOS dp
            INNER JOIN PEDIDOS        p3   ON dp.pedido_id = p3.pedido_id
            INNER JOIN ESTADOS_PEDIDOS ep3  ON p3.estado_id = ep3.estado_id
            LEFT JOIN  MESAS          m3   ON p3.mesa_id   = m3.mesa_id
            LEFT JOIN  EMPLEADOS      emp3 ON p3.tomado_por_empleado_id = emp3.empleado_id
            WHERE CAST(p3.fecha_pedido AS DATE) = @fecha
              AND ep3.nombre IN ('Entregado', 'Cerrado')
              AND (@sucursal_id IS NULL OR m3.sucursal_id = @sucursal_id OR (p3.mesa_id IS NULL AND emp3.sucursal_id = @sucursal_id))
        ),
        (
            SELECT COUNT(DISTINCT p.mesa_id)
            FROM PEDIDOS p
            LEFT JOIN MESAS     m   ON p.mesa_id = m.mesa_id
            LEFT JOIN EMPLEADOS emp ON p.tomado_por_empleado_id = emp.empleado_id
            WHERE CAST(p.fecha_pedido AS DATE) = @fecha
              AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id OR (p.mesa_id IS NULL AND emp.sucursal_id = @sucursal_id))
        )
    FROM SUCURSALES s
    WHERE (@sucursal_id IS NULL OR s.sucursal_id = @sucursal_id);

    SELECT * FROM #ResultadoVentas ORDER BY sucursal_nombre;

    IF @guardar_reporte = 1
    BEGIN
        DECLARE @json NVARCHAR(MAX);
        SELECT @json = (SELECT * FROM #ResultadoVentas FOR JSON PATH);
        INSERT INTO REPORTES_GENERADOS (tipo_reporte, fecha_reporte, sucursal_id, datos_json, observaciones)
        VALUES ('VENTAS_DIARIO', @fecha, @sucursal_id, @json, 'Reporte automático ventas diarias - EsbirrosDB');
    END;

    DROP TABLE #ResultadoVentas;
END
GO

-- =============================================
-- SP: TOP PLATOS MÁS VENDIDOS DIARIO
-- =============================================

PRINT 'Creando SP: sp_PlatosMasVendidosDiario...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_PlatosMasVendidosDiario]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_PlatosMasVendidosDiario]
GO

CREATE PROCEDURE [dbo].[sp_PlatosMasVendidosDiario]
    @fecha          DATE = NULL,
    @top_cantidad   INT  = 10,
    @sucursal_id    INT  = NULL,
    @guardar_reporte BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha IS NULL SET @fecha = CAST(GETDATE() AS DATE)

    CREATE TABLE #ResultadoPlatos (
        tipo_reporte        NVARCHAR(50),
        fecha_reporte       DATE,
        posicion            INT,
        plato_nombre        NVARCHAR(100),
        categoria           NVARCHAR(50),
        cantidad_vendida    INT,
        ingresos_generados  DECIMAL(10,2),
        pedidos_incluidos   INT,
        promedio_por_pedido DECIMAL(5,2)
    )

    INSERT INTO #ResultadoPlatos
    SELECT TOP (@top_cantidad)
        'TOP_PLATOS_DIARIO',
        @fecha,
        ROW_NUMBER() OVER (ORDER BY SUM(dp.cantidad) DESC),
        pl.nombre,
        pl.categoria,
        SUM(dp.cantidad),
        SUM(dp.subtotal),
        COUNT(DISTINCT p.pedido_id),
        ROUND(SUM(dp.cantidad) * 1.0 / COUNT(DISTINCT p.pedido_id), 2)
    FROM DETALLES_PEDIDOS dp
    INNER JOIN PEDIDOS        p  ON dp.pedido_id = p.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id  = ep.estado_id
    INNER JOIN PLATOS         pl  ON dp.plato_id  = pl.plato_id
    LEFT JOIN  MESAS          m   ON p.mesa_id    = m.mesa_id
    LEFT JOIN  EMPLEADOS      emp ON p.tomado_por_empleado_id = emp.empleado_id
    WHERE CAST(p.fecha_pedido AS DATE) = @fecha
      AND ep.nombre IN ('Entregado', 'Cerrado')
      AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id OR (p.mesa_id IS NULL AND emp.sucursal_id = @sucursal_id))
    GROUP BY pl.plato_id, pl.nombre, pl.categoria
    ORDER BY SUM(dp.cantidad) DESC

    SELECT * FROM #ResultadoPlatos ORDER BY posicion

    IF @guardar_reporte = 1
    BEGIN
        INSERT INTO REPORTES_GENERADOS (tipo_reporte, fecha_reporte, sucursal_id, datos_json, observaciones)
        VALUES (
            'TOP_PLATOS_DIARIO', @fecha, @sucursal_id,
            (SELECT * FROM #ResultadoPlatos FOR JSON PATH),
            'Top ' + CAST(@top_cantidad AS VARCHAR) + ' platos más vendidos del día'
        )
    END

    DROP TABLE #ResultadoPlatos
END
GO

-- =============================================
-- SP: RENDIMIENTO POR CANAL DIARIO
-- =============================================

PRINT 'Creando SP: sp_RendimientoCanalDiario...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RendimientoCanalDiario]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_RendimientoCanalDiario]
GO

CREATE PROCEDURE [dbo].[sp_RendimientoCanalDiario]
    @fecha          DATE = NULL,
    @sucursal_id    INT  = NULL,
    @guardar_reporte BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha IS NULL SET @fecha = CAST(GETDATE() AS DATE)

    DECLARE @total_facturacion DECIMAL(18,2) = (
        SELECT COALESCE(SUM(p.total), 0)
        FROM PEDIDOS p
        INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
        WHERE CAST(p.fecha_pedido AS DATE) = @fecha
          AND ep.nombre IN ('Entregado', 'Cerrado')
    );

    CREATE TABLE #ResultadoCanal (
        tipo_reporte            NVARCHAR(50),
        fecha_reporte           DATE,
        canal_nombre            NVARCHAR(50),
        total_pedidos           INT,
        pedidos_completados     INT,
        pedidos_pendientes      INT,
        pedidos_cancelados      INT,
        facturacion_canal       DECIMAL(18,2),
        ticket_promedio         DECIMAL(18,2),
        tasa_completacion       DECIMAL(9,2),
        porcentaje_facturacion  DECIMAL(9,2)
    )

    INSERT INTO #ResultadoCanal
    SELECT
        'RENDIMIENTO_CANAL_DIARIO',
        @fecha,
        cv.nombre,
        COUNT(p.pedido_id),
        COUNT(CASE WHEN ep.nombre IN ('Entregado', 'Cerrado') THEN p.pedido_id END),
        COUNT(CASE WHEN ep.nombre = 'Pendiente'               THEN p.pedido_id END),
        COUNT(CASE WHEN ep.nombre = 'Cancelado'               THEN p.pedido_id END),
        COALESCE(SUM(CASE WHEN ep.nombre IN ('Entregado', 'Cerrado') THEN p.total END), 0),
        COALESCE(AVG(CASE WHEN ep.nombre IN ('Entregado', 'Cerrado') THEN p.total END), 0),
        ROUND(
            COUNT(CASE WHEN ep.nombre IN ('Entregado','Cerrado') THEN p.pedido_id END) * 100.0
            / NULLIF(COUNT(p.pedido_id), 0), 2),
        CASE
            WHEN @total_facturacion > 0
            THEN ROUND(
                COALESCE(SUM(CASE WHEN ep.nombre IN ('Entregado','Cerrado') THEN p.total END), 0)
                * 100.0 / @total_facturacion, 2)
            ELSE 0
        END
    FROM CANALES_VENTAS cv
    LEFT JOIN PEDIDOS        p  ON cv.canal_id  = p.canal_id
                               AND CAST(p.fecha_pedido AS DATE) = @fecha
    LEFT JOIN ESTADOS_PEDIDOS ep ON p.estado_id  = ep.estado_id
    GROUP BY cv.canal_id, cv.nombre

    SELECT * FROM #ResultadoCanal ORDER BY facturacion_canal DESC

    IF @guardar_reporte = 1
    BEGIN
        INSERT INTO REPORTES_GENERADOS (tipo_reporte, fecha_reporte, sucursal_id, datos_json, observaciones)
        VALUES (
            'RENDIMIENTO_CANAL_DIARIO', @fecha, @sucursal_id,
            (SELECT * FROM #ResultadoCanal FOR JSON PATH),
            'Rendimiento por canal de venta del día'
        )
    END

    DROP TABLE #ResultadoCanal
END
GO

-- =============================================
-- PASO 3: SPs DE REPORTES MENSUALES
-- =============================================

PRINT 'Paso 3/3: Creando SPs de reportes mensuales...'
PRINT 'Creando SP: sp_AnalisisVentasMensual...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_AnalisisVentasMensual]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_AnalisisVentasMensual]
GO

CREATE PROCEDURE [dbo].[sp_AnalisisVentasMensual]
    @anio           INT = NULL,
    @mes            INT = NULL,
    @sucursal_id    INT = NULL,
    @guardar_reporte BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @anio IS NULL SET @anio = YEAR(GETDATE())
    IF @mes  IS NULL SET @mes  = MONTH(GETDATE())

    DECLARE @fecha_inicio DATE = DATEFROMPARTS(@anio, @mes, 1)
    DECLARE @fecha_fin    DATE = EOMONTH(@fecha_inicio)

    CREATE TABLE #ResultadoMensual (
        tipo_reporte            NVARCHAR(50),
        anio                    INT,
        mes                     INT,
        nombre_mes              NVARCHAR(20),
        sucursal_nombre         NVARCHAR(100),
        facturacion_total       DECIMAL(18,2),
        pedidos_completados     INT,
        pedidos_cancelados      INT,
        ticket_promedio         DECIMAL(18,2),
        total_items_vendidos    INT,
        dias_con_ventas         INT
    )

    INSERT INTO #ResultadoMensual
    SELECT
        'ANALISIS_MENSUAL',
        @anio,
        @mes,
        DATENAME(MONTH, @fecha_inicio),
        s.nombre,
        COALESCE(SUM(CASE WHEN ep.nombre IN ('Entregado','Cerrado') THEN p.total END), 0),
        COUNT(CASE WHEN ep.nombre IN ('Entregado','Cerrado') THEN p.pedido_id END),
        COUNT(CASE WHEN ep.nombre = 'Cancelado'              THEN p.pedido_id END),
        COALESCE(AVG(CASE WHEN ep.nombre IN ('Entregado','Cerrado') THEN p.total END), 0),
        (
            SELECT COALESCE(SUM(dp.cantidad), 0)
            FROM DETALLES_PEDIDOS dp
            INNER JOIN PEDIDOS        p2  ON dp.pedido_id = p2.pedido_id
            INNER JOIN ESTADOS_PEDIDOS ep2  ON p2.estado_id = ep2.estado_id
            LEFT JOIN  MESAS          m2   ON p2.mesa_id   = m2.mesa_id
            LEFT JOIN  EMPLEADOS      emp2 ON p2.tomado_por_empleado_id = emp2.empleado_id
            WHERE p2.fecha_pedido BETWEEN @fecha_inicio AND DATEADD(DAY,1,@fecha_fin)
              AND ep2.nombre IN ('Entregado', 'Cerrado')
              AND (@sucursal_id IS NULL OR m2.sucursal_id = @sucursal_id OR (p2.mesa_id IS NULL AND emp2.sucursal_id = @sucursal_id))
        ),
        COUNT(DISTINCT CAST(p.fecha_pedido AS DATE))
    FROM SUCURSALES s
    LEFT JOIN EMPLEADOS      e  ON s.sucursal_id = e.sucursal_id
    LEFT JOIN PEDIDOS        p  ON e.empleado_id = p.tomado_por_empleado_id
                               AND p.fecha_pedido BETWEEN @fecha_inicio AND DATEADD(DAY,1,@fecha_fin)
    LEFT JOIN ESTADOS_PEDIDOS ep ON p.estado_id   = ep.estado_id
    WHERE (@sucursal_id IS NULL OR s.sucursal_id = @sucursal_id)
    GROUP BY s.sucursal_id, s.nombre
    ORDER BY s.nombre

    SELECT * FROM #ResultadoMensual

    IF @guardar_reporte = 1
    BEGIN
        INSERT INTO REPORTES_GENERADOS (tipo_reporte, fecha_reporte, sucursal_id, datos_json, observaciones)
        VALUES (
            'ANALISIS_MENSUAL', @fecha_inicio, @sucursal_id,
            (SELECT * FROM #ResultadoMensual FOR JSON PATH),
            'Análisis mensual ' + CAST(@mes AS VARCHAR) + '/' + CAST(@anio AS VARCHAR)
        )
    END

    DROP TABLE #ResultadoMensual
END
GO

-- =============================================
-- SP: RANKING PRODUCTOS MENSUAL
-- =============================================

PRINT 'Creando SP: sp_RankingProductosMensual...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RankingProductosMensual]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_RankingProductosMensual]
GO

CREATE PROCEDURE [dbo].[sp_RankingProductosMensual]
    @anio         INT = NULL,
    @mes          INT = NULL,
    @top_cantidad INT = 10,
    @sucursal_id  INT = NULL,
    @guardar_reporte BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @anio IS NULL SET @anio = YEAR(GETDATE())
    IF @mes  IS NULL SET @mes  = MONTH(GETDATE())

    DECLARE @fecha_inicio DATE = DATEFROMPARTS(@anio, @mes, 1)
    DECLARE @fecha_fin    DATE = EOMONTH(@fecha_inicio)

    SELECT TOP (@top_cantidad)
        ROW_NUMBER() OVER (ORDER BY SUM(dp.cantidad) DESC) AS posicion,
        pl.nombre                                          AS plato_nombre,
        pl.categoria,
        SUM(dp.cantidad)                                   AS cantidad_total,
        SUM(dp.subtotal)                                   AS ingresos_generados,
        COUNT(DISTINCT p.pedido_id)                        AS pedidos_incluidos,
        ROUND(SUM(dp.cantidad) * 1.0 / COUNT(DISTINCT p.pedido_id), 2) AS promedio_por_pedido,
        MAX(dp.precio_unitario)                            AS precio_maximo,
        MIN(dp.precio_unitario)                            AS precio_minimo
    FROM DETALLES_PEDIDOS dp
    INNER JOIN PEDIDOS        p  ON dp.pedido_id = p.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id  = ep.estado_id
    INNER JOIN PLATOS         pl  ON dp.plato_id  = pl.plato_id
    LEFT JOIN  MESAS          m   ON p.mesa_id    = m.mesa_id
    LEFT JOIN  EMPLEADOS      emp ON p.tomado_por_empleado_id = emp.empleado_id
    WHERE p.fecha_pedido BETWEEN @fecha_inicio AND DATEADD(DAY,1,@fecha_fin)
      AND ep.nombre IN ('Entregado', 'Cerrado')
      AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id OR (p.mesa_id IS NULL AND emp.sucursal_id = @sucursal_id))
    GROUP BY pl.plato_id, pl.nombre, pl.categoria
    ORDER BY SUM(dp.cantidad) DESC
END
GO

-- =============================================
-- VALIDACIÓN
-- =============================================

PRINT ''
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ReporteVentasDiario]')     AND type in (N'P',N'PC')) PRINT 'sp_ReporteVentasDiario    : OK' ELSE PRINT 'sp_ReporteVentasDiario    : ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_PlatosMasVendidosDiario]') AND type in (N'P',N'PC')) PRINT 'sp_PlatosMasVendidosDiario: OK' ELSE PRINT 'sp_PlatosMasVendidosDiario: ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RendimientoCanalDiario]')  AND type in (N'P',N'PC')) PRINT 'sp_RendimientoCanalDiario : OK' ELSE PRINT 'sp_RendimientoCanalDiario : ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_AnalisisVentasMensual]')   AND type in (N'P',N'PC')) PRINT 'sp_AnalisisVentasMensual  : OK' ELSE PRINT 'sp_AnalisisVentasMensual  : ERROR'
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RankingProductosMensual]') AND type in (N'P',N'PC')) PRINT 'sp_RankingProductosMensual: OK' ELSE PRINT 'sp_RankingProductosMensual: ERROR'
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES   WHERE TABLE_NAME = 'REPORTES_GENERADOS')            PRINT 'REPORTES_GENERADOS        : OK' ELSE PRINT 'REPORTES_GENERADOS        : ERROR'

PRINT ''
PRINT 'BUNDLE R1 COMPLETADO!'
PRINT '============================================='
PRINT 'SPs creados:'
PRINT '   sp_ReporteVentasDiario     - Ventas del día'
PRINT '   sp_PlatosMasVendidosDiario - Top platos del día'
PRINT '   sp_RendimientoCanalDiario  - Rendimiento por canal'
PRINT '   sp_AnalisisVentasMensual   - Análisis mensual'
PRINT '   sp_RankingProductosMensual - Ranking mensual'
PRINT 'Tabla: REPORTES_GENERADOS + 3 índices'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_R2_Reportes_Vistas_Dashboard.sql'
PRINT '============================================='
GO

-- =============================================
-- PERMISOS DIFERIDOS: REPORTES_GENERADOS
-- (requiere que Bundle_C_Seguridad se haya ejecutado antes)
-- =============================================
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_aplicacion_web')
BEGIN
    GRANT SELECT ON dbo.REPORTES_GENERADOS TO [rol_aplicacion_web];
    PRINT 'Permiso SELECT sobre REPORTES_GENERADOS aplicado a rol_aplicacion_web'
END
GO

