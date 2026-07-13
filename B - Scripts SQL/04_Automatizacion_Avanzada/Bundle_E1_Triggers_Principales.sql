-- =============================================
-- BUNDLE E1 - TRIGGERS PRINCIPALES
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Triggers de totales automáticos y auditoría principal
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACION
-- =============================================

USE EsbirrosDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT 'INICIANDO BUNDLE E1 - TRIGGERS PRINCIPALES'
PRINT '============================================'
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- TRIGGER 1: ACTUALIZAR TOTALES AUTOMÁTICAMENTE
-- =============================================
-- Se dispara en INSERT/UPDATE/DELETE sobre DETALLES_PEDIDOS.
-- Recalcula PEDIDOS.total sumando subtotales vigentes.
-- =============================================

PRINT 'Creando Trigger: tr_ActualizarTotales...'

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_ActualizarTotales]'))
    DROP TRIGGER [dbo].[tr_ActualizarTotales]
GO

CREATE TRIGGER [dbo].[tr_ActualizarTotales]
ON [dbo].[DETALLES_PEDIDOS]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Recolectar pedidos afectados (por inserts y/o deletes)
    DECLARE @pedidos_afectados TABLE (pedido_id INT)

    INSERT INTO @pedidos_afectados (pedido_id)
    SELECT DISTINCT pedido_id FROM inserted

    INSERT INTO @pedidos_afectados (pedido_id)
    SELECT DISTINCT pedido_id FROM deleted
    WHERE pedido_id NOT IN (SELECT pedido_id FROM @pedidos_afectados)

    -- Recalcular total para cada PEDIDOS afectado
    UPDATE p
    SET total = ISNULL(totales.total_calculado, 0)
    FROM PEDIDOS p
    INNER JOIN @pedidos_afectados pa ON p.pedido_id = pa.pedido_id
    LEFT JOIN (
        SELECT dp.pedido_id, SUM(dp.subtotal) AS total_calculado
        FROM DETALLES_PEDIDOS dp
        GROUP BY dp.pedido_id
    ) totales ON p.pedido_id = totales.pedido_id
END
GO

-- =============================================
-- TRIGGER 2: AUDITORÍA DE PEDIDOS
-- =============================================

PRINT 'Creando Trigger: tr_AuditoriaPedidos...'

-- Crear tabla de auditoría simplificada si no existe
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AUDITORIAS_SIMPLES')
BEGIN
    CREATE TABLE AUDITORIAS_SIMPLES (
        auditoria_id     INT          IDENTITY(1,1) PRIMARY KEY,
        tabla_afectada   NVARCHAR(50) NOT NULL,
        registro_id      INT          NOT NULL,
        accion           VARCHAR(20)  NOT NULL,
        fecha_auditoria  DATETIME     NOT NULL DEFAULT GETDATE(),
        usuario_sistema  VARCHAR(128) NOT NULL DEFAULT SYSTEM_USER,
        datos_resumen    NVARCHAR(500) NULL
    )
    PRINT 'Tabla AUDITORIAS_SIMPLES creada'
END

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_AuditoriaPedidos]'))
    DROP TRIGGER [dbo].[tr_AuditoriaPedidos]
GO

CREATE TRIGGER [dbo].[tr_AuditoriaPedidos]
ON [dbo].[PEDIDOS]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
    BEGIN
        INSERT INTO AUDITORIAS_SIMPLES (tabla_afectada, registro_id, accion, datos_resumen)
        SELECT
            'PEDIDOS',
            i.pedido_id,
            'INSERT',
            'Nuevo PEDIDOS - Canal: ' + ISNULL(cv.nombre, 'N/A') +
            ', Estado: ' + ISNULL(ep.nombre, 'N/A')
        FROM inserted i
        LEFT JOIN ESTADOS_PEDIDOS ep ON i.estado_id = ep.estado_id
        LEFT JOIN CANALES_VENTAS   cv ON i.canal_id  = cv.canal_id
    END

    -- UPDATE
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        INSERT INTO AUDITORIAS_SIMPLES (tabla_afectada, registro_id, accion, datos_resumen)
        SELECT
            'PEDIDOS',
            i.pedido_id,
            'UPDATE',
            'Estado: ' + ISNULL(ep_old.nombre, 'N/A') + ' → ' + ISNULL(ep_new.nombre, 'N/A') +
            ', Total: $' + CAST(ISNULL(i.total, 0) AS VARCHAR)
        FROM inserted i
        INNER JOIN deleted d         ON i.pedido_id  = d.pedido_id
        LEFT JOIN ESTADOS_PEDIDOS ep_old ON d.estado_id = ep_old.estado_id
        LEFT JOIN ESTADOS_PEDIDOS ep_new ON i.estado_id = ep_new.estado_id
        WHERE d.estado_id != i.estado_id OR d.total != i.total
    END

    -- DELETE
    IF NOT EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        INSERT INTO AUDITORIAS_SIMPLES (tabla_afectada, registro_id, accion, datos_resumen)
        SELECT
            'PEDIDOS',
            d.pedido_id,
            'DELETE',
            'PEDIDOS eliminado - Total: $' + CAST(ISNULL(d.total, 0) AS VARCHAR)
        FROM deleted d
    END
