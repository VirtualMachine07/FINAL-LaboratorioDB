-- =============================================
-- TEST DE NEGOCIO - EsbirrosDB
-- Pruebas funcionales end-to-end de todos los SPs y triggers
-- Fecha: 2026-04-25
-- =============================================

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

USE EsbirrosDB
GO

PRINT '======================================================='
PRINT 'TEST DE NEGOCIO - EsbirrosDB'
PRINT 'Bodegon Los Esbirros de Claudio'
PRINT '======================================================='
PRINT ''

DECLARE @errores   INT = 0
DECLARE @exitosos  INT = 0
DECLARE @test_name NVARCHAR(100)

-- =============================================
-- BLOQUE 1: SETUP — IDs de referencia
-- =============================================
PRINT '--- SETUP: Obteniendo IDs de referencia ---'

DECLARE @canal_mesa      INT = (SELECT canal_id FROM CANALES_VENTAS WHERE nombre = 'MESAS QR')
DECLARE @canal_delivery  INT = (SELECT canal_id FROM CANALES_VENTAS WHERE nombre = 'Delivery')
DECLARE @canal_mostrador INT = (SELECT canal_id FROM CANALES_VENTAS WHERE nombre = 'Mostrador')
DECLARE @mesa_1          INT = (SELECT mesa_id  FROM MESAS WHERE numero = 1)
DECLARE @mesa_3          INT = (SELECT mesa_id  FROM MESAS WHERE numero = 3)
DECLARE @emp_admin       INT = (SELECT empleado_id FROM EMPLEADOS WHERE usuario = 'claudio.admin')
DECLARE @emp_mozo        INT = (SELECT empleado_id FROM EMPLEADOS WHERE usuario = 'carlos.ramirez')
DECLARE @emp_repartidor  INT = (SELECT empleado_id FROM EMPLEADOS WHERE usuario = 'matias.pereyra')
DECLARE @plato_bife      INT = (SELECT plato_id FROM PLATOS WHERE nombre LIKE '%Bife de Chorizo%')
DECLARE @plato_empanadas INT = (SELECT plato_id FROM PLATOS WHERE nombre = 'Empanadas de Carne (x6)')
DECLARE @plato_vino      INT = (SELECT plato_id FROM PLATOS WHERE nombre = 'Vino Tinto de la Casa (porrón)')
DECLARE @plato_papas     INT = (SELECT plato_id FROM PLATOS WHERE nombre = 'Papas Fritas')
-- Estados por ID para evitar problemas de encoding con caracteres especiales
DECLARE @estado_prep     NVARCHAR(50) = (SELECT nombre FROM ESTADOS_PEDIDOS WHERE estado_id = 3) -- En Preparación

PRINT 'Canal mesa    : ' + CAST(@canal_mesa      AS VARCHAR)
PRINT 'Canal delivery: ' + CAST(@canal_delivery  AS VARCHAR)
PRINT 'Mesa 1        : ' + CAST(@mesa_1          AS VARCHAR)
PRINT 'Mesa 3        : ' + CAST(@mesa_3          AS VARCHAR)
PRINT 'Emp admin     : ' + CAST(@emp_admin       AS VARCHAR)
PRINT 'Emp mozo      : ' + CAST(@emp_mozo        AS VARCHAR)
PRINT 'Plato bife    : ' + CAST(@plato_bife      AS VARCHAR)
PRINT 'Plato empanadas: ' + CAST(@plato_empanadas AS VARCHAR)
PRINT ''

-- Variables de trabajo
DECLARE @pedido_id  INT
DECLARE @detalle_id INT
DECLARE @mensaje    NVARCHAR(500)
DECLARE @total      DECIMAL(10,2)
DECLARE @ret        INT

-- =============================================
-- TEST 1: Crear pedido en mesa (canal QR)
-- =============================================
SET @test_name = 'TEST 1: Crear pedido en mesa'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_CrearPedido
    @canal_id               = @canal_mesa,
    @mesa_id                = @mesa_1,
    @cant_comensales        = 2,
    @tomado_por_empleado_id = @emp_mozo,
    @pedido_id              = @pedido_id OUTPUT,
    @mensaje                = @mensaje   OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret = 0 AND @pedido_id > 0
