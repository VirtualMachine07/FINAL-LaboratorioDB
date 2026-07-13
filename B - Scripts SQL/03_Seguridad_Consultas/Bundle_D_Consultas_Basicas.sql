-- =============================================
-- BUNDLE D - CONSULTAS BÁSICAS
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: SPs y vistas para consultas operativas
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================

USE EsbirrosDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT 'INICIANDO BUNDLE D - CONSULTAS BASICAS'
PRINT '========================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- SP 1: CONSULTAR MENÚ ACTUAL
-- =============================================

PRINT 'Creando SP: sp_ConsultarMenuActual...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarMenuActual]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_ConsultarMenuActual]
GO

CREATE PROCEDURE [dbo].[sp_ConsultarMenuActual]
    -- @sucursal_id eliminado: no se utiliza en la consulta (HM-12)
    @categoria   NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.plato_id,
        p.nombre       AS plato_nombre,
        p.categoria,
        pr.monto        AS precio_actual,
        pr.vigencia_desde,
        pr.vigencia_hasta,
        CASE
            WHEN pr.vigencia_hasta IS NULL          THEN 'Vigente'
            WHEN pr.vigencia_hasta >= GETDATE()     THEN 'Vigente'
            ELSE 'Vencido'
        END            AS estado_precio,
        p.activo
    FROM PLATOS p
    INNER JOIN PRECIOS pr ON p.plato_id = pr.plato_id
    WHERE p.activo = 1
      AND pr.vigencia_desde <= GETDATE()
      AND (pr.vigencia_hasta IS NULL OR pr.vigencia_hasta >= GETDATE())
      AND (@categoria IS NULL OR p.categoria = @categoria)
    ORDER BY p.categoria, p.nombre
END
GO

-- =============================================
-- SP 2: MESAS DISPONIBLES
-- =============================================

PRINT 'Creando SP: sp_MesasDisponibles...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_MesasDisponibles]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_MesasDisponibles]
GO

CREATE PROCEDURE [dbo].[sp_MesasDisponibles]
    @sucursal_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        m.mesa_id,
        m.numero                 AS mesa_numero,
        m.capacidad,
        s.nombre                 AS sucursal_nombre,
        m.qr_token,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM PEDIDOS p
                INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
                WHERE p.mesa_id = m.mesa_id
                  AND ep.nombre NOT IN ('Cerrado', 'Cancelado')
            ) THEN 'Ocupada'
            ELSE 'Disponible'
        END                      AS estado_mesa,
        (
            SELECT TOP 1 p.pedido_id
            FROM PEDIDOS p
            INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
            WHERE p.mesa_id = m.mesa_id
              AND ep.nombre NOT IN ('Cerrado', 'Cancelado')
            ORDER BY p.fecha_pedido DESC
        )                        AS pedido_activo_id
    FROM MESAS m
    INNER JOIN SUCURSALES s ON m.sucursal_id = s.sucursal_id
    WHERE m.activa = 1
      AND (@sucursal_id IS NULL OR m.sucursal_id = @sucursal_id)
    ORDER BY s.nombre, m.numero
END
GO

-- =============================================
-- VISTA 1: PEDIDOS COMPLETOS
-- =============================================

PRINT 'Creando Vista: vw_PedidosCompletos...'

IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_PedidosCompletos]'))
    DROP VIEW [dbo].[vw_PedidosCompletos]
GO

CREATE VIEW [dbo].[vw_PedidosCompletos]
AS
SELECT
    -- PEDIDOS
    p.pedido_id,
    p.fecha_pedido,
    FORMAT(p.fecha_pedido, 'yyyy-MM-dd')  AS fecha_pedido_formato,
    FORMAT(p.fecha_pedido, 'HH:mm')       AS hora_pedido,
    DATENAME(weekday, p.fecha_pedido)     AS dia_semana,

    -- Estado
    ep.nombre AS estado_nombre,
    ep.orden  AS estado_orden,

    -- Canal
    cv.nombre AS canal_nombre,

    -- CLIENTES
    c.cliente_id,
    c.nombre   AS cliente_nombre,
    c.telefono AS cliente_telefono,
    c.email    AS cliente_email,

    -- MESAS
    m.mesa_id,
    m.numero   AS mesa_numero,
    m.capacidad AS mesa_capacidad,
    p.cant_comensales,

    -- EMPLEADOS
    e.empleado_id,
    e.nombre   AS empleado_nombre,
    e.usuario  AS empleado_usuario,

    -- SUCURSALES
    s.sucursal_id,
    s.nombre   AS sucursal_nombre,
    s.direccion AS sucursal_direccion,

    -- Totales
    p.total    AS total_pedido,

    -- Tiempos
    p.fecha_entrega,
    CASE
        WHEN p.fecha_entrega IS NOT NULL
        THEN DATEDIFF(MINUTE, p.fecha_pedido, p.fecha_entrega)
        ELSE DATEDIFF(MINUTE, p.fecha_pedido, GETDATE())
    END        AS minutos_transcurridos

