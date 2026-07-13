-- =============================================
-- BUNDLE H - BULK INSERT: CLIENTES + DOMICILIOS
-- EsbirrosDB - Sistema de Gestion de Bodegon Porteno
-- Negocio: Bodegon Los Esbirros de Claudio
-- Version: 2.0
-- Descripcion: Carga masiva desde un CSV unico desnormalizado
--              usando tabla staging para normalizar y resolver
--              el problema de FK con IDENTITY (cliente_id).
--
-- PREREQUISITO: ejecutar antes
--   python genera_csv_clientes_domicilios.py
--   -> genera C:\SQLData\clientes_domicilios.csv
--
-- Proyecto Educativo ISTEA - Uso academico exclusivo
-- =============================================

USE EsbirrosDB;
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

PRINT '======================================================='
PRINT 'BUNDLE H - BULK INSERT CLIENTES + DOMICILIOS v2.0'
PRINT '======================================================='
PRINT 'Inicio: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT ''

-- =============================================
-- PRE-VALIDACION: verificar que el CSV existe
-- =============================================

DECLARE @existe INT
EXEC master.dbo.xp_fileexist 'C:\SQLData\clientes_domicilios.csv', @existe OUTPUT

IF @existe = 0
BEGIN
    DECLARE @msg_err NVARCHAR(500)
    SET @msg_err = 'ERROR: No se encuentra C:\SQLData\clientes_domicilios.csv - Ejecutar primero: python genera_csv_clientes_domicilios.py'
    RAISERROR(@msg_err, 16, 1)
    RETURN
END

PRINT 'Archivo CSV verificado - OK'
PRINT ''

-- =============================================
-- PASO 1: TABLA STAGING TEMPORAL
-- Recibe el CSV tal cual: una fila por domicilio,
-- con los datos del cliente repetidos en cada fila.
-- No tiene IDENTITY ni FK, acepta todo como texto.
-- =============================================

PRINT '1. Creando tabla staging...'

CREATE TABLE #STAGING (
    -- Datos del cliente (se repiten por cada domicilio)
    doc_nro        NVARCHAR(20)  NOT NULL,   -- clave natural de enlace
    nombre         NVARCHAR(100) NOT NULL,
    telefono       NVARCHAR(20)  NULL,
    email          NVARCHAR(100) NULL,
    doc_tipo       NVARCHAR(10)  NULL,
    -- Datos del domicilio
    calle          NVARCHAR(100) NOT NULL,
    numero         NVARCHAR(10)  NOT NULL,
    piso           NVARCHAR(10)  NULL,
    depto          NVARCHAR(10)  NULL,
    localidad      NVARCHAR(50)  NOT NULL,
    provincia      NVARCHAR(50)  NOT NULL,
    es_principal   TINYINT       NOT NULL,   -- 0 o 1 (BIT no acepta BULK INSERT directo)
    tipo_domicilio NVARCHAR(50)  NULL,
    observaciones  NVARCHAR(255) NULL
)

PRINT '   Staging creado - OK'
PRINT ''

-- =============================================
-- PASO 2: BULK INSERT -> STAGING
-- Carga el CSV completo (1 fila por domicilio)
-- =============================================

PRINT '2. BULK INSERT en staging...'

BULK INSERT #STAGING
FROM 'C:\SQLData\clientes_domicilios.csv'
WITH (
    FIELDTERMINATOR = ',',       -- separador de columnas
    ROWTERMINATOR   = '0x0a',   -- LF (funciona en Windows y Linux)
    FIRSTROW        = 2,         -- saltear encabezado
    TABLOCK,                     -- bloqueo tabla = mayor velocidad
    MAXERRORS       = 10,        -- tolerar hasta 10 errores antes de abortar
    ERRORFILE       = 'C:\SQLData\errores_bulkinsert.log'
)

