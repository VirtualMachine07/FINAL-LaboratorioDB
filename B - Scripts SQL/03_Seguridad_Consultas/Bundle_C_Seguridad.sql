-- =============================================
-- BUNDLE C - SEGURIDAD
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Roles de aplicación, permisos y usuarios de BD
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

USE EsbirrosDB
GO

PRINT 'INICIANDO BUNDLE C - SEGURIDAD'
PRINT '================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- PASO 1: CREAR ROLES DE APLICACIÓN
-- =============================================

PRINT 'Paso 1/3: Creando roles de seguridad...'

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_administrador')
BEGIN CREATE ROLE [rol_administrador]; PRINT 'ROLES rol_administrador creado'; END
ELSE PRINT 'ROLES rol_administrador ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_empleado')
BEGIN CREATE ROLE [rol_empleado]; PRINT 'ROLES rol_empleado creado'; END
ELSE PRINT 'ROLES rol_empleado ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_cajero')
BEGIN CREATE ROLE [rol_cajero]; PRINT 'ROLES rol_cajero creado'; END
ELSE PRINT 'ROLES rol_cajero ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_delivery')
BEGIN CREATE ROLE [rol_delivery]; PRINT 'ROLES rol_delivery creado'; END
ELSE PRINT 'ROLES rol_delivery ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_cliente')
BEGIN CREATE ROLE [rol_cliente]; PRINT 'ROLES rol_cliente creado'; END
ELSE PRINT 'ROLES rol_cliente ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_reportes')
BEGIN CREATE ROLE [rol_reportes]; PRINT 'ROLES rol_reportes creado'; END
ELSE PRINT 'ROLES rol_reportes ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_aplicacion_web')
BEGIN CREATE ROLE [rol_aplicacion_web]; PRINT 'ROLES rol_aplicacion_web creado'; END
ELSE PRINT 'ROLES rol_aplicacion_web ya existe';

-- HM-10: ROLES cocinero
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_cocinero')
BEGIN CREATE ROLE [rol_cocinero]; PRINT 'ROLES rol_cocinero creado'; END
ELSE PRINT 'ROLES rol_cocinero ya existe';

-- ROLES mozo (atención en mesas)
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'rol_mozo')
BEGIN CREATE ROLE [rol_mozo]; PRINT 'ROLES rol_mozo creado'; END
ELSE PRINT 'ROLES rol_mozo ya existe';
GO

-- =============================================
-- PASO 2: ASIGNAR PERMISOS POR ROLES
-- =============================================

PRINT 'Paso 2/3: Configurando permisos por ROLES...'

-- ROLES ADMINISTRADOR: acceso completo
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [rol_administrador];
GRANT EXECUTE ON SCHEMA::dbo TO [rol_administrador];
PRINT 'Permisos rol_administrador configurados';

-- ROLES EMPLEADOS: operaciones básicas (mozo, cocinero)
GRANT SELECT ON SCHEMA::dbo TO [rol_empleado];
GRANT EXECUTE ON dbo.sp_CrearPedido        TO [rol_empleado];
GRANT EXECUTE ON dbo.sp_AgregarItemPedido  TO [rol_empleado];
GRANT EXECUTE ON dbo.sp_CalcularTotalPedido TO [rol_empleado];
GRANT INSERT, UPDATE ON PEDIDOS         TO [rol_empleado];
GRANT INSERT, UPDATE ON DETALLES_PEDIDOS TO [rol_empleado];
PRINT 'Permisos rol_empleado configurados';

-- ROLES CAJERO: operaciones + cierre de caja
GRANT SELECT ON SCHEMA::dbo TO [rol_cajero];
GRANT EXECUTE ON dbo.sp_CrearPedido        TO [rol_cajero];
GRANT EXECUTE ON dbo.sp_AgregarItemPedido  TO [rol_cajero];
GRANT EXECUTE ON dbo.sp_CalcularTotalPedido TO [rol_cajero];
GRANT EXECUTE ON dbo.sp_CerrarPedido       TO [rol_cajero];
GRANT INSERT, UPDATE ON PEDIDOS         TO [rol_cajero];
GRANT INSERT, UPDATE ON DETALLES_PEDIDOS TO [rol_cajero];
PRINT 'Permisos rol_cajero configurados';

-- ROLES DELIVERY: lectura de pedidos + actualización de estado
GRANT SELECT ON PEDIDOS         TO [rol_delivery];
GRANT SELECT ON DETALLES_PEDIDOS TO [rol_delivery];
GRANT SELECT ON PLATOS          TO [rol_delivery];
GRANT SELECT ON CLIENTES        TO [rol_delivery];
GRANT UPDATE ON PEDIDOS         TO [rol_delivery];
PRINT 'Permisos rol_delivery configurados';

