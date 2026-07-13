-- =============================================
-- DEMO: CICLO COMPLETO DE UN PEDIDO
-- EsbirrosDB - Bodegon Los Esbirros de Claudio
-- =============================================
-- Ejecutar bloque por bloque (F5 en cada seccion)
-- para mostrar el ciclo de vida de un pedido en vivo.
--
-- DATOS USADOS (reales de la BD):
--   Canal:    3 = MESAS QR
--   Mesa:     1 (numero 1, activa)
--   Empleado: 2 = Maria Fernandez
--   Platos:   1 = Empanadas de Carne (x6)  $3200
--             2 = Provoleta a la Parrilla
--             5 = Fideos con Tuco Casero
-- =============================================

USE EsbirrosDB;
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ─────────────────────────────────────────────────────────
-- PASO 0: ESTADO INICIAL — ver mesas antes de empezar
-- ─────────────────────────────────────────────────────────
PRINT '======================================================'
PRINT 'PASO 0: Estado inicial de las mesas'
PRINT '======================================================'

SELECT mesa_numero, estado_actual, estado_operativo
FROM vw_EstadoMesas
ORDER BY mesa_numero;
GO

-- ─────────────────────────────────────────────────────────
-- PASO 1: CREAR EL PEDIDO
-- sp_CrearPedido registra el pedido en estado "Pendiente"
-- y devuelve el pedido_id generado.
-- ─────────────────────────────────────────────────────────
PRINT ''
PRINT '======================================================'
PRINT 'PASO 1: Crear el pedido (mesa 1, mozo: Maria Fernandez)'
PRINT '======================================================'

DECLARE @pedido_id  INT
DECLARE @mensaje    NVARCHAR(500)

EXEC sp_CrearPedido
    @canal_id               = 3,   -- MESAS QR
    @mesa_id                = 1,   -- Mesa numero 1
    @cliente_id             = NULL,-- sin cliente identificado
    @domicilio_id           = NULL,
    @cant_comensales        = 4,
    @tomado_por_empleado_id = 2,   -- Maria Fernandez
    @pedido_id              = @pedido_id OUTPUT,
    @mensaje                = @mensaje   OUTPUT

PRINT 'Resultado: ' + @mensaje
PRINT 'Pedido creado con ID: ' + CAST(@pedido_id AS VARCHAR)

-- Guardar en variable de sesion para los pasos siguientes
-- (copiar el numero impreso arriba y reemplazar en los EXEC siguientes)
SELECT @pedido_id AS pedido_id_generado;
GO

-- ─────────────────────────────────────────────────────────
-- PASO 2: VER LA MESA AHORA — debe aparecer Ocupada
-- ─────────────────────────────────────────────────────────
PRINT ''
PRINT '======================================================'
PRINT 'PASO 2: Mesa 1 ahora deberia estar Ocupada'
PRINT '======================================================'

SELECT mesa_numero, estado_actual, estado_operativo, pedido_activo_id, estado_pedido_activo
FROM vw_EstadoMesas
WHERE mesa_numero = 1;
GO

-- ─────────────────────────────────────────────────────────
-- PASO 3: AGREGAR ITEMS AL PEDIDO
-- Reemplazar @mi_pedido con el ID obtenido en el PASO 1
-- ─────────────────────────────────────────────────────────
PRINT ''
PRINT '======================================================'
PRINT 'PASO 3: Agregar items al pedido'
PRINT '======================================================'

-- !! REEMPLAZAR el valor de @mi_pedido con el ID del PASO 1 !!
DECLARE @mi_pedido INT = (SELECT MAX(pedido_id) FROM PEDIDOS)  -- toma el ultimo pedido creado

DECLARE @detalle_id INT
DECLARE @msg        NVARCHAR(500)

-- Item 1: Empanadas de Carne x2
EXEC sp_AgregarItemPedido
    @pedido_id  = @mi_pedido,
    @plato_id   = 1,          -- Empanadas de Carne (x6)
    @cantidad   = 2,
    @detalle_id = @detalle_id OUTPUT,
    @mensaje    = @msg        OUTPUT
PRINT 'Item 1 - Empanadas x2: ' + @msg

-- Item 2: Provoleta x1
EXEC sp_AgregarItemPedido
    @pedido_id  = @mi_pedido,
    @plato_id   = 2,          -- Provoleta a la Parrilla
    @cantidad   = 1,
    @detalle_id = @detalle_id OUTPUT,
    @mensaje    = @msg        OUTPUT
PRINT 'Item 2 - Provoleta x1: ' + @msg