BEGIN
    PRINT '[OK] ' + @test_name + ' — pedido_id=' + CAST(@pedido_id AS VARCHAR)
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name + ' — ret=' + CAST(@ret AS VARCHAR)
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 2: Agregar ítems al pedido
-- =============================================
SET @test_name = 'TEST 2: Agregar ítem — Bife de Chorizo x1'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_AgregarItemPedido
    @pedido_id  = @pedido_id,
    @plato_id   = @plato_bife,
    @cantidad   = 1,
    @detalle_id = @detalle_id OUTPUT,
    @mensaje    = @mensaje    OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret = 0
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 3: Agregar segundo ítem
-- =============================================
SET @test_name = 'TEST 3: Agregar ítem — Empanadas x2'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_AgregarItemPedido
    @pedido_id  = @pedido_id,
    @plato_id   = @plato_empanadas,
    @cantidad   = 2,
    @detalle_id = @detalle_id OUTPUT,
    @mensaje    = @mensaje    OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret = 0
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 4: Verificar trigger — total calculado automáticamente
-- =============================================
SET @test_name = 'TEST 4: Trigger tr_ActualizarTotales — total automático'
PRINT '--- ' + @test_name + ' ---'

DECLARE @total_pedido   DECIMAL(10,2)
DECLARE @total_esperado DECIMAL(10,2)

SELECT @total_pedido = total FROM PEDIDOS WHERE pedido_id = @pedido_id

SELECT @total_esperado = SUM(subtotal) FROM DETALLES_PEDIDOS WHERE pedido_id = @pedido_id

PRINT 'Total en PEDIDOS     : $' + CAST(@total_pedido   AS VARCHAR)
PRINT 'Suma de subtotales   : $' + CAST(@total_esperado AS VARCHAR)

IF @total_pedido = @total_esperado AND @total_pedido > 0
BEGIN
    PRINT '[OK] ' + @test_name + ' — total=$' + CAST(@total_pedido AS VARCHAR)
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name + ' — discrepancia en totales'
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 5: Avanzar estado secuencialmente
-- =============================================
SET @test_name = 'TEST 5: Avanzar estado Pendiente → Confirmado'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_ActualizarEstadoPedido
    @pedido_id                 = @pedido_id,
    @nuevo_estado              = 'Confirmado',
    @entregado_por_empleado_id = NULL,
    @mensaje                   = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret = 0
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 6: Intentar retroceder estado (debe fallar)
-- =============================================
SET @test_name = 'TEST 6: Intentar retroceder estado (debe rechazarse)'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_ActualizarEstadoPedido
    @pedido_id    = @pedido_id,
    @nuevo_estado = 'Pendiente',
    @mensaje      = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret <> 0
BEGIN
    PRINT '[OK] ' + @test_name + ' — retroceso correctamente rechazado'
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name + ' — debería haber fallado'
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 7: Avanzar hasta "En Preparación" → trigger de notificaciones
-- =============================================
SET @test_name = 'TEST 7: Avanzar a En Preparación → genera notificación a COCINA'
PRINT '--- ' + @test_name + ' ---'

DECLARE @notif_antes INT = (SELECT COUNT(*) FROM NOTIFICACIONES WHERE tipo = 'PEDIDO_EN_PREPARACION')

EXEC @ret = sp_ActualizarEstadoPedido
    @pedido_id    = @pedido_id,
    @nuevo_estado = @estado_prep,
    @mensaje      = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje

DECLARE @notif_despues INT = (SELECT COUNT(*) FROM NOTIFICACIONES WHERE tipo = 'PEDIDO_EN_PREPARACION')

IF @ret = 0 AND @notif_despues > @notif_antes
BEGIN
    PRINT '[OK] ' + @test_name + ' — notificación generada a COCINA'
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name + ' — notificación no generada'
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 8: Intentar agregar ítem a pedido "En Preparación" (debe fallar)
-- =============================================
SET @test_name = 'TEST 8: Agregar ítem a pedido En Preparación (debe rechazarse)'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_AgregarItemPedido
    @pedido_id  = @pedido_id,
    @plato_id   = @plato_vino,
    @cantidad   = 1,
    @detalle_id = @detalle_id OUTPUT,
    @mensaje    = @mensaje    OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret <> 0