-- ROLES CLIENTES: lectura de menú y sus propios pedidos
GRANT SELECT ON PEDIDOS         TO [rol_cliente];
GRANT SELECT ON DETALLES_PEDIDOS TO [rol_cliente];
GRANT SELECT ON PLATOS          TO [rol_cliente];
GRANT SELECT ON PRECIOS         TO [rol_cliente];
PRINT 'Permisos rol_cliente configurados';

-- ROLES REPORTES: solo lectura (gerencia, BI)
GRANT SELECT ON SCHEMA::dbo TO [rol_reportes];
PRINT 'Permisos rol_reportes configurados';

-- ROLES APLICACION WEB: permisos granulares (HM-09)
GRANT SELECT ON dbo.SUCURSALES       TO [rol_aplicacion_web];
GRANT SELECT ON dbo.CANALES_VENTAS    TO [rol_aplicacion_web];
GRANT SELECT ON dbo.ESTADOS_PEDIDOS  TO [rol_aplicacion_web];
GRANT SELECT ON dbo.ROLES            TO [rol_aplicacion_web];
GRANT SELECT ON dbo.MESAS           TO [rol_aplicacion_web];
GRANT SELECT ON dbo.EMPLEADOS       TO [rol_aplicacion_web];
GRANT SELECT ON dbo.CLIENTES        TO [rol_aplicacion_web];
GRANT SELECT ON dbo.DOMICILIOS      TO [rol_aplicacion_web];
GRANT SELECT ON dbo.PLATOS          TO [rol_aplicacion_web];
GRANT SELECT ON dbo.PRECIOS         TO [rol_aplicacion_web];
GRANT SELECT, INSERT, UPDATE ON dbo.PEDIDOS          TO [rol_aplicacion_web];
GRANT SELECT, INSERT, UPDATE ON dbo.DETALLES_PEDIDOS  TO [rol_aplicacion_web];
GRANT SELECT, INSERT         ON dbo.CLIENTES         TO [rol_aplicacion_web];
GRANT SELECT, INSERT         ON dbo.DOMICILIOS       TO [rol_aplicacion_web];
GRANT EXECUTE ON SCHEMA::dbo TO [rol_aplicacion_web];
-- NOTA: Los permisos sobre NOTIFICACIONES, STOCKS_SIMULADOS, REPORTES_GENERADOS
--       y AUDITORIAS_SIMPLES se aplican al final de sus bundles respectivos
--       (Bundle_E1, Bundle_E2, Bundle_R1) donde esas tablas son creadas.
PRINT 'Permisos rol_aplicacion_web configurados (granular, HM-09)';

-- ROLES COCINERO: consulta de pedidos + marcar estado (HM-10)
GRANT SELECT ON dbo.PEDIDOS          TO [rol_cocinero];
GRANT SELECT ON dbo.DETALLES_PEDIDOS  TO [rol_cocinero];
GRANT SELECT ON dbo.PLATOS           TO [rol_cocinero];
GRANT SELECT ON dbo.ESTADOS_PEDIDOS   TO [rol_cocinero];
GRANT EXECUTE ON dbo.sp_ActualizarEstadoPedido   TO [rol_cocinero];
-- NOTA: Los permisos sobre STOCKS_SIMULADOS, NOTIFICACIONES y sus SPs
--       se aplican al final de Bundle_E2 donde esas tablas/SPs son creados.
PRINT 'Permisos rol_cocinero configurados';

-- ROLES MOZO: toma de pedidos, consulta mesas, actualización de estados
GRANT SELECT ON dbo.PEDIDOS          TO [rol_mozo];
GRANT SELECT ON dbo.DETALLES_PEDIDOS  TO [rol_mozo];
GRANT SELECT ON dbo.PLATOS           TO [rol_mozo];
GRANT SELECT ON dbo.PRECIOS          TO [rol_mozo];
GRANT SELECT ON dbo.MESAS            TO [rol_mozo];
GRANT SELECT ON dbo.CLIENTES         TO [rol_mozo];
GRANT SELECT ON dbo.ESTADOS_PEDIDOS   TO [rol_mozo];
GRANT SELECT ON dbo.CANALES_VENTAS     TO [rol_mozo];
GRANT INSERT, UPDATE ON dbo.PEDIDOS         TO [rol_mozo];
GRANT INSERT, UPDATE ON dbo.DETALLES_PEDIDOS TO [rol_mozo];
GRANT EXECUTE ON dbo.sp_CrearPedido             TO [rol_mozo];
GRANT EXECUTE ON dbo.sp_AgregarItemPedido       TO [rol_mozo];
GRANT EXECUTE ON dbo.sp_CalcularTotalPedido     TO [rol_mozo];
GRANT EXECUTE ON dbo.sp_ActualizarEstadoPedido  TO [rol_mozo];
PRINT 'Permisos rol_mozo configurados';
GO

-- =============================================
-- PASO 3: CREAR USUARIOS DE APLICACIÓN
-- =============================================

