-- =============================================
-- BUNDLE F - CARGA MASIVA DE DATOS
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Genera 10,000+ registros de prueba para testing y análisis
-- Versión: 3.0 (definitiva) - Sin tildes, solo canales válidos
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================
--
-- CONTENIDO GENERADO:
--   - 3,000 clientes (DNIs 30,000,001 - 30,003,000)
--   - 3,000 domicilios (uno por cliente)
--   - 10,000 pedidos distribuidos en 6 meses
--       * 50% Mostrador
--       * 30% Delivery
--       * 15% MESAS QR
--       * 5%  Telefono (sin tilde - encoding limpio)
--   - 30,000+ ítems de pedidos (2-4 ítems por pedido)
--
-- TOTAL ESTIMADO: ~43,000 registros
-- TIEMPO ESTIMADO: 30-60 segundos
--
-- PREREQUISITOS (ejecutar en orden antes de este script):
--   Bundle_A1 + Bundle_A2  → Infraestructura + datos maestros
--   Bundle_B1 + B2 + B3    → Lógica de negocio (SPs de pedidos)
--   Bundle_C               → Seguridad (roles, usuarios)
--   Bundle_D               → Consultas básicas (vistas)
--   Bundle_E1 + E2         → Triggers activos (totales, auditoría, stock)
--   Bundle_R1 + R2         → Reportes y dashboard (opcional)
--
-- NOTAS:
--   - Limpia datos previos de carga masiva preservando catálogos y empleados
--   - Nombres y canales SIN TILDES (encoding limpio, evita corrupción)
--   - Canal 'Telefono' sin tilde (coincide con el valor cargado en A2)
--   - Compatible con SQL Server sin configuración adicional de encoding
-- =============================================

USE EsbirrosDB;
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT '======================================================='
PRINT 'BUNDLE F - CARGA MASIVA DE DATOS v3.0'
PRINT '======================================================='
PRINT 'Generando 10,000+ registros para testing...'
PRINT 'Inicio: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT ''

-- =============================================
-- LIMPIEZA DE DATOS PREVIOS (si existen)
-- =============================================

PRINT 'Limpiando datos previos de carga masiva...'

DELETE FROM DETALLES_PEDIDOS;
DELETE FROM PEDIDOS;
DELETE FROM DOMICILIOS;
DELETE FROM CLIENTES WHERE cliente_id > 19; -- Preservar empleados y admin
DELETE FROM NOTIFICACIONES;
DELETE FROM AUDITORIAS_SIMPLES;

PRINT '   Datos previos eliminados - OK'
PRINT ''

-- =============================================
-- PASO 1: GENERAR CLIENTES (3,000 clientes)
-- =============================================

PRINT '1. Generando 3,000 clientes...'

DECLARE @i INT = 1
DECLARE @nombres TABLE (nombre NVARCHAR(50))
INSERT INTO @nombres VALUES 
('Juan'),('Maria'),('Carlos'),('Ana'),('Luis'),('Laura'),('Pedro'),('Sofia'),
('Miguel'),('Elena'),('Jorge'),('Carmen'),('Roberto'),('Isabel'),('Diego'),
('Patricia'),('Fernando'),('Lucia'),('Ricardo'),('Martina'),('Andres'),('Valentina')

DECLARE @apellidos TABLE (apellido NVARCHAR(50))
INSERT INTO @apellidos VALUES 
('Gonzalez'),('Rodriguez'),('Fernandez'),('Lopez'),('Martinez'),('Sanchez'),
('Perez'),('Gomez'),('Martin'),('Jimenez'),('Ruiz'),('Hernandez'),('Diaz'),
('Moreno'),('Munoz'),('Alvarez'),('Romero'),('Alonso'),('Gutierrez'),('Navarro')

WHILE @i <= 3000
BEGIN
    INSERT INTO CLIENTES (nombre, email, telefono, doc_tipo, doc_nro)
    SELECT TOP 1
        n.nombre + ' ' + a.apellido,
        LOWER(n.nombre) + '.' + LOWER(a.apellido) + CAST(@i AS VARCHAR) + '@email.com',
        '11' + RIGHT('00000000' + CAST(30000000 + @i AS VARCHAR), 8),
        'DNI',
        30000000 + @i
    FROM @nombres n
    CROSS APPLY (SELECT TOP 1 apellido FROM @apellidos ORDER BY NEWID()) a
    ORDER BY NEWID()

    SET @i = @i + 1

    IF @i % 500 = 0
        PRINT '   Clientes creados: ' + CAST(@i AS VARCHAR)
