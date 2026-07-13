-- =============================================
-- BUNDLE E2 - CONTROL AVANZADO
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Triggers de stock, notificaciones y control avanzado
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACION
-- =============================================

USE EsbirrosDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT 'INICIANDO BUNDLE E2 - CONTROL AVANZADO'
PRINT '========================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- TRIGGER 1: VALIDAR STOCK (SIMULACIÓN)
-- =============================================

PRINT 'Creando Trigger: tr_ValidarStock...'

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'STOCKS_SIMULADOS')
BEGIN
    CREATE TABLE STOCKS_SIMULADOS (
        plato_id             INT      PRIMARY KEY,
        stock_disponible     INT      NOT NULL DEFAULT 100,
        stock_minimo         INT      NOT NULL DEFAULT 10,
        ultima_actualizacion DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_STOCK_plato FOREIGN KEY (plato_id) REFERENCES PLATOS(plato_id),
        CONSTRAINT CK_STOCK_no_negativo CHECK (stock_disponible >= 0)
    )

    -- Stock inicial para todos los platos
    INSERT INTO STOCKS_SIMULADOS (plato_id, stock_disponible, stock_minimo)
    SELECT plato_id, 100, 10 FROM PLATOS

    PRINT 'Tabla STOCKS_SIMULADOS creada con stock inicial (100 unidades por PLATOS)'
END

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_ValidarStock]'))
    DROP TRIGGER [dbo].[tr_ValidarStock]
GO

CREATE TRIGGER [dbo].[tr_ValidarStock]
ON [dbo].[DETALLES_PEDIDOS]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Detectar platos sin stock suficiente
    DECLARE @platos_sin_stock TABLE (plato_id INT, nombre NVARCHAR(100), stock_actual INT)

    INSERT INTO @platos_sin_stock
    SELECT
        i.plato_id,
        p.nombre,
        s.stock_disponible
    FROM inserted i
    INNER JOIN PLATOS         p ON i.plato_id = p.plato_id
    INNER JOIN STOCKS_SIMULADOS s ON i.plato_id = s.plato_id
    WHERE s.stock_disponible < i.cantidad

    IF EXISTS (SELECT 1 FROM @platos_sin_stock)
    BEGIN
        -- HM-07: Insertar notificación en NOTIFICACIONES en vez de PRINT
        INSERT INTO NOTIFICACIONES (tipo, titulo, mensaje, pedido_id, prioridad, usuario_destino)
        SELECT
            'STOCK_BAJO',
            'Stock insuficiente: ' + ps.nombre,
            'PLATOS "' + ps.nombre + '" tiene stock=' + CAST(ps.stock_actual AS VARCHAR)
                + ' pero se pidieron ' + CAST(i.cantidad AS VARCHAR) + ' unidades',
            i.pedido_id,
            'CRITICA',
            'COCINA'
        FROM @platos_sin_stock ps
        INNER JOIN inserted i ON ps.plato_id = i.plato_id
    END

    -- Descontar stock (solo platos)
    UPDATE s
    SET
        stock_disponible     = s.stock_disponible - i.cantidad,
        ultima_actualizacion = GETDATE()
    FROM STOCKS_SIMULADOS s
    INNER JOIN inserted i ON s.plato_id = i.plato_id
END
GO

-- =============================================
-- TRIGGER 2: SISTEMA DE NOTIFICACIONES
-- =============================================

PRINT 'Creando Trigger: tr_SistemaNotificaciones...'

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'NOTIFICACIONES')
BEGIN
    CREATE TABLE NOTIFICACIONES (
        notificacion_id INT           IDENTITY(1,1) PRIMARY KEY,
        tipo            VARCHAR(50)   NOT NULL,
        titulo          NVARCHAR(200) NOT NULL,
        mensaje         NVARCHAR(500) NOT NULL,
        pedido_id       INT           NULL,
        mesa_id         INT           NULL,
        prioridad       VARCHAR(20)   NOT NULL DEFAULT 'NORMAL',
        fecha_creacion  DATETIME      NOT NULL DEFAULT GETDATE(),
        leida           BIT           NOT NULL DEFAULT 0,
        fecha_lectura   DATETIME      NULL,
        usuario_destino VARCHAR(100)  NULL
    )
    PRINT 'Tabla NOTIFICACIONES creada'
END

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_SistemaNotificaciones]'))
    DROP TRIGGER [dbo].[tr_SistemaNotificaciones]
GO