END
GO

-- =============================================
-- TRIGGER 3: AUDITORÍA DE DETALLE PEDIDOS
-- =============================================

PRINT 'Creando Trigger: tr_AuditoriaDetalle...'

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_AuditoriaDetalle]'))
    DROP TRIGGER [dbo].[tr_AuditoriaDetalle]
GO

CREATE TRIGGER [dbo].[tr_AuditoriaDetalle]
ON [dbo].[DETALLES_PEDIDOS]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
    BEGIN
        INSERT INTO AUDITORIAS_SIMPLES (tabla_afectada, registro_id, accion, datos_resumen)
        SELECT
            'DETALLES_PEDIDOS',
            i.detalle_id,
            'INSERT',
            'Ítem agregado al PEDIDOS ' + CAST(i.pedido_id AS VARCHAR) +
            ' - Cantidad: ' + CAST(i.cantidad AS VARCHAR) +
            ', Subtotal: $' + CAST(i.subtotal AS VARCHAR)
        FROM inserted i
    END

    -- UPDATE (HA-02: auditar modificaciones de cantidad/subtotal)
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        INSERT INTO AUDITORIAS_SIMPLES (tabla_afectada, registro_id, accion, datos_resumen)
        SELECT
            'DETALLES_PEDIDOS',
            i.detalle_id,
            'UPDATE',
            'PEDIDOS=' + CAST(i.pedido_id AS VARCHAR) +
            ' Cant: ' + CAST(d.cantidad AS VARCHAR) + '→' + CAST(i.cantidad AS VARCHAR) +
            ' Subtotal: $' + CAST(d.subtotal AS VARCHAR) + '→$' + CAST(i.subtotal AS VARCHAR)
        FROM inserted i
        INNER JOIN deleted d ON i.detalle_id = d.detalle_id
        WHERE i.cantidad != d.cantidad OR i.subtotal != d.subtotal
    END

    -- DELETE
    IF NOT EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        INSERT INTO AUDITORIAS_SIMPLES (tabla_afectada, registro_id, accion, datos_resumen)
        SELECT
            'DETALLES_PEDIDOS',
            d.detalle_id,
            'DELETE',
            'Ítem eliminado del PEDIDOS ' + CAST(d.pedido_id AS VARCHAR) +
            ' - Subtotal: $' + CAST(d.subtotal AS VARCHAR)
        FROM deleted d
    END
END
GO

-- =============================================
-- VALIDACIÓN
-- =============================================

PRINT ''
IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_ActualizarTotales]'))
    PRINT 'tr_ActualizarTotales : Creado correctamente'
ELSE PRINT 'tr_ActualizarTotales : ERROR'

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_AuditoriaPedidos]'))
    PRINT 'tr_AuditoriaPedidos  : Creado correctamente'
ELSE PRINT 'tr_AuditoriaPedidos  : ERROR'

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[tr_AuditoriaDetalle]'))
    PRINT 'tr_AuditoriaDetalle  : Creado correctamente'
ELSE PRINT 'tr_AuditoriaDetalle  : ERROR'

PRINT ''
PRINT 'BUNDLE E1 COMPLETADO!'
PRINT '==============================================='
PRINT 'Triggers  : tr_ActualizarTotales, tr_AuditoriaPedidos, tr_AuditoriaDetalle'
PRINT 'Tabla auto: AUDITORIAS_SIMPLES'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_E2_Control_Avanzado.sql'
PRINT '================================================='
GO

-- =============================================
-- PERMISOS DIFERIDOS: AUDITORIAS_SIMPLES
-- (requiere que Bundle_C_Seguridad se haya ejecutado antes)
-- =============================================
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_aplicacion_web')
BEGIN
    DENY INSERT, UPDATE, DELETE ON dbo.AUDITORIAS_SIMPLES TO [rol_aplicacion_web];
    PRINT 'Permiso DENY sobre AUDITORIAS_SIMPLES aplicado a rol_aplicacion_web'
END
GO