END

PRINT '   Total clientes: 3,000 - OK'
PRINT ''

-- =============================================
-- PASO 2: GENERAR DOMICILIOS (3,000 domicilios)
-- =============================================

PRINT '2. Generando 3,000 domicilios...'

DECLARE @calles TABLE (calle NVARCHAR(100))
INSERT INTO @calles VALUES 
('Av. Corrientes'),('Av. Santa Fe'),('Av. Cabildo'),('Av. Rivadavia'),
('Calle Florida'),('Av. 9 de Julio'),('Av. Callao'),('Av. Cordoba'),
('Calle Lavalle'),('Av. Las Heras'),('Calle Reconquista'),('Av. Pueyrredon')

INSERT INTO DOMICILIOS (cliente_id, calle, numero, piso, depto, localidad, provincia, es_principal, tipo_domicilio, observaciones)
SELECT
    c.cliente_id,
    (SELECT TOP 1 calle FROM @calles ORDER BY NEWID()),
    100 + (c.cliente_id % 9000),
    CASE WHEN c.cliente_id % 3 = 0 THEN CAST((c.cliente_id % 20) + 1 AS VARCHAR(5)) ELSE NULL END,
    CASE WHEN c.cliente_id % 3 = 0 THEN CHAR(65 + (c.cliente_id % 10)) ELSE NULL END,
    'CABA',
    'Buenos Aires',
    1,
    CASE
        WHEN c.cliente_id % 4 = 0 THEN 'Particular'
        WHEN c.cliente_id % 4 = 1 THEN 'Laboral'
        WHEN c.cliente_id % 4 = 2 THEN 'Temporal'
        ELSE 'Particular'
    END,
    CASE
        WHEN c.cliente_id % 4 = 0 THEN 'Domicilio particular del cliente'
        WHEN c.cliente_id % 4 = 1 THEN 'Domicilio laboral / oficina'
        WHEN c.cliente_id % 4 = 2 THEN 'Domicilio temporal (vacacional o transitorio)'
        ELSE 'Domicilio particular del cliente'
    END
FROM CLIENTES c
WHERE c.cliente_id > 19

PRINT '   Total domicilios: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' - OK'
PRINT ''

-- =============================================
-- PASO 3: GENERAR PEDIDOS (10,000 pedidos)
-- =============================================

PRINT '3. Generando 10,000 pedidos...'

DECLARE @canal_mostrador INT = (SELECT canal_id FROM CANALES_VENTAS WHERE nombre = 'Mostrador')
DECLARE @canal_delivery   INT = (SELECT canal_id FROM CANALES_VENTAS WHERE nombre = 'Delivery')
DECLARE @canal_mesa_qr    INT = (SELECT canal_id FROM CANALES_VENTAS WHERE nombre = 'MESAS QR')
DECLARE @canal_telefono   INT = (SELECT canal_id FROM CANALES_VENTAS WHERE nombre = 'Telefono')

DECLARE @estado_cerrado   INT = (SELECT estado_id FROM ESTADOS_PEDIDOS WHERE nombre = 'Cerrado')
DECLARE @estado_entregado INT = (SELECT estado_id FROM ESTADOS_PEDIDOS WHERE nombre = 'Entregado')
DECLARE @estado_cancelado INT = (SELECT estado_id FROM ESTADOS_PEDIDOS WHERE nombre = 'Cancelado')

DECLARE @min_cliente_id INT = (SELECT MIN(cliente_id) FROM CLIENTES WHERE cliente_id > 19)
DECLARE @max_cliente_id INT = (SELECT MAX(cliente_id) FROM CLIENTES WHERE cliente_id > 19)