CREATE TRIGGER [dbo].[tr_SistemaNotificaciones]
ON [dbo].[PEDIDOS]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- HM-08: Notificación: PEDIDOS en preparación (mozos → cocina)
    INSERT INTO NOTIFICACIONES (tipo, titulo, mensaje, pedido_id, mesa_id, prioridad, usuario_destino)
    SELECT
        'PEDIDO_EN_PREPARACION',
        'Nuevo PEDIDOS para Preparar',
        CONCAT(
            'El PEDIDOS #', i.pedido_id,
            CASE WHEN m.numero IS NOT NULL THEN ' de la MESAS ' + CAST(m.numero AS VARCHAR) ELSE ' (delivery)' END,
            ' ingresó a preparación. Total: $', i.total
        ),
        i.pedido_id,
        i.mesa_id,
        'ALTA',
        'COCINA'
    FROM inserted i
    INNER JOIN deleted d                ON i.pedido_id  = d.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep_new     ON i.estado_id  = ep_new.estado_id
    INNER JOIN ESTADOS_PEDIDOS ep_old     ON d.estado_id  = ep_old.estado_id
    LEFT JOIN  MESAS          m          ON i.mesa_id    = m.mesa_id
    WHERE ep_new.nombre = 'En Preparación' AND ep_old.nombre != 'En Preparación'

    -- Notificación: PEDIDOS listo para entregar (cocina → mozos)
    INSERT INTO NOTIFICACIONES (tipo, titulo, mensaje, pedido_id, mesa_id, prioridad, usuario_destino)
    SELECT
        'PEDIDO_LISTO',
        'PEDIDOS Listo para Entregar',
        CONCAT(
            'El PEDIDOS #', i.pedido_id,
            CASE WHEN m.numero IS NOT NULL THEN ' de la MESAS ' + CAST(m.numero AS VARCHAR) ELSE '' END,
            ' está listo. Total: $', i.total
        ),
        i.pedido_id,
        i.mesa_id,
        'ALTA',
        'MOZOS'
    FROM inserted i
    INNER JOIN deleted d                ON i.pedido_id  = d.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep_new     ON i.estado_id  = ep_new.estado_id
    INNER JOIN ESTADOS_PEDIDOS ep_old     ON d.estado_id  = ep_old.estado_id
    LEFT JOIN  MESAS          m          ON i.mesa_id    = m.mesa_id
    WHERE ep_new.nombre = 'Listo' AND ep_old.nombre != 'Listo'

    -- HM-08: Notificación: PEDIDOS en reparto (cocina → repartidor)
    INSERT INTO NOTIFICACIONES (tipo, titulo, mensaje, pedido_id, mesa_id, prioridad, usuario_destino)
    SELECT
        'PEDIDO_EN_REPARTO',
        'PEDIDOS en Camino',
        CONCAT('PEDIDOS #', i.pedido_id, ' salió a reparto. Total: $', i.total),
        i.pedido_id,
        i.mesa_id,
        'ALTA',
        'DELIVERY'
    FROM inserted i
    INNER JOIN deleted d                ON i.pedido_id  = d.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep_new     ON i.estado_id  = ep_new.estado_id
    INNER JOIN ESTADOS_PEDIDOS ep_old     ON d.estado_id  = ep_old.estado_id
    WHERE ep_new.nombre = 'En Reparto' AND ep_old.nombre != 'En Reparto'

    -- Notificación: PEDIDOS cerrado (mozos → caja)
    INSERT INTO NOTIFICACIONES (tipo, titulo, mensaje, pedido_id, mesa_id, prioridad, usuario_destino)
    SELECT
        'PEDIDO_CERRADO',
        'PEDIDOS Completado',
        CONCAT('PEDIDOS #', i.pedido_id, ' cerrado exitosamente. Total: $', i.total),
        i.pedido_id,
        i.mesa_id,
        'NORMAL',
        'CAJA'
    FROM inserted i
    INNER JOIN deleted d            ON i.pedido_id = d.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep_new ON i.estado_id = ep_new.estado_id
    INNER JOIN ESTADOS_PEDIDOS ep_old ON d.estado_id = ep_old.estado_id
    WHERE ep_new.nombre = 'Cerrado' AND ep_old.nombre != 'Cerrado'

    -- HM-08: Notificación: PEDIDOS cancelado (→ caja + cocina)
    INSERT INTO NOTIFICACIONES (tipo, titulo, mensaje, pedido_id, mesa_id, prioridad, usuario_destino)
    SELECT
        'PEDIDO_CANCELADO',
        'PEDIDOS Cancelado',
        CONCAT('PEDIDOS #', i.pedido_id, ' fue CANCELADO. Motivo: ', ISNULL(i.observaciones, 'Sin motivo')),
        i.pedido_id,
        i.mesa_id,
        'CRITICA',
        'CAJA'
    FROM inserted i
    INNER JOIN deleted d            ON i.pedido_id = d.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep_new ON i.estado_id = ep_new.estado_id
    INNER JOIN ESTADOS_PEDIDOS ep_old ON d.estado_id = ep_old.estado_id
    WHERE ep_new.nombre = 'Cancelado' AND ep_old.nombre != 'Cancelado'

    INSERT INTO NOTIFICACIONES (tipo, titulo, mensaje, pedido_id, mesa_id, prioridad, usuario_destino)
    SELECT
        'PEDIDO_CANCELADO',
        'PEDIDOS Cancelado',
        CONCAT('PEDIDOS #', i.pedido_id, ' fue CANCELADO. Dejar de preparar.'),
        i.pedido_id,
        i.mesa_id,
        'CRITICA',
        'COCINA'
    FROM inserted i
    INNER JOIN deleted d            ON i.pedido_id = d.pedido_id
    INNER JOIN ESTADOS_PEDIDOS ep_new ON i.estado_id = ep_new.estado_id
    INNER JOIN ESTADOS_PEDIDOS ep_old ON d.estado_id = ep_old.estado_id
    WHERE ep_new.nombre = 'Cancelado' AND ep_old.nombre != 'Cancelado'