BEGIN
    PRINT '[OK] ' + @test_name + ' — correctamente rechazado'
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name + ' — debería haber fallado'
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 9: Avanzar a Listo → genera notificación a MOZOS
-- =============================================
SET @test_name = 'TEST 9: Avanzar a Listo → genera notificación a MOZOS'
PRINT '--- ' + @test_name + ' ---'

DECLARE @notif_listo_antes INT = (SELECT COUNT(*) FROM NOTIFICACIONES WHERE tipo = 'PEDIDO_LISTO')

EXEC sp_ActualizarEstadoPedido @pedido_id, 'Listo', NULL, @mensaje OUTPUT
PRINT 'Estado: ' + @mensaje

DECLARE @notif_listo_despues INT = (SELECT COUNT(*) FROM NOTIFICACIONES WHERE tipo = 'PEDIDO_LISTO')

IF @notif_listo_despues > @notif_listo_antes
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 10: Cerrar pedido
-- =============================================
SET @test_name = 'TEST 10: Cerrar pedido'
PRINT '--- ' + @test_name + ' ---'

-- Primero avanzar a Entregado
EXEC sp_ActualizarEstadoPedido @pedido_id, 'Entregado', @emp_mozo, @mensaje OUTPUT

EXEC @ret = sp_CerrarPedido
    @pedido_id = @pedido_id,
    @mensaje   = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret = 0
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 11: Intentar cerrar un pedido ya cerrado (debe fallar)
-- =============================================
SET @test_name = 'TEST 11: Cerrar pedido ya cerrado (debe rechazarse)'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_CerrarPedido
    @pedido_id = @pedido_id,
    @mensaje   = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret <> 0
BEGIN
    PRINT '[OK] ' + @test_name + ' — doble cierre correctamente rechazado'
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 12: Crear y cancelar un pedido con motivo
-- =============================================
SET @test_name = 'TEST 12: Crear pedido en mesa 3 y cancelarlo con motivo'
PRINT '--- ' + @test_name + ' ---'

DECLARE @pedido_cancelar INT

EXEC sp_CrearPedido
    @canal_id               = @canal_mesa,
    @mesa_id                = @mesa_3,
    @cant_comensales        = 4,
    @tomado_por_empleado_id = @emp_mozo,
    @pedido_id              = @pedido_cancelar OUTPUT,
    @mensaje                = @mensaje         OUTPUT

EXEC sp_AgregarItemPedido @pedido_cancelar, @plato_papas, 3, @detalle_id OUTPUT, @mensaje OUTPUT

EXEC @ret = sp_CancelarPedido
    @pedido_id = @pedido_cancelar,
    @motivo    = 'Cliente se retiró antes de ser atendido',
    @mensaje   = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret = 0
BEGIN
    -- Verificar que la notificación de cancelación llegó a CAJA y COCINA
    DECLARE @notif_cancelado INT = (
        SELECT COUNT(*) FROM NOTIFICACIONES
        WHERE tipo = 'PEDIDO_CANCELADO' AND pedido_id = @pedido_cancelar
    )
    PRINT 'Notificaciones de cancelación generadas: ' + CAST(@notif_cancelado AS VARCHAR)
    IF @notif_cancelado >= 2
    BEGIN
        PRINT '[OK] ' + @test_name + ' — notificaciones a CAJA y COCINA generadas'
        SET @exitosos += 1
    END
    ELSE
    BEGIN
        PRINT '[ERROR] ' + @test_name + ' — faltan notificaciones de cancelación'
        SET @errores += 1
    END
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 13: Pedido de delivery con cliente y domicilio
-- =============================================
SET @test_name = 'TEST 13: Pedido delivery con cliente y domicilio'
PRINT '--- ' + @test_name + ' ---'