SET @i = 1
WHILE @i <= 10000
BEGIN
    DECLARE @canal_id          INT
    DECLARE @mesa_id           INT
    DECLARE @cliente_id_pedido INT
    DECLARE @domicilio_id      INT
    DECLARE @estado_id         INT
    DECLARE @dias_atras        INT
    DECLARE @fecha_pedido      DATETIME

    -- Distribución temporal: más recientes con más pedidos
    SET @dias_atras = CASE
        WHEN @i % 100 < 40 THEN @i % 7          -- 40% última semana
        WHEN @i % 100 < 70 THEN 7 + (@i % 23)   -- 30% último mes
        ELSE 30 + (@i % 150)                     -- 30% últimos 6 meses
    END

    SET @fecha_pedido = DATEADD(DAY,    -@dias_atras,    GETDATE())
    SET @fecha_pedido = DATEADD(HOUR,   12 + (@i % 10), @fecha_pedido)
    SET @fecha_pedido = DATEADD(MINUTE, @i % 60,        @fecha_pedido)

    -- Distribución de canales: 50% Mostrador / 30% Delivery / 15% MESAS QR / 5% Telefono
    SET @canal_id = CASE
        WHEN @i % 100 < 50 THEN @canal_mostrador
        WHEN @i % 100 < 80 THEN @canal_delivery
        WHEN @i % 100 < 95 THEN @canal_mesa_qr
        ELSE @canal_telefono
    END

    -- Mesa solo para Mostrador y MESAS QR
    SET @mesa_id = CASE
        WHEN @canal_id IN (@canal_mostrador, @canal_mesa_qr) THEN ((@i % 8) + 1)
        ELSE NULL
    END

    -- 90% de pedidos con cliente registrado
    SET @cliente_id_pedido = CASE
        WHEN @i % 100 < 90
        THEN @min_cliente_id + (@i % (@max_cliente_id - @min_cliente_id + 1))
        ELSE NULL
    END

    -- Domicilio solo en delivery con cliente
    SET @domicilio_id = CASE
        WHEN @canal_id = @canal_delivery AND @cliente_id_pedido IS NOT NULL
        THEN (SELECT TOP 1 domicilio_id FROM DOMICILIOS WHERE cliente_id = @cliente_id_pedido)
        ELSE NULL
    END

    -- Estado: pedidos viejos mayormente cerrados, recientes variados
    SET @estado_id = CASE
        WHEN @dias_atras > 7
        THEN CASE WHEN @i % 100 < 97 THEN @estado_cerrado   ELSE @estado_cancelado END
        ELSE CASE WHEN @i % 100 < 90 THEN @estado_entregado ELSE @estado_cancelado END
    END

    INSERT INTO PEDIDOS (
        fecha_pedido,
        fecha_entrega,
        canal_id,
        mesa_id,
        cliente_id,
        domicilio_id,
        cant_comensales,
        estado_id,
        tomado_por_empleado_id,
        entregado_por_empleado_id,
        total,
        observaciones
    )
    VALUES (
        @fecha_pedido,
        CASE WHEN @estado_id IN (@estado_entregado, @estado_cerrado)
             THEN DATEADD(MINUTE, 30 + (@i % 60), @fecha_pedido)
             ELSE NULL
        END,
        @canal_id,
        @mesa_id,
        @cliente_id_pedido,
        @domicilio_id,
        CASE WHEN @mesa_id IS NOT NULL THEN 1 + (@i % 6) ELSE NULL END,
        @estado_id,
        1 + (@i % 19),  -- empleado aleatorio
        CASE WHEN @estado_id IN (@estado_entregado, @estado_cerrado) THEN 1 + (@i % 19) ELSE NULL END,
        0,              -- el trigger tr_ActualizarTotales recalculará el total
        CASE
            WHEN @i % 20 = 0 THEN 'Sin cebolla'
            WHEN @i % 25 = 0 THEN 'Bien cocido'
            WHEN @i % 30 = 0 THEN 'Para llevar'
            ELSE NULL
        END
    )

    SET @i = @i + 1

    IF @i % 2000 = 0
        PRINT '   Pedidos creados: ' + CAST(@i AS VARCHAR)
END

PRINT '   Total pedidos: 10,000 - OK'
PRINT ''

-- =============================================
-- PASO 4: GENERAR DETALLES DE PEDIDOS (30,000+ ítems)
-- =============================================

PRINT '4. Generando items de pedidos (2-4 items por pedido)...'

DECLARE @min_plato_id INT = (SELECT MIN(plato_id) FROM PLATOS)
DECLARE @max_plato_id INT = (SELECT MAX(plato_id) FROM PLATOS)

INSERT INTO DETALLES_PEDIDOS (pedido_id, plato_id, cantidad, precio_unitario, subtotal)
SELECT
    p.pedido_id,
    @min_plato_id + (ABS(CHECKSUM(NEWID())) % (@max_plato_id - @min_plato_id + 1)),
    1 + (ABS(CHECKSUM(NEWID())) % 3),   -- 1-3 unidades
    pr.monto,
    (1 + (ABS(CHECKSUM(NEWID())) % 3)) * pr.monto
