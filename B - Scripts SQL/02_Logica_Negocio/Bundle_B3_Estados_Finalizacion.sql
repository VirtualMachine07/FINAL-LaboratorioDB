-- =============================================
-- BUNDLE B3 - ESTADOS Y FINALIZACIÓN
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: SPs para cierre, cancelación y transición de estados de pedidos
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================

USE EsbirrosDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT 'INICIANDO BUNDLE B3 - ESTADOS Y FINALIZACION'
PRINT '==============================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- SP 1: CERRAR PEDIDOS
-- =============================================

PRINT 'Creando SP: sp_CerrarPedido...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CerrarPedido]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_CerrarPedido]
GO

CREATE PROCEDURE [dbo].[sp_CerrarPedido]
    @pedido_id INT,
    @mensaje   NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @estado_cerrado_id INT
        DECLARE @pedido_existe     INT = 0
        DECLARE @estado_actual     NVARCHAR(50)
        DECLARE @tiene_items       INT = 0

        SET @mensaje = ''

        -- 1. VALIDAR PEDIDOS
        SELECT
            @pedido_existe = COUNT(*),
            @estado_actual = MAX(ep.nombre)
        FROM PEDIDOS p
        INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
        WHERE p.pedido_id = @pedido_id

        IF @pedido_existe = 0
        BEGIN
            SET @mensaje = 'Error: El PEDIDOS no existe'
            ROLLBACK TRANSACTION
            RETURN -1
        END

        -- 2. VALIDAR QUE NO ESTÉ YA CERRADO/CANCELADO
        IF @estado_actual IN ('Cerrado', 'Cancelado')
        BEGIN
            SET @mensaje = 'Error: El PEDIDOS ya está ' + @estado_actual
            ROLLBACK TRANSACTION
            RETURN -2
        END

        -- 3. VALIDAR QUE TENGA ÍTEMS
        SELECT @tiene_items = COUNT(*)
        FROM DETALLES_PEDIDOS
        WHERE pedido_id = @pedido_id

        IF @tiene_items = 0
        BEGIN
            SET @mensaje = 'Error: No se puede cerrar un PEDIDOS sin ítems'
            ROLLBACK TRANSACTION
            RETURN -3
        END

        -- 4. RECALCULAR TOTAL ANTES DE CERRAR
        DECLARE @total_calculado DECIMAL(10,2)
        DECLARE @msg_calculo     NVARCHAR(500)

        EXEC sp_CalcularTotalPedido @pedido_id, @total_calculado OUTPUT, @msg_calculo OUTPUT

        -- 5. OBTENER ID DEL ESTADO "CERRADO"
        SELECT @estado_cerrado_id = estado_id
        FROM ESTADOS_PEDIDOS
        WHERE nombre = 'Cerrado'

        IF @estado_cerrado_id IS NULL
        BEGIN
            SET @mensaje = 'Error: No se encontró el estado "Cerrado"'
            ROLLBACK TRANSACTION
            RETURN -4
        END

        -- 6. CERRAR EL PEDIDOS
        UPDATE PEDIDOS
        SET
            estado_id     = @estado_cerrado_id,
            fecha_entrega = GETDATE()
        WHERE pedido_id = @pedido_id

        SET @mensaje = 'PEDIDOS cerrado exitosamente. Total: $' + CAST(@total_calculado AS VARCHAR)

        COMMIT TRANSACTION
        RETURN 0

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        SET @mensaje = 'Error inesperado: ' + ERROR_MESSAGE()
        RETURN -99
    END CATCH
END
GO

-- =============================================
-- SP 2: CANCELAR PEDIDOS
-- =============================================

PRINT 'Creando SP: sp_CancelarPedido...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CancelarPedido]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_CancelarPedido]
GO