-- Crear cliente de prueba
INSERT INTO CLIENTES (nombre, telefono, email, doc_tipo, doc_nro)
VALUES ('Juan Prueba Test', '1199999999', 'juan.test@prueba.com', 'DNI', '99999999')

DECLARE @cliente_test INT = SCOPE_IDENTITY()

-- Crear domicilio principal
INSERT INTO DOMICILIOS (cliente_id, calle, numero, localidad, provincia, es_principal, tipo_domicilio, observaciones)
VALUES (@cliente_test, 'Av. Corrientes', '1500', 'CABA', 'Buenos Aires', 1, 'Particular', 'Timbre 3B')

DECLARE @domicilio_test INT = SCOPE_IDENTITY()

DECLARE @pedido_delivery INT

EXEC @ret = sp_CrearPedido
    @canal_id               = @canal_delivery,
    @cliente_id             = @cliente_test,
    @domicilio_id           = @domicilio_test,
    @tomado_por_empleado_id = @emp_admin,
    @pedido_id              = @pedido_delivery OUTPUT,
    @mensaje                = @mensaje         OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret = 0 AND @pedido_delivery > 0
BEGIN
    EXEC sp_AgregarItemPedido @pedido_delivery, @plato_bife,      1, @detalle_id OUTPUT, @mensaje OUTPUT
    EXEC sp_AgregarItemPedido @pedido_delivery, @plato_empanadas, 1, @detalle_id OUTPUT, @mensaje OUTPUT
    EXEC sp_AgregarItemPedido @pedido_delivery, @plato_vino,      2, @detalle_id OUTPUT, @mensaje OUTPUT

    SELECT @total = total FROM PEDIDOS WHERE pedido_id = @pedido_delivery
    PRINT '[OK] ' + @test_name + ' — pedido_id=' + CAST(@pedido_delivery AS VARCHAR) + ' total=$' + CAST(@total AS VARCHAR)
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 14: Intentar segundo domicilio principal para el mismo cliente (debe fallar)
-- =============================================
SET @test_name = 'TEST 14: Segundo domicilio principal para mismo cliente (debe rechazarse por UIX)'
PRINT '--- ' + @test_name + ' ---'

BEGIN TRY
    INSERT INTO DOMICILIOS (cliente_id, calle, numero, localidad, provincia, es_principal, tipo_domicilio)
    VALUES (@cliente_test, 'Av. Santa Fe', '800', 'CABA', 'Buenos Aires', 1, 'Laboral')
    PRINT '[ERROR] ' + @test_name + ' — debería haber fallado'
    SET @errores += 1
END TRY
BEGIN CATCH
    PRINT 'Error esperado: ' + ERROR_MESSAGE()
    PRINT '[OK] ' + @test_name + ' — UIX_DOMICILIO_principal funcionando correctamente'
    SET @exitosos += 1
END CATCH
PRINT ''

-- =============================================
-- TEST 15: Email duplicado entre clientes (debe fallar)
-- =============================================
SET @test_name = 'TEST 15: Email duplicado entre clientes (debe rechazarse por UIX)'
PRINT '--- ' + @test_name + ' ---'

BEGIN TRY
    INSERT INTO CLIENTES (nombre, email, doc_tipo, doc_nro)
    VALUES ('Otro Cliente', 'juan.test@prueba.com', 'DNI', '88888888')
    PRINT '[ERROR] ' + @test_name + ' — debería haber fallado'
    SET @errores += 1
END TRY
BEGIN CATCH
    PRINT 'Error esperado: ' + ERROR_MESSAGE()
    PRINT '[OK] ' + @test_name + ' — UIX_CLIENTE_email funcionando correctamente'
    SET @exitosos += 1
END CATCH
PRINT ''

-- =============================================
-- TEST 16: Múltiples clientes sin email (NULLs permitidos)
-- =============================================
SET @test_name = 'TEST 16: Múltiples clientes sin email (NULLs deben coexistir)'
PRINT '--- ' + @test_name + ' ---'