PRINT 'Paso 3/3: Creando usuarios de aplicacion...'

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'app_esbirros_web')
BEGIN
    CREATE USER [app_esbirros_web] WITHOUT LOGIN;
    ALTER ROLE [rol_aplicacion_web] ADD MEMBER [app_esbirros_web];
    PRINT 'Usuario app_esbirros_web creado y asignado a rol_aplicacion_web';
END
ELSE PRINT 'Usuario app_esbirros_web ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'app_esbirros_reportes')
BEGIN
    CREATE USER [app_esbirros_reportes] WITHOUT LOGIN;
    ALTER ROLE [rol_reportes] ADD MEMBER [app_esbirros_reportes];
    PRINT 'Usuario app_esbirros_reportes creado y asignado a rol_reportes';
END
ELSE PRINT 'Usuario app_esbirros_reportes ya existe';

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'app_esbirros_delivery')
BEGIN
    CREATE USER [app_esbirros_delivery] WITHOUT LOGIN;
    ALTER ROLE [rol_delivery] ADD MEMBER [app_esbirros_delivery];
    PRINT 'Usuario app_esbirros_delivery creado y asignado a rol_delivery';
END
ELSE PRINT 'Usuario app_esbirros_delivery ya existe';
GO

-- =============================================
-- FUNCIÓN: VALIDAR PERMISO DE USUARIO
-- =============================================

IF OBJECT_ID('fn_ValidarPermisoUsuario', 'FN') IS NOT NULL
    DROP FUNCTION fn_ValidarPermisoUsuario
GO

CREATE FUNCTION fn_ValidarPermisoUsuario(
    @usuario NVARCHAR(128),
    @objeto  NVARCHAR(128),
    @permiso NVARCHAR(128)
)
RETURNS BIT
AS
BEGIN
    DECLARE @tiene_permiso BIT = 0

    IF EXISTS (
        SELECT 1
        FROM sys.database_permissions dp
        INNER JOIN sys.objects o            ON dp.major_id             = o.object_id
        INNER JOIN sys.database_principals p ON dp.grantee_principal_id = p.principal_id
        WHERE p.name             = @usuario
          AND o.name             = @objeto
          AND dp.permission_name = @permiso
          AND dp.state           = 'G'
    )
        SET @tiene_permiso = 1

    RETURN @tiene_permiso
END
GO

-- =============================================
-- SP: AUDITORÍA DE SEGURIDAD
-- =============================================

IF OBJECT_ID('sp_AuditoriaSeguridad', 'P') IS NOT NULL
    DROP PROCEDURE sp_AuditoriaSeguridad
GO

CREATE PROCEDURE sp_AuditoriaSeguridad
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'AUDITORIA DE SEGURIDAD - ESBIRROSDB'
    PRINT '====================================='
    PRINT ''

    PRINT 'ROLES DE BASE DE DATOS:'
    SELECT
        name        AS [ROLES],
        create_date AS [Fecha Creacion],
        type_desc   AS [Tipo]
    FROM sys.database_principals
    WHERE type = 'R' AND name LIKE 'rol_%'
    ORDER BY name

    PRINT ''

    PRINT 'USUARIOS DE APLICACION:'
    SELECT
        u.name        AS [Usuario],
        r.name        AS [ROLES Asignado],
        u.create_date AS [Fecha Creacion]
    FROM sys.database_principals u
    INNER JOIN sys.database_role_members rm ON u.principal_id        = rm.member_principal_id
    INNER JOIN sys.database_principals r   ON rm.role_principal_id  = r.principal_id
    WHERE u.name LIKE 'app_%'
    ORDER BY u.name, r.name

    PRINT ''
    PRINT 'Auditoria completada'
END
GO

-- =============================================
-- VALIDACIÓN FINAL
-- =============================================

PRINT ''
PRINT 'Ejecutando auditoria de seguridad...'
EXEC sp_AuditoriaSeguridad

DECLARE @roles_count    INT = (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND name LIKE 'rol_%')
DECLARE @usuarios_count INT = (SELECT COUNT(*) FROM sys.database_principals WHERE name LIKE 'app_%')
DECLARE @permisos_count INT = (SELECT COUNT(*) FROM sys.database_permissions
                                WHERE grantee_principal_id IN
                                    (SELECT principal_id FROM sys.database_principals WHERE name LIKE 'rol_%'))

PRINT ''
PRINT 'Roles creados    : ' + CAST(@roles_count    AS VARCHAR)
PRINT 'Usuarios creados : ' + CAST(@usuarios_count AS VARCHAR)
PRINT 'Permisos asignados: ' + CAST(@permisos_count AS VARCHAR)

PRINT ''
PRINT 'BUNDLE C COMPLETADO!'
PRINT '================================================='
PRINT 'Roles   : 8 roles de aplicacion'
PRINT 'Usuarios: 3 usuarios sin login (app_esbirros_*)'
PRINT 'Funcion : fn_ValidarPermisoUsuario'
PRINT 'SP      : sp_AuditoriaSeguridad'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_D_Consultas_Basicas.sql'
PRINT '================================================='
GO