CREATE PROCEDURE [dbo].[sp_CancelarPedido]
    @pedido_id INT,
    @motivo    NVARCHAR(255) = NULL,
    @mensaje   NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @estado_cancelado_id INT
        DECLARE @pedido_existe       INT = 0
        DECLARE @estado_actual       NVARCHAR(50)

        SET @mensaje = ''

        -- 1. VALIDAR PEDIDOS
        SELECT
            @pedido_existe = COUNT(*),
            @estado_actual = MAX(ep.nombre)
        FROM PEDIDOS p
        INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
        WHERE p.pedido_id = @pedido_id

        IF @pedido_existe = 0
        BEGIN
            SET @mensaje = 'Error: El PEDIDOS no existe'
            ROLLBACK TRANSACTION
            RETURN -1
        END

        -- 2. VALIDAR QUE NO ESTÉ YA CERRADO/CANCELADO
        IF @estado_actual IN ('Cerrado', 'Cancelado')
        BEGIN
            SET @mensaje = 'Error: No se puede cancelar un PEDIDOS ' + @estado_actual
            ROLLBACK TRANSACTION
            RETURN -2
        END

        -- 3. OBTENER ID DEL ESTADO "CANCELADO"
        SELECT @estado_cancelado_id = estado_id
        FROM ESTADOS_PEDIDOS
        WHERE nombre = 'Cancelado'

        IF @estado_cancelado_id IS NULL
        BEGIN
            SET @mensaje = 'Error: No se encontró el estado "Cancelado"'
            ROLLBACK TRANSACTION
            RETURN -3
        END

        -- 4. CANCELAR EL PEDIDOS (registrar motivo en observaciones)
        UPDATE PEDIDOS
        SET
            estado_id     = @estado_cancelado_id,
            fecha_entrega = GETDATE(),
            observaciones = ISNULL(observaciones, '') +
                CASE
                    WHEN observaciones IS NOT NULL
                    THEN ' | CANCELADO: ' + ISNULL(@motivo, 'Sin motivo especificado')
                    ELSE 'CANCELADO: '   + ISNULL(@motivo, 'Sin motivo especificado')
                END
        WHERE pedido_id = @pedido_id

        SET @mensaje = 'PEDIDOS cancelado exitosamente'
        IF @motivo IS NOT NULL
            SET @mensaje = @mensaje + '. Motivo: ' + @motivo

        COMMIT TRANSACTION
        RETURN 0

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        SET @mensaje = 'Error inesperado: ' + ERROR_MESSAGE()
        RETURN -99
    END CATCH
END
GO

-- =============================================
-- SP 3: ACTUALIZAR ESTADO DE PEDIDOS
-- Permite avanzar un PEDIDOS al siguiente estado
-- en la secuencia definida por ESTADOS_PEDIDOS.orden
-- =============================================

PRINT 'Creando SP: sp_ActualizarEstadoPedido...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ActualizarEstadoPedido]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_ActualizarEstadoPedido]
GO