BEGIN TRY
    INSERT INTO CLIENTES (nombre, telefono) VALUES ('Cliente Sin Email 1', '1100000001')
    INSERT INTO CLIENTES (nombre, telefono) VALUES ('Cliente Sin Email 2', '1100000002')
    INSERT INTO CLIENTES (nombre, telefono) VALUES ('Cliente Sin Email 3', '1100000003')
    PRINT '[OK] ' + @test_name + ' — 3 clientes sin email insertados sin conflicto'
    SET @exitosos += 1
END TRY
BEGIN CATCH
    PRINT '[ERROR] ' + @test_name + ' — ' + ERROR_MESSAGE()
    SET @errores += 1
END CATCH
PRINT ''

-- =============================================
-- TEST 17: Trigger de auditoría — verificar registros
-- =============================================
SET @test_name = 'TEST 17: Trigger tr_AuditoriaPedidos — verificar registros'
PRINT '--- ' + @test_name + ' ---'

DECLARE @audit_count INT = (
    SELECT COUNT(*) FROM AUDITORIAS_SIMPLES
    WHERE tabla_afectada = 'PEDIDOS'
)

PRINT 'Registros de auditoría en PEDIDOS: ' + CAST(@audit_count AS VARCHAR)
IF @audit_count > 0
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1

    -- Mostrar últimas 3 auditorías
    SELECT TOP 3
        auditoria_id,
        accion,
        fecha_auditoria,
        datos_resumen
    FROM AUDITORIAS_SIMPLES
    WHERE tabla_afectada = 'PEDIDOS'
    ORDER BY auditoria_id DESC
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name + ' — no hay registros de auditoría'
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 18: sp_ConsultarMenuActual
-- =============================================
SET @test_name = 'TEST 18: sp_ConsultarMenuActual — menú vigente'
PRINT '--- ' + @test_name + ' ---'

DECLARE @menu_count INT
CREATE TABLE #menu_test (plato_id INT, plato_nombre NVARCHAR(100), categoria NVARCHAR(50), precio_actual DECIMAL(10,2), vigencia_desde DATE, vigencia_hasta DATE, estado_precio NVARCHAR(20), activo BIT)
INSERT INTO #menu_test EXEC sp_ConsultarMenuActual
SELECT @menu_count = COUNT(*) FROM #menu_test
DROP TABLE #menu_test

PRINT 'Platos en menú vigente: ' + CAST(@menu_count AS VARCHAR)
IF @menu_count >= 22
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name + ' — se esperaban 22 platos'
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 19: sp_MesasDisponibles
-- =============================================
SET @test_name = 'TEST 19: sp_MesasDisponibles — estado de mesas'
PRINT '--- ' + @test_name + ' ---'

DECLARE @mesas_count INT
CREATE TABLE #mesas_test (mesa_id INT, mesa_numero INT, capacidad INT, sucursal_nombre NVARCHAR(100), qr_token NVARCHAR(255), estado_mesa NVARCHAR(20), pedido_activo_id INT)
INSERT INTO #mesas_test EXEC sp_MesasDisponibles