FROM PEDIDOS p
INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id              = ep.estado_id
INNER JOIN CANALES_VENTAS   cv ON p.canal_id               = cv.canal_id
INNER JOIN EMPLEADOS      e  ON p.tomado_por_empleado_id = e.empleado_id
INNER JOIN SUCURSALES      s  ON e.sucursal_id            = s.sucursal_id
LEFT JOIN  MESAS          m  ON p.mesa_id                = m.mesa_id
LEFT JOIN  CLIENTES       c  ON p.cliente_id             = c.cliente_id
GO

-- =============================================
-- VISTA 2: ESTADO DE MESAS
-- =============================================

PRINT 'Creando Vista: vw_EstadoMesas...'

IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_EstadoMesas]'))
    DROP VIEW [dbo].[vw_EstadoMesas]
GO

CREATE VIEW [dbo].[vw_EstadoMesas]
AS
SELECT
    m.mesa_id,
    m.numero    AS mesa_numero,
    m.capacidad,
    m.qr_token,
    s.sucursal_id,
    s.nombre    AS sucursal_nombre,

    CASE
        WHEN EXISTS (
            SELECT 1 FROM PEDIDOS p
            INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
            WHERE p.mesa_id = m.mesa_id
              AND ep.nombre NOT IN ('Cerrado', 'Cancelado', 'Entregado')
        ) THEN 'Ocupada'
        ELSE 'Disponible'
    END         AS estado_actual,

    pa.pedido_id       AS pedido_activo_id,
    pa.fecha_pedido    AS pedido_inicio,
    pa.cant_comensales,
    pa.total,
    epa.nombre         AS estado_pedido_activo,
    ea.nombre          AS empleado_responsable,

    CASE
        WHEN pa.pedido_id IS NOT NULL
        THEN DATEDIFF(MINUTE, pa.fecha_pedido, GETDATE())
        ELSE 0
    END         AS minutos_ocupada,

    CASE
        WHEN m.activa = 0                          THEN 'Fuera de servicio'
        WHEN pa.pedido_id IS NULL                  THEN 'Lista para uso'
        WHEN epa.nombre = 'Pendiente'              THEN 'Esperando orden'
        WHEN epa.nombre IN ('Confirmado', 'En Preparación') THEN 'Comida en preparacion'
        WHEN epa.nombre = 'Listo'                  THEN 'Comida lista'
        ELSE 'En uso'
    END         AS estado_operativo

FROM MESAS m
INNER JOIN SUCURSALES s ON m.sucursal_id = s.sucursal_id
LEFT JOIN (
    SELECT
        p.mesa_id,
        p.pedido_id,
        p.fecha_pedido,
        p.cant_comensales,
        p.total,
        p.estado_id,
        p.tomado_por_empleado_id,
        ROW_NUMBER() OVER (PARTITION BY p.mesa_id ORDER BY p.fecha_pedido DESC) AS rn
    FROM PEDIDOS p
    INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
    WHERE ep.nombre NOT IN ('Cerrado', 'Cancelado', 'Entregado')
) pa ON m.mesa_id = pa.mesa_id AND pa.rn = 1
LEFT JOIN ESTADOS_PEDIDOS epa ON pa.estado_id              = epa.estado_id
LEFT JOIN EMPLEADOS      ea  ON pa.tomado_por_empleado_id = ea.empleado_id
GO

-- =============================================
-- SP 3: CONSULTAR PEDIDOS POR ESTADO
-- (COMBO eliminado — solo referencias a PLATOS)
-- =============================================

PRINT 'Creando SP: sp_ConsultarPedidosPorEstado...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarPedidosPorEstado]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_ConsultarPedidosPorEstado]
GO

CREATE PROCEDURE [dbo].[sp_ConsultarPedidosPorEstado]
    @estado_nombre NVARCHAR(50) = NULL,
    @sucursal_id   INT          = NULL,
    @fecha_desde   DATE         = NULL,
    @fecha_hasta   DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha_desde IS NULL SET @fecha_desde = CAST(GETDATE() AS DATE)
    IF @fecha_hasta IS NULL SET @fecha_hasta = CAST(GETDATE() AS DATE)

    SELECT
        pc.pedido_id,
        pc.fecha_pedido,
        pc.hora_pedido,
        pc.estado_nombre,
        pc.canal_nombre,
        pc.mesa_numero,
        pc.cliente_nombre,
        pc.empleado_nombre,
        pc.sucursal_nombre,
        pc.total_pedido,
        pc.minutos_transcurridos,

        -- Cantidad de ítems del PEDIDOS
        (SELECT COUNT(*) FROM DETALLES_PEDIDOS dp WHERE dp.pedido_id = pc.pedido_id) AS cantidad_items,

        -- Detalle en texto (solo platos — COMBO eliminado)
        (
            SELECT STRING_AGG(pl.nombre + ' (x' + CAST(dp.cantidad AS VARCHAR) + ')', ', ')
            FROM DETALLES_PEDIDOS dp
            INNER JOIN PLATOS pl ON dp.plato_id = pl.plato_id
            WHERE dp.pedido_id = pc.pedido_id
        ) AS items_pedido

    FROM vw_PedidosCompletos pc
    WHERE (@estado_nombre IS NULL OR pc.estado_nombre = @estado_nombre)
      AND (@sucursal_id   IS NULL OR pc.sucursal_id   = @sucursal_id)
      AND pc.fecha_pedido_formato >= @fecha_desde
      AND pc.fecha_pedido_formato <= @fecha_hasta
    ORDER BY pc.fecha_pedido DESC