CREATE PROCEDURE [dbo].[sp_ActualizarEstadoPedido]
    @pedido_id                 INT,
    @nuevo_estado              NVARCHAR(50),
    @entregado_por_empleado_id INT           = NULL,
    @mensaje                   NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @pedido_existe       INT = 0
        DECLARE @estado_actual       NVARCHAR(50)
        DECLARE @orden_actual        INT
        DECLARE @nuevo_estado_id     INT
        DECLARE @orden_nuevo         INT

        SET @mensaje = ''

        -- 1. VALIDAR PEDIDOS
        SELECT
            @pedido_existe = COUNT(*),
            @estado_actual = MAX(ep.nombre),
            @orden_actual  = MAX(ep.orden)
        FROM PEDIDOS p
        INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
        WHERE p.pedido_id = @pedido_id

        IF @pedido_existe = 0
        BEGIN
            SET @mensaje = 'Error: El PEDIDOS no existe'
            ROLLBACK TRANSACTION
            RETURN -1
        END

        -- 2. VALIDAR QUE NO ESTÉ YA CERRADO/CANCELADO
        IF @estado_actual IN ('Cerrado', 'Cancelado')
        BEGIN
            SET @mensaje = 'Error: El PEDIDOS ya está ' + @estado_actual + ' y no se puede modificar'
            ROLLBACK TRANSACTION
            RETURN -2
        END

        -- 3. VALIDAR QUE EL NUEVO ESTADO EXISTE
        SELECT
            @nuevo_estado_id = estado_id,
            @orden_nuevo     = orden
        FROM ESTADOS_PEDIDOS
        WHERE nombre = @nuevo_estado

        IF @nuevo_estado_id IS NULL
        BEGIN
            SET @mensaje = 'Error: El estado "' + @nuevo_estado + '" no existe'
            ROLLBACK TRANSACTION
            RETURN -3
        END

        -- 4. VALIDAR PROGRESIÓN SECUENCIAL (RN-006.2)
        -- Solo se permite avanzar al siguiente estado en la secuencia
        -- Excepción: Cancelado (orden=99) se maneja con sp_CancelarPedido
        IF @orden_nuevo = 99
        BEGIN
            SET @mensaje = 'Error: Para cancelar un PEDIDOS use sp_CancelarPedido'
            ROLLBACK TRANSACTION
            RETURN -4
        END

        IF @orden_nuevo <= @orden_actual
        BEGIN
            SET @mensaje = 'Error: No se puede retroceder de "' + @estado_actual
                + '" (orden ' + CAST(@orden_actual AS VARCHAR)
                + ') a "' + @nuevo_estado
                + '" (orden ' + CAST(@orden_nuevo AS VARCHAR) + ')'
            ROLLBACK TRANSACTION
            RETURN -5
        END

        IF @orden_nuevo != @orden_actual + 1
        BEGIN
            SET @mensaje = 'Error: Solo se puede avanzar al siguiente estado. Estado actual: "'
                + @estado_actual + '" (orden ' + CAST(@orden_actual AS VARCHAR)
                + '), siguiente esperado: orden ' + CAST(@orden_actual + 1 AS VARCHAR)
            ROLLBACK TRANSACTION
            RETURN -6
        END

        -- 5. VALIDAR EMPLEADOS DE ENTREGA (RN-006.4)
        IF @nuevo_estado = 'Entregado'
        BEGIN
            IF @entregado_por_empleado_id IS NULL
            BEGIN
                SET @mensaje = 'Error: Para marcar como "Entregado" se requiere el EMPLEADOS de entrega'
                ROLLBACK TRANSACTION
                RETURN -7
            END

            -- Validar que el EMPLEADOS existe y está activo
            IF NOT EXISTS (SELECT 1 FROM EMPLEADOS WHERE empleado_id = @entregado_por_empleado_id AND activo = 1)
            BEGIN
                SET @mensaje = 'Error: El EMPLEADOS de entrega no existe o no está activo'
                ROLLBACK TRANSACTION
                RETURN -8
            END
        END

        -- 6. ACTUALIZAR ESTADO
        UPDATE PEDIDOS
        SET
            estado_id                 = @nuevo_estado_id,
            entregado_por_empleado_id = CASE
                WHEN @nuevo_estado = 'Entregado' THEN @entregado_por_empleado_id
                ELSE entregado_por_empleado_id
            END
        WHERE pedido_id = @pedido_id

        SET @mensaje = 'Estado actualizado: "' + @estado_actual + '" → "' + @nuevo_estado + '"'

        COMMIT TRANSACTION
        RETURN 0

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        SET @mensaje = 'Error inesperado: ' + ERROR_MESSAGE()
        RETURN -99
    END CATCH
END
GO

-- =============================================
-- VALIDACIÓN
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CerrarPedido]') AND type in (N'P', N'PC'))
    PRINT 'sp_CerrarPedido           : Creado correctamente'
ELSE
    PRINT 'sp_CerrarPedido           : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CancelarPedido]') AND type in (N'P', N'PC'))
    PRINT 'sp_CancelarPedido         : Creado correctamente'
ELSE
    PRINT 'sp_CancelarPedido         : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ActualizarEstadoPedido]') AND type in (N'P', N'PC'))
    PRINT 'sp_ActualizarEstadoPedido : Creado correctamente'
ELSE
    PRINT 'sp_ActualizarEstadoPedido : ERROR'

PRINT ''
PRINT 'BUNDLE B3 COMPLETADO!'
PRINT '================================================='
PRINT 'Resumen Bundle B completo (B1+B2+B3):'
PRINT '   sp_CrearPedido             - Crear pedidos'
PRINT '   sp_AgregarItemPedido       - Agregar ítems (solo platos)'
PRINT '   sp_CalcularTotalPedido     - Calcular totales'
PRINT '   sp_CerrarPedido            - Cerrar pedidos'
PRINT '   sp_CancelarPedido          - Cancelar pedidos'
PRINT '   sp_ActualizarEstadoPedido  - Avanzar estado (secuencial)'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_C_Seguridad.sql'
PRINT '================================================='
GO
