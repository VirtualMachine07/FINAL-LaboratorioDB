-- =============================================
-- BUNDLE G - VERIFICACION DE CARGA MASIVA
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Crea la vista vw_ResumenCargaMasiva y muestra
--              las cantidades de registros cargados en cada tabla
-- Versión: 1.0
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================
--
-- PREREQUISITOS:
--   Ejecutar DESPUÉS de Bundle_F (carga masiva de datos)
--
-- RESULTADO ESPERADO (post Bundle F):
--   CLIENTES              ~3,004  (4 manuales + 3,000 masivos)
--   DOMICILIOS            ~2,986  (con tipo_domicilio y es_principal)
--   PEDIDOS               ~10,000
--   DETALLES_PEDIDOS      ~30,001
--   AUDITORIAS_SIMPLES    ~50,001+
--   NOTIFICACIONES             0   (carga masiva no pasa por triggers de notif.)
--   EMPLEADOS             variable
--   ROLES                      9
--   PLATOS                    22
--   PRECIOS               variable
--   STOCKS_SIMULADOS          22   (uno por plato)
--   ESTADOS_PEDIDOS            8
--   CANALES_VENTAS             4
--   MESAS                      8
--   SUCURSALES                 1
--   REPORTES_GENERADOS    variable
-- =============================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

USE EsbirrosDB;
GO

-- =============================================
-- SECCIÓN 1: CREAR (O RECREAR) LA VISTA
-- =============================================

