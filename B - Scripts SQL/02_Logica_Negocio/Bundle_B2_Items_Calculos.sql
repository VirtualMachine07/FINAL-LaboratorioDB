-- =============================================
-- BUNDLE B2 - ITEMS Y CÁLCULOS
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: SPs para manejo de ítems de PEDIDOS y cálculo de totales
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================

USE EsbirrosDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT 'INICIANDO BUNDLE B2 - ITEMS Y CALCULOS'
PRINT '========================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- SP 1: AGREGAR ITEM AL PEDIDOS
-- =============================================
-- Sin combos: plato_id es siempre obligatorio.
-- El PRECIOS se obtiene de la tabla PRECIOS con vigencia actual.
-- =============================================

PRINT 'Creando SP: sp_AgregarItemPedido...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_AgregarItemPedido]') AND type IN (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_AgregarItemPedido]
GO

CREATE PROCEDURE [dbo].[sp_AgregarItemPedido]
    @pedido_id      INT,
    @plato_id       INT,              -- obligatorio (no nullable, sin combo)
    @cantidad       INT,
    @detalle_id     INT           OUTPUT,
    @mensaje        NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION

        -- Variables locales
        DECLARE @precio_unitario DECIMAL(10,2) = 0
        DECLARE @subtotal        DECIMAL(10,2) = 0
        DECLARE @pedido_existe   INT           = 0
        DECLARE @estado_actual   NVARCHAR(50)

        -- Inicializar salidas
        SET @detalle_id = 0
        SET @mensaje    = ''

        -- ── 1. VALIDAR PEDIDOS ────────────────────────────
        SELECT
            @pedido_existe  = COUNT(*),
            @estado_actual  = MAX(ep.nombre)
        FROM PEDIDOS p
        INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
        WHERE p.pedido_id = @pedido_id

        IF @pedido_existe = 0
        BEGIN
            SET @mensaje = 'Error: El pedido no existe (pedido_id=' + CAST(@pedido_id AS VARCHAR) + ')'
            ROLLBACK TRANSACTION
            RETURN -1
        END

        IF @estado_actual NOT IN ('Pendiente', 'Confirmado')
        BEGIN
            SET @mensaje = 'Error: No se pueden agregar ítems en estado "' + @estado_actual + '"'
            ROLLBACK TRANSACTION
            RETURN -2
        END

        -- ── 2. VALIDAR PLATOS ─────────────────────────────
        IF @plato_id IS NULL
        BEGIN
            SET @mensaje = 'Error: plato_id es obligatorio'
            ROLLBACK TRANSACTION
            RETURN -3
        END

        IF NOT EXISTS (SELECT 1 FROM PLATOS WHERE plato_id = @plato_id AND activo = 1)
        BEGIN
            SET @mensaje = 'Error: PLATOS no encontrado o inactivo (plato_id=' + CAST(@plato_id AS VARCHAR) + ')'
            ROLLBACK TRANSACTION
            RETURN -4
        END

        -- ── 3. VALIDAR CANTIDAD ──────────────────────────
        IF @cantidad <= 0
        BEGIN
            SET @mensaje = 'Error: La cantidad debe ser mayor a cero'
            ROLLBACK TRANSACTION
            RETURN -5
        END

        -- ── 4. OBTENER PRECIO VIGENTE DEL PLATO ─────────
        -- Toma el monto más reciente dentro de la vigencia actual
        -- HA-04: precio_id DESC como tiebreaker ante vigencias duplicadas
        SELECT TOP 1 @precio_unitario = monto
        FROM PRECIOS
        WHERE plato_id       = @plato_id
          AND vigencia_desde <= CAST(GETDATE() AS DATE)
          AND (vigencia_hasta IS NULL OR vigencia_hasta >= CAST(GETDATE() AS DATE))
        ORDER BY vigencia_desde DESC, precio_id DESC

        IF @precio_unitario IS NULL OR @precio_unitario = 0
        BEGIN
            SET @mensaje = 'Error: No existe precio vigente para el plato_id=' + CAST(@plato_id AS VARCHAR)
            ROLLBACK TRANSACTION
            RETURN -6
        END

        -- ── 5. CALCULAR SUBTOTAL ─────────────────────────
        SET @subtotal = @precio_unitario * @cantidad

        -- ── 6. INSERTAR DETALLE ──────────────────────────
        INSERT INTO DETALLES_PEDIDOS (
            pedido_id,
            plato_id,
            cantidad,
            precio_unitario,
            subtotal
        )
        VALUES (
            @pedido_id,
            @plato_id,
            @cantidad,
            @precio_unitario,
            @subtotal
        )

        SET @detalle_id = SCOPE_IDENTITY()
        SET @mensaje    = 'Item agregado OK. detalle_id=' + CAST(@detalle_id AS VARCHAR) +
                          ' | subtotal=$' + CAST(@subtotal AS VARCHAR)

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
-- SP 2: CALCULAR TOTAL DEL PEDIDOS
-- =============================================
-- Recalcula el total sumando todos los subtotales de DETALLES_PEDIDOS.
-- =============================================