END
GO

-- =============================================
-- SP 1: CONSULTAR NOTIFICACIONES
-- =============================================

PRINT 'Creando SP: sp_ConsultarNotificaciones...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarNotificaciones]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_ConsultarNotificaciones]
GO

CREATE PROCEDURE [dbo].[sp_ConsultarNotificaciones]
    @usuario_destino VARCHAR(100) = NULL,
    @solo_no_leidas  BIT          = 1,
    @prioridad       VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        n.notificacion_id,
        n.tipo,
        n.titulo,
        n.mensaje,
        n.pedido_id,
        n.mesa_id,
        n.prioridad,
        n.fecha_creacion,
        n.leida,
        n.fecha_lectura,
        n.usuario_destino,

        CASE WHEN n.pedido_id IS NOT NULL THEN ep.nombre ELSE NULL END AS estado_pedido_actual,
        CASE WHEN n.mesa_id   IS NOT NULL THEN m.numero  ELSE NULL END AS numero_mesa,

        DATEDIFF(MINUTE, n.fecha_creacion, GETDATE()) AS minutos_antiguedad,

        CASE n.prioridad
            WHEN 'CRITICA' THEN 4
            WHEN 'ALTA'    THEN 3
            WHEN 'NORMAL'  THEN 2
            WHEN 'BAJA'    THEN 1
            ELSE 0
        END AS prioridad_orden

    FROM NOTIFICACIONES n
    LEFT JOIN PEDIDOS        p  ON n.pedido_id = p.pedido_id
    LEFT JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
    LEFT JOIN MESAS          m  ON n.mesa_id   = m.mesa_id
    WHERE (@usuario_destino IS NULL OR n.usuario_destino = @usuario_destino)
      AND (@solo_no_leidas  = 0     OR n.leida = 0)
      AND (@prioridad       IS NULL OR n.prioridad       = @prioridad)
    ORDER BY prioridad_orden DESC, n.fecha_creacion DESC
END
GO

-- =============================================
-- SP 2: MARCAR NOTIFICACIÓN COMO LEÍDA
-- =============================================

PRINT 'Creando SP: sp_MarcarNotificacionLeida...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_MarcarNotificacionLeida]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_MarcarNotificacionLeida]
GO

CREATE PROCEDURE [dbo].[sp_MarcarNotificacionLeida]
    @notificacion_id INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE NOTIFICACIONES
    SET
        leida         = 1,
        fecha_lectura = GETDATE()
    WHERE notificacion_id = @notificacion_id
      AND leida = 0

    IF @@ROWCOUNT > 0
    BEGIN PRINT 'Notificación marcada como leída'; RETURN 0 END
    ELSE
    BEGIN PRINT 'Notificación no encontrada o ya leída'; RETURN -1 END
END
GO

-- =============================================
-- SP 3: CONSULTAR STOCK ACTUAL
-- =============================================

PRINT 'Creando SP: sp_ConsultarStock...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarStock]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_ConsultarStock]
GO