END
GO

-- =============================================
-- SP 4: RESUMEN OPERATIVO DIARIO
-- =============================================

PRINT 'Creando SP: sp_ResumenOperativoDiario...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ResumenOperativoDiario]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_ResumenOperativoDiario]
GO

CREATE PROCEDURE [dbo].[sp_ResumenOperativoDiario]
    @fecha       DATE = NULL,
    @sucursal_id INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha IS NULL SET @fecha = CAST(GETDATE() AS DATE)

    SELECT
        'RESUMEN DEL DIA'   AS tipo_reporte,
        @fecha              AS fecha_reporte,
        s.nombre            AS SUCURSALES,

        COUNT(DISTINCT p.pedido_id)                                                           AS total_pedidos,
        COUNT(DISTINCT CASE WHEN ep.nombre = 'Cerrado'   THEN p.pedido_id END)                AS pedidos_cerrados,
        COUNT(DISTINCT CASE WHEN ep.nombre = 'Cancelado' THEN p.pedido_id END)                AS pedidos_cancelados,
        COUNT(DISTINCT CASE WHEN ep.nombre NOT IN ('Cerrado','Cancelado') THEN p.pedido_id END) AS pedidos_activos,

        SUM(CASE WHEN ep.nombre = 'Cerrado' THEN p.total ELSE 0 END)                         AS facturacion_total,
        AVG(CASE WHEN ep.nombre = 'Cerrado' THEN p.total ELSE NULL END)                       AS ticket_promedio,

        COUNT(DISTINCT p.mesa_id)                                                             AS mesas_utilizadas,
        COUNT(DISTINCT CASE WHEN cv.nombre = 'Delivery'  THEN p.pedido_id END)                AS pedidos_delivery,
        COUNT(DISTINCT CASE WHEN cv.nombre = 'MESAS QR'   THEN p.pedido_id END)                AS pedidos_qr,

        SUM(dp.cantidad)                                                                      AS total_items_vendidos,
        COUNT(DISTINCT dp.plato_id)                                                           AS platos_diferentes_vendidos

    FROM SUCURSALES s
    LEFT JOIN EMPLEADOS      e  ON s.sucursal_id          = e.sucursal_id
    LEFT JOIN PEDIDOS        p  ON e.empleado_id          = p.tomado_por_empleado_id
                               AND CAST(p.fecha_pedido AS DATE) = @fecha
    LEFT JOIN ESTADOS_PEDIDOS ep ON p.estado_id            = ep.estado_id
    LEFT JOIN CANALES_VENTAS   cv ON p.canal_id             = cv.canal_id
    LEFT JOIN DETALLES_PEDIDOS dp ON p.pedido_id           = dp.pedido_id
    WHERE (@sucursal_id IS NULL OR s.sucursal_id = @sucursal_id)
    GROUP BY s.sucursal_id, s.nombre
    ORDER BY s.nombre
END
GO

-- =============================================
-- VALIDACIÓN
-- =============================================

PRINT ''
PRINT 'Validando Bundle D...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarMenuActual]') AND type in (N'P', N'PC'))
    PRINT 'sp_ConsultarMenuActual        : OK'
ELSE PRINT 'sp_ConsultarMenuActual        : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_MesasDisponibles]') AND type in (N'P', N'PC'))
    PRINT 'sp_MesasDisponibles           : OK'
ELSE PRINT 'sp_MesasDisponibles           : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarPedidosPorEstado]') AND type in (N'P', N'PC'))
    PRINT 'sp_ConsultarPedidosPorEstado  : OK'
ELSE PRINT 'sp_ConsultarPedidosPorEstado  : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ResumenOperativoDiario]') AND type in (N'P', N'PC'))
    PRINT 'sp_ResumenOperativoDiario     : OK'
ELSE PRINT 'sp_ResumenOperativoDiario     : ERROR'

IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_PedidosCompletos]'))
    PRINT 'vw_PedidosCompletos           : OK'
ELSE PRINT 'vw_PedidosCompletos           : ERROR'

IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_EstadoMesas]'))
    PRINT 'vw_EstadoMesas                : OK'
ELSE PRINT 'vw_EstadoMesas                : ERROR'

PRINT ''
PRINT 'BUNDLE D COMPLETADO!'
PRINT '================================================='
PRINT 'SPs   : 4 (menu, mesas, pedidos por estado, resumen diario)'
PRINT 'Vistas: 2 (vw_PedidosCompletos, vw_EstadoMesas)'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_E1_Triggers_Principales.sql'
PRINT '================================================='
GO