-- Item 3: Fideos con Tuco x3
EXEC sp_AgregarItemPedido
    @pedido_id  = @mi_pedido,
    @plato_id   = 5,          -- Fideos con Tuco Casero
    @cantidad   = 3,
    @detalle_id = @detalle_id OUTPUT,
    @mensaje    = @msg        OUTPUT
PRINT 'Item 3 - Fideos x3: ' + @msg

-- Ver los items cargados
SELECT
    p.nombre        AS plato,
    dp.cantidad,
    dp.precio_unitario,
    dp.subtotal
FROM DETALLES_PEDIDOS dp
INNER JOIN PLATOS p ON dp.plato_id = p.plato_id
WHERE dp.pedido_id = @mi_pedido;
GO

-- ─────────────────────────────────────────────────────────
-- PASO 4: AVANZAR ESTADO — Pendiente → Confirmado → En Preparacion → Listo
-- ─────────────────────────────────────────────────────────
PRINT ''
PRINT '======================================================'
PRINT 'PASO 4: Avanzar estados del pedido'
PRINT '======================================================'

DECLARE @mi_pedido2 INT = (SELECT MAX(pedido_id) FROM PEDIDOS)
DECLARE @msg2 NVARCHAR(500)

-- Confirmar
EXEC sp_ActualizarEstadoPedido
    @pedido_id                 = @mi_pedido2,
    @nuevo_estado              = 'Confirmado',
    @entregado_por_empleado_id = 2,
    @mensaje                   = @msg2 OUTPUT
PRINT 'Confirmado: ' + @msg2

-- En Preparacion (leemos el nombre exacto desde la BD para evitar problema de tildes en sqlcmd)
DECLARE @estado_prep NVARCHAR(50)
SELECT @estado_prep = nombre FROM ESTADOS_PEDIDOS WHERE nombre LIKE 'En Prepar%'

EXEC sp_ActualizarEstadoPedido
    @pedido_id                 = @mi_pedido2,
    @nuevo_estado              = @estado_prep,
    @entregado_por_empleado_id = 2,
    @mensaje                   = @msg2 OUTPUT
PRINT 'En Preparacion: ' + @msg2

-- Listo para entregar
EXEC sp_ActualizarEstadoPedido
    @pedido_id                 = @mi_pedido2,
    @nuevo_estado              = 'Listo',
    @entregado_por_empleado_id = 2,
    @mensaje                   = @msg2 OUTPUT
PRINT 'Listo: ' + @msg2

-- Ver estado de la mesa durante preparacion
SELECT mesa_numero, estado_actual, estado_operativo, estado_pedido_activo, minutos_ocupada
FROM vw_EstadoMesas
WHERE mesa_numero = 1;
GO

-- ─────────────────────────────────────────────────────────
-- PASO 5: CERRAR EL PEDIDO
-- Calcula total, registra pago y cierra
-- ─────────────────────────────────────────────────────────
PRINT ''
PRINT '======================================================'
PRINT 'PASO 5: Cerrar el pedido (calcular total y registrar)'
PRINT '======================================================'

DECLARE @mi_pedido3 INT = (SELECT MAX(pedido_id) FROM PEDIDOS)
DECLARE @msg3 NVARCHAR(500)

EXEC sp_CerrarPedido
    @pedido_id = @mi_pedido3,
    @mensaje   = @msg3 OUTPUT

PRINT 'Cierre: ' + @msg3

-- Resumen final del pedido
SELECT
    p.pedido_id,
    ep.nombre        AS estado_final,
    p.cant_comensales,
    p.total,
    p.fecha_pedido
FROM PEDIDOS p
INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
WHERE p.pedido_id = @mi_pedido3;
GO

-- ─────────────────────────────────────────────────────────
-- PASO 6: ESTADO FINAL — mesa debe volver a Disponible
-- ─────────────────────────────────────────────────────────
PRINT ''
PRINT '======================================================'
PRINT 'PASO 6: Estado final — mesa debe estar Disponible'
PRINT '======================================================'

SELECT mesa_numero, estado_actual, estado_operativo, pedido_activo_id
FROM vw_EstadoMesas
WHERE mesa_numero = 1;

-- Monitoreo general
SELECT
    pendientes, confirmados, en_preparacion, listos_entrega,
    mesas_ocupadas, mesas_totales, ventas_acumuladas_hoy
FROM vw_MonitoreoTiempoReal;
GO

PRINT ''
PRINT '======================================================'
PRINT 'DEMO COMPLETADA — Ciclo completo de pedido ejecutado'
PRINT '======================================================'