CREATE PROCEDURE [dbo].[sp_ConsultarStock]
    @plato_id       INT = NULL,
    @solo_stock_bajo BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.plato_id,
        p.nombre,
        p.categoria,
        s.stock_disponible,
        s.stock_minimo,
        s.ultima_actualizacion,
        CASE
            WHEN s.stock_disponible <= s.stock_minimo     THEN 'CRITICO'
            WHEN s.stock_disponible <= s.stock_minimo * 2 THEN 'BAJO'
            ELSE 'NORMAL'
        END AS estado_stock,
        pr.monto AS precio_actual
    FROM PLATOS p
    INNER JOIN STOCKS_SIMULADOS s ON p.plato_id = s.plato_id
    LEFT JOIN (
        SELECT
            plato_id,
            monto,
            ROW_NUMBER() OVER (PARTITION BY plato_id ORDER BY vigencia_desde DESC) AS rn
        FROM PRECIOS
        WHERE vigencia_desde <= GETDATE()
          AND (vigencia_hasta IS NULL OR vigencia_hasta >= GETDATE())
    ) pr ON p.plato_id = pr.plato_id AND pr.rn = 1
    WHERE (@plato_id        IS NULL OR p.plato_id = @plato_id)
      AND (@solo_stock_bajo  = 0    OR s.stock_disponible <= s.stock_minimo)
      AND p.activo = 1
    ORDER BY
        CASE
            WHEN s.stock_disponible <= s.stock_minimo     THEN 1
            WHEN s.stock_disponible <= s.stock_minimo * 2 THEN 2
            ELSE 3
        END,
        p.nombre
END
GO

-- =============================================
-- VALIDACIÓN
-- =============================================

PRINT ''
IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_ValidarStock]'))
    PRINT 'tr_ValidarStock              : Creado correctamente'
ELSE PRINT 'tr_ValidarStock              : ERROR'

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_SistemaNotificaciones]'))
    PRINT 'tr_SistemaNotificaciones     : Creado correctamente'
ELSE PRINT 'tr_SistemaNotificaciones     : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarNotificaciones]') AND type in (N'P', N'PC'))
    PRINT 'sp_ConsultarNotificaciones   : Creado correctamente'
ELSE PRINT 'sp_ConsultarNotificaciones   : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_MarcarNotificacionLeida]') AND type in (N'P', N'PC'))
    PRINT 'sp_MarcarNotificacionLeida   : Creado correctamente'
ELSE PRINT 'sp_MarcarNotificacionLeida   : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ConsultarStock]') AND type in (N'P', N'PC'))
    PRINT 'sp_ConsultarStock            : Creado correctamente'
ELSE PRINT 'sp_ConsultarStock            : ERROR'

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'STOCKS_SIMULADOS')
    PRINT 'STOCKS_SIMULADOS               : OK'
ELSE PRINT 'STOCKS_SIMULADOS               : ERROR'

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'NOTIFICACIONES')
    PRINT 'NOTIFICACIONES               : OK'
ELSE PRINT 'NOTIFICACIONES               : ERROR'

PRINT ''
PRINT 'BUNDLE E2 COMPLETADO!'
PRINT '============================================'
PRINT 'Bundle E completo (E1 + E2):'
PRINT '   tr_ActualizarTotales      - Totales automáticos'
PRINT '   tr_AuditoriaPedidos       - Auditoría principal'
PRINT '   tr_AuditoriaDetalle       - Auditoría de ítems'
PRINT '   tr_ValidarStock           - Control de inventario'
PRINT '   tr_SistemaNotificaciones  - Alertas automáticas'
PRINT '   sp_ConsultarNotificaciones - Consulta de alertas'
PRINT '   sp_MarcarNotificacionLeida - Marcar alertas leídas'
PRINT '   sp_ConsultarStock          - Consulta de inventario'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_R1_Reportes_Estructuras_SPs.sql'
PRINT '================================================='
GO

-- =============================================
-- PERMISOS DIFERIDOS: NOTIFICACIONES, STOCKS_SIMULADOS y SPs E2
-- (requiere que Bundle_C_Seguridad se haya ejecutado antes)
-- =============================================
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_aplicacion_web')
BEGIN
    GRANT SELECT ON dbo.NOTIFICACIONES    TO [rol_aplicacion_web];
    GRANT SELECT ON dbo.STOCKS_SIMULADOS  TO [rol_aplicacion_web];
    PRINT 'Permisos sobre NOTIFICACIONES y STOCKS_SIMULADOS aplicados a rol_aplicacion_web'
END

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_cocinero')
BEGIN
    GRANT SELECT ON dbo.STOCKS_SIMULADOS                     TO [rol_cocinero];
    GRANT SELECT ON dbo.NOTIFICACIONES                       TO [rol_cocinero];
    GRANT EXECUTE ON dbo.sp_ConsultarNotificaciones          TO [rol_cocinero];
    GRANT EXECUTE ON dbo.sp_MarcarNotificacionLeida          TO [rol_cocinero];
    GRANT EXECUTE ON dbo.sp_ConsultarStock                   TO [rol_cocinero];
    PRINT 'Permisos diferidos de E2 aplicados a rol_cocinero'
END
GO