PRINT 'Creando SP: sp_CalcularTotalPedido...'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CalcularTotalPedido]') AND type IN (N'P', N'PC'))
    DROP PROCEDURE [dbo].[sp_CalcularTotalPedido]
GO

CREATE PROCEDURE [dbo].[sp_CalcularTotalPedido]
    @pedido_id   INT,
    @nuevo_total DECIMAL(10,2) OUTPUT,
    @mensaje     NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @total_calculado DECIMAL(10,2) = 0
        DECLARE @pedido_existe   INT           = 0

        SET @nuevo_total = 0
        SET @mensaje     = ''

        -- 1. VALIDAR PEDIDOS
        SELECT @pedido_existe = COUNT(*)
        FROM PEDIDOS
        WHERE pedido_id = @pedido_id

        IF @pedido_existe = 0
        BEGIN
            SET @mensaje = 'Error: El PEDIDOS no existe (pedido_id=' + CAST(@pedido_id AS VARCHAR) + ')'
            ROLLBACK TRANSACTION
            RETURN -1
        END

        -- 2. CALCULAR TOTAL
        SELECT @total_calculado = ISNULL(SUM(subtotal), 0)
        FROM DETALLES_PEDIDOS
        WHERE pedido_id = @pedido_id

        -- 3. ACTUALIZAR PEDIDOS
        UPDATE PEDIDOS
        SET total = @total_calculado
        WHERE pedido_id = @pedido_id

        SET @nuevo_total = @total_calculado
        SET @mensaje     = 'Total actualizado: $' + CAST(@total_calculado AS VARCHAR(20))

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

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_AgregarItemPedido]')   AND type IN (N'P', N'PC'))
    PRINT 'sp_AgregarItemPedido  : Creado correctamente'
ELSE
    PRINT 'sp_AgregarItemPedido  : ERROR'

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_CalcularTotalPedido]') AND type IN (N'P', N'PC'))
    PRINT 'sp_CalcularTotalPedido: Creado correctamente'
ELSE
    PRINT 'sp_CalcularTotalPedido: ERROR'

PRINT ''
PRINT 'BUNDLE B2 COMPLETADO!'
PRINT '================================================='
PRINT 'Funciones disponibles:'
PRINT '   sp_AgregarItemPedido   - Agrega PLATOS a PEDIDOS (sin combo)'
PRINT '   sp_CalcularTotalPedido - Recalcula total del PEDIDOS'
PRINT ''
PRINT 'Ejemplo de uso:'
PRINT '   DECLARE @did INT, @msg NVARCHAR(500)'
PRINT '   EXEC sp_AgregarItemPedido @pedido_id=1, @plato_id=9, @cantidad=2,'
PRINT '        @detalle_id=@did OUTPUT, @mensaje=@msg OUTPUT'
PRINT '   SELECT @did AS detalle_id, @msg AS resultado'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_B3_Estados_Finalizacion.sql'
PRINT '================================================='
GO