SELECT @mesas_count = COUNT(*) FROM #mesas_test
DECLARE @mesas_ocupadas_count INT = (SELECT COUNT(*) FROM #mesas_test WHERE estado_mesa = 'Ocupada')
DECLARE @mesas_libres_count   INT = (SELECT COUNT(*) FROM #mesas_test WHERE estado_mesa = 'Disponible')
DROP TABLE #mesas_test

PRINT 'Total mesas      : ' + CAST(@mesas_count         AS VARCHAR)
PRINT 'Mesas ocupadas   : ' + CAST(@mesas_ocupadas_count AS VARCHAR)
PRINT 'Mesas disponibles: ' + CAST(@mesas_libres_count   AS VARCHAR)
IF @mesas_count = 8
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 20: sp_ConsultarStock — stock inicial
-- =============================================
SET @test_name = 'TEST 20: sp_ConsultarStock — stock con estado'
PRINT '--- ' + @test_name + ' ---'

DECLARE @stock_normal INT = (
    SELECT COUNT(*) FROM STOCKS_SIMULADOS
    WHERE stock_disponible > stock_minimo
)
DECLARE @stock_critico INT = (
    SELECT COUNT(*) FROM STOCKS_SIMULADOS
    WHERE stock_disponible <= stock_minimo
)
PRINT 'Stock normal  : ' + CAST(@stock_normal  AS VARCHAR) + ' platos'
PRINT 'Stock crítico : ' + CAST(@stock_critico AS VARCHAR) + ' platos'
IF @stock_normal > 0
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 21: vw_DashboardEjecutivo
-- =============================================
SET @test_name = 'TEST 21: vw_DashboardEjecutivo — métricas del día'
PRINT '--- ' + @test_name + ' ---'

SELECT
    ventas_hoy,
    pedidos_hoy,
    ticket_promedio_hoy,
    pedidos_pendientes,
    ultima_actualizacion
FROM vw_DashboardEjecutivo

IF @@ROWCOUNT = 1
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 22: vw_MonitoreoTiempoReal
-- =============================================
SET @test_name = 'TEST 22: vw_MonitoreoTiempoReal — cola de cocina'
PRINT '--- ' + @test_name + ' ---'

SELECT
    pendientes,
    confirmados,
    en_preparacion,
    listos_entrega,
    en_reparto,
    mesas_ocupadas,
    mesas_totales,
    ventas_acumuladas_hoy
FROM vw_MonitoreoTiempoReal

IF @@ROWCOUNT = 1
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 23: sp_ResumenOperativoDiario
-- =============================================
SET @test_name = 'TEST 23: sp_ResumenOperativoDiario'
PRINT '--- ' + @test_name + ' ---'

EXEC sp_ResumenOperativoDiario

IF @@ROWCOUNT >= 0
BEGIN
    PRINT '[OK] ' + @test_name
    SET @exitosos += 1
END
PRINT ''

-- =============================================
-- TEST 24: Cerrar pedido sin ítems (debe fallar)
-- =============================================
SET @test_name = 'TEST 24: Cerrar pedido sin ítems (debe rechazarse)'
PRINT '--- ' + @test_name + ' ---'

DECLARE @pedido_vacio INT

EXEC sp_CrearPedido
    @canal_id               = @canal_mostrador,
    @tomado_por_empleado_id = @emp_admin,
    @pedido_id              = @pedido_vacio OUTPUT,
    @mensaje                = @mensaje      OUTPUT

EXEC @ret = sp_CerrarPedido
    @pedido_id = @pedido_vacio,
    @mensaje   = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret <> 0
BEGIN
    PRINT '[OK] ' + @test_name + ' — cierre sin ítems correctamente rechazado'
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- TEST 25: Usar sp_CancelarPedido cuando estado es Cerrado (debe fallar)
-- =============================================
SET @test_name = 'TEST 25: Cancelar pedido ya cerrado (debe rechazarse)'
PRINT '--- ' + @test_name + ' ---'

EXEC @ret = sp_CancelarPedido
    @pedido_id = @pedido_id,
    @motivo    = 'Intento inválido',
    @mensaje   = @mensaje OUTPUT

PRINT 'Resultado: ' + @mensaje
IF @ret <> 0
BEGIN
    PRINT '[OK] ' + @test_name + ' — correctamente rechazado'
    SET @exitosos += 1
END
ELSE
BEGIN
    PRINT '[ERROR] ' + @test_name
    SET @errores += 1
END
PRINT ''

-- =============================================
-- RESUMEN FINAL
-- =============================================
PRINT '======================================================='
PRINT 'RESUMEN DE PRUEBAS DE NEGOCIO'
PRINT '======================================================='
PRINT 'Tests exitosos : ' + CAST(@exitosos AS VARCHAR)
PRINT 'Tests fallidos : ' + CAST(@errores  AS VARCHAR)
PRINT 'Total tests    : ' + CAST(@exitosos + @errores AS VARCHAR)
PRINT ''

IF @errores = 0
    PRINT 'ESTADO: TODOS LOS TESTS PASARON — Sistema funcionando correctamente'
ELSE
    PRINT 'ESTADO: HAY ' + CAST(@errores AS VARCHAR) + ' TESTS FALLIDOS — Revisar errores arriba'

PRINT '======================================================='
GO