IF OBJECT_ID('dbo.vw_ResumenCargaMasiva', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ResumenCargaMasiva;
GO

CREATE VIEW dbo.vw_ResumenCargaMasiva AS
-- Datos de operación principal
SELECT 'CLIENTES'          AS tabla,
       COUNT(*)            AS total_registros,
       'Clientes registrados en el sistema'      AS descripcion
FROM CLIENTES

UNION ALL

SELECT 'DOMICILIOS',
       COUNT(*),
       'Domicilios asociados a clientes'
FROM DOMICILIOS

UNION ALL

SELECT 'PEDIDOS',
       COUNT(*),
       'Pedidos generados en todos los estados'
FROM PEDIDOS

UNION ALL

SELECT 'DETALLES_PEDIDOS',
       COUNT(*),
       'Items de detalle (platos por pedido)'
FROM DETALLES_PEDIDOS

UNION ALL

SELECT 'AUDITORIAS_SIMPLES',
       COUNT(*),
       'Cambios de estado auditados automaticamente'
FROM AUDITORIAS_SIMPLES

UNION ALL

SELECT 'NOTIFICACIONES',
       COUNT(*),
       'Notificaciones generadas por triggers'
FROM NOTIFICACIONES

UNION ALL

SELECT 'EMPLEADOS',
       COUNT(*),
       'Empleados registrados en el sistema'
FROM EMPLEADOS

UNION ALL

SELECT 'REPORTES_GENERADOS',
       COUNT(*),
       'Reportes generados y almacenados'
FROM REPORTES_GENERADOS

UNION ALL

-- Tablas maestras / catálogos
SELECT 'PLATOS',
       COUNT(*),
       'Platos del menu del bodegon'
FROM PLATOS

UNION ALL

SELECT 'PRECIOS',
       COUNT(*),
       'Registros de precios historicos (vigentes e historicos)'
FROM PRECIOS

UNION ALL

SELECT 'STOCKS_SIMULADOS',
       COUNT(*),
       'Registros de stock simulado por plato'
FROM STOCKS_SIMULADOS

UNION ALL

-- Tablas de configuración
SELECT 'ESTADOS_PEDIDOS',
       COUNT(*),
       'Estados posibles de un pedido (flujo de 8 estados)'
FROM ESTADOS_PEDIDOS

UNION ALL

SELECT 'CANALES_VENTAS',
       COUNT(*),
       'Canales de venta habilitados'
FROM CANALES_VENTAS

UNION ALL

SELECT 'ROLES',
       COUNT(*),
       'Roles de seguridad del sistema'
FROM ROLES

UNION ALL

SELECT 'MESAS',
       COUNT(*),
       'Mesas fisicas del local'
FROM MESAS

UNION ALL

SELECT 'SUCURSALES',
       COUNT(*),
       'Sucursales registradas'
FROM SUCURSALES

UNION ALL

-- Fila de total general
SELECT '>>> TOTAL',
       (SELECT SUM(cnt) FROM (
           SELECT COUNT(*) AS cnt FROM CLIENTES
           UNION ALL SELECT COUNT(*) FROM DOMICILIOS
           UNION ALL SELECT COUNT(*) FROM PEDIDOS
           UNION ALL SELECT COUNT(*) FROM DETALLES_PEDIDOS
           UNION ALL SELECT COUNT(*) FROM AUDITORIAS_SIMPLES
           UNION ALL SELECT COUNT(*) FROM NOTIFICACIONES
           UNION ALL SELECT COUNT(*) FROM EMPLEADOS
           UNION ALL SELECT COUNT(*) FROM REPORTES_GENERADOS
           UNION ALL SELECT COUNT(*) FROM PLATOS
           UNION ALL SELECT COUNT(*) FROM PRECIOS
           UNION ALL SELECT COUNT(*) FROM STOCKS_SIMULADOS
           UNION ALL SELECT COUNT(*) FROM ESTADOS_PEDIDOS
           UNION ALL SELECT COUNT(*) FROM CANALES_VENTAS
           UNION ALL SELECT COUNT(*) FROM ROLES
           UNION ALL SELECT COUNT(*) FROM MESAS
           UNION ALL SELECT COUNT(*) FROM SUCURSALES
       ) AS totales),
       '*** TOTAL DE REGISTROS EN TODA LA BASE DE DATOS ***';
GO

PRINT '>> Vista vw_ResumenCargaMasiva creada exitosamente.';
GO

-- =============================================
-- SECCIÓN 2: CONSULTAR LA VISTA (RESUMEN POR TABLA)
-- =============================================

PRINT '======================================================';
PRINT '  RESUMEN DE CARGA - EsbirrosDB';
PRINT '======================================================';

SELECT
    tabla                           AS [Tabla],
    total_registros                 AS [Registros],
    descripcion                     AS [Descripción]
FROM vw_ResumenCargaMasiva
ORDER BY
    -- Primero tablas de operación, luego maestras, luego configuración
    CASE tabla
        WHEN 'CLIENTES'            THEN 1
        WHEN 'DOMICILIOS'          THEN 2
        WHEN 'PEDIDOS'             THEN 3
        WHEN 'DETALLES_PEDIDOS'    THEN 4
        WHEN 'AUDITORIAS_SIMPLES'  THEN 5
        WHEN 'NOTIFICACIONES'      THEN 6
        WHEN 'EMPLEADOS'           THEN 7
        WHEN 'REPORTES_GENERADOS'  THEN 8
        WHEN 'PLATOS'              THEN 9
        WHEN 'PRECIOS'             THEN 10
        WHEN 'STOCKS_SIMULADOS'    THEN 11
        WHEN 'ESTADOS_PEDIDOS'     THEN 12
        WHEN 'CANALES_VENTAS'      THEN 13
        WHEN 'ROLES'               THEN 14
        WHEN 'MESAS'               THEN 15
        WHEN 'SUCURSALES'          THEN 16
        WHEN '>>> TOTAL'           THEN 99
        ELSE 100
    END;
GO

-- =============================================
-- SECCIÓN 3: TOTALES AGREGADOS
-- =============================================

PRINT '';
PRINT '------------------------------------------------------';
PRINT '  TOTAL GENERAL DE REGISTROS EN LA BASE DE DATOS';
PRINT '------------------------------------------------------';

SELECT
    SUM(total_registros)            AS [Total General de Registros],
    COUNT(*) - 1                    AS [Tablas con datos],
    SUM(CASE WHEN total_registros = 0 THEN 1 ELSE 0 END)
                                    AS [Tablas vacias]
FROM vw_ResumenCargaMasiva
WHERE tabla <> '>>> TOTAL';
GO

-- =============================================
-- SECCIÓN 4: DISTRIBUCIÓN DE PEDIDOS POR ESTADO
-- =============================================

PRINT '';
PRINT '------------------------------------------------------';
PRINT '  DISTRIBUCION DE PEDIDOS POR ESTADO';
PRINT '------------------------------------------------------';

SELECT
    ep.nombre                       AS [Estado],
    COUNT(p.pedido_id)              AS [Cantidad de Pedidos],
    CAST(
        COUNT(p.pedido_id) * 100.0
        / NULLIF((SELECT COUNT(*) FROM PEDIDOS), 0)
    AS DECIMAL(5,2))                AS [Porcentaje %]
FROM ESTADOS_PEDIDOS ep
LEFT JOIN PEDIDOS p ON p.estado_id = ep.estado_id
GROUP BY ep.estado_id, ep.nombre
ORDER BY ep.estado_id;
GO

-- =============================================
-- SECCIÓN 5: DISTRIBUCIÓN DE PEDIDOS POR CANAL
-- =============================================

PRINT '';
PRINT '------------------------------------------------------';
PRINT '  DISTRIBUCION DE PEDIDOS POR CANAL';
PRINT '------------------------------------------------------';

SELECT
    c.nombre                        AS [Canal],
    COUNT(p.pedido_id)              AS [Cantidad de Pedidos],
    CAST(
        COUNT(p.pedido_id) * 100.0
        / NULLIF((SELECT COUNT(*) FROM PEDIDOS), 0)
    AS DECIMAL(5,2))                AS [Porcentaje %]
FROM CANALES_VENTAS c
LEFT JOIN PEDIDOS p ON p.canal_id = c.canal_id
GROUP BY c.canal_id, c.nombre
ORDER BY COUNT(p.pedido_id) DESC;
GO

-- =============================================
-- SECCIÓN 6: RANGO DE FECHAS DE PEDIDOS
-- =============================================

PRINT '';
PRINT '------------------------------------------------------';
PRINT '  RANGO TEMPORAL DE LOS PEDIDOS CARGADOS';
PRINT '------------------------------------------------------';

SELECT
    MIN(fecha_pedido)               AS [Primer Pedido],
    MAX(fecha_pedido)               AS [Ultimo Pedido],
    DATEDIFF(DAY, MIN(fecha_pedido), MAX(fecha_pedido))
                                    AS [Dias de cobertura]
FROM PEDIDOS;
GO

PRINT '';
PRINT '======================================================';
PRINT '  Bundle G ejecutado correctamente.';
PRINT '  Vista disponible: dbo.vw_ResumenCargaMasiva';
PRINT '======================================================';
GO