DECLARE @total_staging INT = (SELECT COUNT(*) FROM #STAGING)
PRINT '   Filas cargadas en staging: ' + CAST(@total_staging AS VARCHAR) + ' - OK'
PRINT ''

-- =============================================
-- PASO 3: INSERT INTO CLIENTES
-- Se insertan solo los clientes DISTINTOS por doc_nro
-- que NO existan ya en la tabla (evita duplicados).
-- SQL Server genera el cliente_id automaticamente (IDENTITY).
-- =============================================

PRINT '3. Insertando CLIENTES (distintos, solo nuevos)...'

-- Cuantos del CSV ya existen en la BD por doc_nro
DECLARE @ya_existen INT = (
    SELECT COUNT(DISTINCT LTRIM(RTRIM(s.doc_nro)))
    FROM #STAGING s
    WHERE EXISTS (
        SELECT 1 FROM CLIENTES c
        WHERE c.doc_nro = LTRIM(RTRIM(s.doc_nro))
    )
)
IF @ya_existen > 0
    PRINT '   AVISO: ' + CAST(@ya_existen AS VARCHAR) + ' clientes del CSV ya existen en la BD (se omiten)'

DECLARE @antes_c INT = (SELECT COUNT(*) FROM CLIENTES)

INSERT INTO CLIENTES (nombre, telefono, email, doc_tipo, doc_nro)
SELECT
    MIN(LTRIM(RTRIM(s.nombre))),                     -- primera fila del grupo
    NULLIF(MIN(LTRIM(RTRIM(s.telefono))), ''),
    NULLIF(MIN(LTRIM(RTRIM(s.email))),    ''),
    NULLIF(MIN(LTRIM(RTRIM(s.doc_tipo))), ''),
    LTRIM(RTRIM(s.doc_nro))
FROM #STAGING s
WHERE NOT EXISTS (                                   -- omitir si el DNI ya esta en CLIENTES
    SELECT 1 FROM CLIENTES c
    WHERE c.doc_nro = LTRIM(RTRIM(s.doc_nro))
)
GROUP BY LTRIM(RTRIM(s.doc_nro))                     -- un registro por DNI unico

DECLARE @insertados_c INT = (SELECT COUNT(*) FROM CLIENTES) - @antes_c
PRINT '   Clientes insertados: ' + CAST(@insertados_c AS VARCHAR) + ' - OK'
PRINT ''

-- =============================================
-- PASO 4: INSERT INTO DOMICILIOS
-- Se resuelve cliente_id haciendo JOIN entre staging
-- y la tabla CLIENTES por doc_nro (clave natural).
-- Solo se insertan domicilios de clientes que NO tenian
-- domicilios previos (evita duplicar si el script se vuelve a correr).
-- =============================================

PRINT '4. Insertando DOMICILIOS (resolviendo FK por doc_nro)...'

INSERT INTO DOMICILIOS (
    cliente_id,
    calle, numero, piso, depto,
    localidad, provincia,
    es_principal, tipo_domicilio, observaciones
)
SELECT
    c.cliente_id,                                              -- ID real resuelto por JOIN
    s.calle,
    s.numero,
    NULLIF(LTRIM(RTRIM(s.piso)),           ''),
    NULLIF(LTRIM(RTRIM(s.depto)),          ''),
    s.localidad,
    s.provincia,
    CAST(s.es_principal AS BIT),
    ISNULL(NULLIF(LTRIM(RTRIM(s.tipo_domicilio)), ''), 'Particular'),
    NULLIF(LTRIM(RTRIM(s.observaciones)),  '')
FROM #STAGING s
INNER JOIN CLIENTES c
    ON c.doc_nro = LTRIM(RTRIM(s.doc_nro))                    -- enlace por DNI
WHERE NOT EXISTS (                                             -- omitir si ya tiene domicilios cargados
    SELECT 1 FROM DOMICILIOS d
    WHERE d.cliente_id = c.cliente_id
)

DECLARE @insertados_d INT = @@ROWCOUNT
PRINT '   Domicilios insertados: ' + CAST(@insertados_d AS VARCHAR) + ' - OK'
PRINT ''

-- =============================================
-- LIMPIEZA
-- =============================================

DROP TABLE #STAGING
PRINT '   Staging eliminado - OK'
PRINT ''

-- =============================================
-- VALIDACION FINAL
-- =============================================

DECLARE @total_c   INT = (SELECT COUNT(*) FROM CLIENTES  WHERE cliente_id > 19)
DECLARE @total_d   INT = (SELECT COUNT(*) FROM DOMICILIOS)
DECLARE @sin_dom   INT = (
    SELECT COUNT(*) FROM CLIENTES c
    WHERE  c.cliente_id > 19
    AND    NOT EXISTS (SELECT 1 FROM DOMICILIOS d WHERE d.cliente_id = c.cliente_id)
)
DECLARE @con_uno   INT = (
    SELECT COUNT(*) FROM CLIENTES c
    WHERE  c.cliente_id > 19
    AND    (SELECT COUNT(*) FROM DOMICILIOS d WHERE d.cliente_id = c.cliente_id) = 1
)
DECLARE @con_mas   INT = (
    SELECT COUNT(*) FROM CLIENTES c
    WHERE  c.cliente_id > 19
    AND    (SELECT COUNT(*) FROM DOMICILIOS d WHERE d.cliente_id = c.cliente_id) > 1
)

PRINT '======================================================='
PRINT 'VALIDACION FINAL:'
PRINT '----------------------------------------------------'
PRINT 'Clientes nuevos cargados  : ' + CAST(@total_c  AS VARCHAR)
PRINT 'Domicilios cargados       : ' + CAST(@total_d  AS VARCHAR)
PRINT 'Clientes sin domicilio    : ' + CAST(@sin_dom  AS VARCHAR) + '  (debe ser 0)'
PRINT 'Clientes con 1 domicilio  : ' + CAST(@con_uno  AS VARCHAR) + '  (~80%)'
PRINT 'Clientes con 2+ domicilios: ' + CAST(@con_mas  AS VARCHAR) + '  (~20%)'
PRINT ''

-- Muestra los ultimos 5 clientes con todos sus domicilios
SELECT TOP 10
    c.cliente_id,
    c.nombre,
    c.doc_nro,
    d.es_principal,
    d.calle + ' ' + d.numero AS direccion,
    d.localidad,
    d.tipo_domicilio
FROM CLIENTES c
INNER JOIN DOMICILIOS d ON c.cliente_id = d.cliente_id
WHERE c.cliente_id > 19
ORDER BY c.cliente_id DESC, d.es_principal DESC

-- Distribucion de domicilios por cliente
PRINT ''
PRINT 'Distribucion de domicilios por cliente:'
SELECT
    cant_dom                        AS domicilios_por_cliente,
    COUNT(*)                        AS cantidad_clientes,
    CAST(COUNT(*) * 100.0 /
         SUM(COUNT(*)) OVER()
    AS DECIMAL(5,1))                AS porcentaje
FROM (
    SELECT c.cliente_id, COUNT(d.domicilio_id) AS cant_dom
    FROM CLIENTES c
    LEFT JOIN DOMICILIOS d ON c.cliente_id = d.cliente_id
    WHERE c.cliente_id > 19
    GROUP BY c.cliente_id
) sub
GROUP BY cant_dom
ORDER BY cant_dom

PRINT ''
PRINT 'Fin: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT '======================================================='
PRINT 'BUNDLE H COMPLETADO EXITOSAMENTE'
PRINT '======================================================='
GO