FROM PEDIDOS p
CROSS JOIN (SELECT 1 AS n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) items
CROSS APPLY (
    SELECT TOP 1 monto
    FROM PRECIOS
    WHERE plato_id = @min_plato_id + (ABS(CHECKSUM(NEWID())) % (@max_plato_id - @min_plato_id + 1))
    ORDER BY vigencia_desde DESC
) pr
WHERE items.n <= (2 + (p.pedido_id % 3))  -- 2-4 ítems por pedido

PRINT '   Total items: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' - OK'
PRINT ''

-- =============================================
-- RESUMEN FINAL Y ESTADÍSTICAS
-- =============================================

PRINT '======================================================='
PRINT 'BUNDLE F - CARGA MASIVA COMPLETADA'
PRINT '======================================================='
PRINT ''

DECLARE @total_clientes    INT
DECLARE @total_domicilios  INT
DECLARE @total_pedidos     INT
DECLARE @total_items_final INT
DECLARE @total_auditoria   INT
DECLARE @total_notif       INT
DECLARE @total_facturacion DECIMAL(18,2)

SELECT @total_clientes    = COUNT(*) FROM CLIENTES         WHERE cliente_id > 19
SELECT @total_domicilios  = COUNT(*) FROM DOMICILIOS
SELECT @total_pedidos     = COUNT(*) FROM PEDIDOS
SELECT @total_items_final = COUNT(*) FROM DETALLES_PEDIDOS
SELECT @total_auditoria   = COUNT(*) FROM AUDITORIAS_SIMPLES
SELECT @total_notif       = COUNT(*) FROM NOTIFICACIONES
SELECT @total_facturacion = SUM(p.total)
FROM PEDIDOS p
INNER JOIN ESTADOS_PEDIDOS ep ON p.estado_id = ep.estado_id
WHERE ep.nombre IN ('Entregado', 'Cerrado')

PRINT 'ESTADISTICAS FINALES:'
PRINT '----------------------------------------------------'
PRINT 'Clientes nuevos        : ' + CAST(@total_clientes    AS VARCHAR)
PRINT 'Domicilios registrados : ' + CAST(@total_domicilios  AS VARCHAR)
PRINT 'Pedidos generados      : ' + CAST(@total_pedidos     AS VARCHAR)
PRINT 'Items de pedidos       : ' + CAST(@total_items_final AS VARCHAR)
PRINT 'Registros auditoria    : ' + CAST(@total_auditoria   AS VARCHAR)
PRINT 'Notificaciones         : ' + CAST(@total_notif       AS VARCHAR)
PRINT ''
PRINT 'TOTAL REGISTROS NUEVOS : ' + CAST(
    @total_clientes + @total_domicilios + @total_pedidos +
    @total_items_final + @total_auditoria + @total_notif AS VARCHAR
) + ' registros'
PRINT ''
PRINT 'Facturacion historica  : $' + CAST(ISNULL(@total_facturacion, 0) AS VARCHAR)
PRINT ''

-- Distribución por canal
PRINT 'DISTRIBUCION POR CANAL:'
SELECT
    cv.nombre                                                                          AS Canal,
    COUNT(p.pedido_id)                                                                 AS Pedidos,
    SUM(CASE WHEN ep.nombre IN ('Entregado','Cerrado') THEN 1 ELSE 0 END)              AS Completados,
    CAST(SUM(CASE WHEN ep.nombre IN ('Entregado','Cerrado') THEN p.total ELSE 0 END)
         AS DECIMAL(18,2))                                                             AS Facturacion
FROM CANALES_VENTAS cv
LEFT JOIN PEDIDOS         p  ON cv.canal_id  = p.canal_id
LEFT JOIN ESTADOS_PEDIDOS ep ON p.estado_id  = ep.estado_id
GROUP BY cv.nombre
ORDER BY Facturacion DESC

PRINT ''

-- Distribución por estado
PRINT 'DISTRIBUCION POR ESTADO:'
SELECT
    ep.nombre                                        AS Estado,
    COUNT(p.pedido_id)                               AS Cantidad,
    CAST(AVG(ISNULL(p.total, 0)) AS DECIMAL(10,2))  AS TicketPromedio
FROM ESTADOS_PEDIDOS ep
LEFT JOIN PEDIDOS p ON ep.estado_id = p.estado_id
GROUP BY ep.nombre
ORDER BY Cantidad DESC

PRINT ''
PRINT 'Fin: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '======================================================='
PRINT 'BUNDLE F COMPLETADO - Sistema listo para testing'
PRINT '======================================================='
GO
