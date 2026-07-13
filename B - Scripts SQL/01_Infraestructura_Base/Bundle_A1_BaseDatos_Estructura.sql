-- =============================================
-- BUNDLE A1 - BASE DE DATOS Y ESTRUCTURA
-- EsbirrosDB - Sistema de Gestión de Bodegón Porteño
-- Negocio: Bodegón Los Esbirros de Claudio
-- Descripción: Creación de base de datos y estructura de tablas
-- Proyecto Educativo ISTEA - Uso académico exclusivo
-- PROHIBIDA LA COMERCIALIZACIÓN
-- =============================================

PRINT ' INICIANDO BUNDLE A1 - BASE DE DATOS Y ESTRUCTURA'
PRINT '=================================================='
PRINT 'Sistema: EsbirrosDB - Bodegon Los Esbirros de Claudio'
PRINT ''

-- =============================================
-- PASO 1: CREAR BASE DE DATOS
-- =============================================

PRINT 'Paso 1/2: Creando base de datos EsbirrosDB...'

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'EsbirrosDB')
BEGIN
    CREATE DATABASE EsbirrosDB
    PRINT 'Base de datos EsbirrosDB creada exitosamente'
END
ELSE
BEGIN
    PRINT 'Base de datos EsbirrosDB ya existe'
END
GO

USE EsbirrosDB
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- PASO 2: CREAR TABLAS
-- =============================================

PRINT 'Paso 2/2: Creando estructura de tablas...'

-- ─────────────────────────────────────────────
-- MÓDULO 1: CATÁLOGOS BASE
-- ─────────────────────────────────────────────

CREATE TABLE SUCURSALES (
    sucursal_id INT           IDENTITY(1,1) PRIMARY KEY,
    nombre      NVARCHAR(100) NOT NULL,
    direccion   NVARCHAR(255) NOT NULL,
    CONSTRAINT UK_SUCURSAL_nombre UNIQUE (nombre)
)
GO

CREATE TABLE CANALES_VENTAS (
    canal_id INT          IDENTITY(1,1) PRIMARY KEY,
    nombre   NVARCHAR(50) NOT NULL,
    CONSTRAINT UK_CANAL_VENTA_nombre UNIQUE (nombre)
)
GO

CREATE TABLE ESTADOS_PEDIDOS (
    estado_id INT          IDENTITY(1,1) PRIMARY KEY,
    nombre    NVARCHAR(50) NOT NULL,
    orden     INT          NOT NULL,
    CONSTRAINT UK_ESTADO_PEDIDO_nombre UNIQUE (nombre),
    CONSTRAINT UK_ESTADO_PEDIDO_orden  UNIQUE (orden)
)
GO

CREATE TABLE ROLES (
    rol_id      INT           IDENTITY(1,1) PRIMARY KEY,
    nombre      NVARCHAR(50)  NOT NULL,
    descripcion NVARCHAR(255) NULL,
    CONSTRAINT UK_ROL_nombre UNIQUE (nombre)
)
GO

-- ─────────────────────────────────────────────
-- MÓDULO 2: PERSONAL Y UBICACIÓN
-- ─────────────────────────────────────────────

CREATE TABLE MESAS (
    mesa_id     INT           IDENTITY(1,1) PRIMARY KEY,
    numero      INT           NOT NULL,
    capacidad   INT           NOT NULL CHECK (capacidad > 0),
    sucursal_id INT           NOT NULL,
    qr_token    NVARCHAR(255) NOT NULL,
    activa      BIT           NOT NULL DEFAULT 1,
    CONSTRAINT FK_MESA_sucursal        FOREIGN KEY (sucursal_id) REFERENCES SUCURSALES(sucursal_id),
    CONSTRAINT UK_MESA_numero_sucursal UNIQUE (numero, sucursal_id),
    CONSTRAINT UK_MESA_qr_token        UNIQUE (qr_token)
)
GO

CREATE TABLE EMPLEADOS (
    empleado_id   INT           IDENTITY(1,1) PRIMARY KEY,
    nombre        NVARCHAR(100) NOT NULL,
    usuario       NVARCHAR(50)  NOT NULL,
    hash_password NVARCHAR(255) NOT NULL,
    rol_id        INT           NOT NULL,
    sucursal_id   INT           NOT NULL,
    activo        BIT           NOT NULL DEFAULT 1,
    CONSTRAINT FK_EMPLEADO_rol      FOREIGN KEY (rol_id)      REFERENCES ROLES(rol_id),
    CONSTRAINT FK_EMPLEADO_sucursal FOREIGN KEY (sucursal_id) REFERENCES SUCURSALES(sucursal_id),
    CONSTRAINT UK_EMPLEADO_usuario  UNIQUE (usuario)
)
GO

-- ─────────────────────────────────────────────
-- MÓDULO 3: CLIENTES Y DOMICILIOS
-- ─────────────────────────────────────────────

CREATE TABLE CLIENTES (
    cliente_id INT           IDENTITY(1,1) PRIMARY KEY,
    nombre     NVARCHAR(100) NOT NULL,
    telefono   NVARCHAR(20)  NULL,
    email      NVARCHAR(100) NULL,
    doc_tipo   NVARCHAR(10)  NULL,
    doc_nro    NVARCHAR(20)  NULL
    -- Unicidad de email y documento se garantiza mediante índices filtrados en Bundle_A2
    -- (UNIQUE constraint no admite múltiples NULLs correctamente en SQL Server)
)
GO

CREATE TABLE DOMICILIOS (
    domicilio_id  INT           IDENTITY(1,1) PRIMARY KEY,
    cliente_id    INT           NOT NULL,
    calle         NVARCHAR(100) NOT NULL,
    numero        NVARCHAR(10)  NOT NULL,
    piso          NVARCHAR(10)  NULL,
    depto         NVARCHAR(10)  NULL,
    localidad     NVARCHAR(50)  NOT NULL,
    provincia     NVARCHAR(50)  NOT NULL,
    observaciones NVARCHAR(255) NULL,
    es_principal  BIT           NOT NULL DEFAULT 0,
    tipo_domicilio NVARCHAR(50) NULL DEFAULT 'Particular',
    CONSTRAINT FK_DOMICILIO_cliente FOREIGN KEY (cliente_id) REFERENCES CLIENTES(cliente_id),
    CONSTRAINT CK_DOMICILIO_tipo CHECK (tipo_domicilio IN ('Particular', 'Laboral', 'Temporal', 'Otro'))
)
GO

-- ─────────────────────────────────────────────
-- MÓDULO 4: PRODUCTOS Y PRECIOS
-- Nota: tabla PLATOS se conserva para compatibilidad.
-- En el bodegón representa cualquier ítem del menú
-- (entradas, pastas, carnes a la leña, postres, bebidas).
-- COMBO y PROMOCION fueron eliminados de este módulo.
-- ─────────────────────────────────────────────

CREATE TABLE PLATOS (
    plato_id  INT           IDENTITY(1,1) PRIMARY KEY,
    nombre    NVARCHAR(100) NOT NULL,
    categoria NVARCHAR(50)  NOT NULL,
    activo    BIT           NOT NULL DEFAULT 1,
    CONSTRAINT UK_PLATO_nombre UNIQUE (nombre)
)
GO

CREATE TABLE PRECIOS (
    precio_id      INT           IDENTITY(1,1) PRIMARY KEY,
    plato_id       INT           NOT NULL,
    vigencia_desde DATE          NOT NULL,
    vigencia_hasta DATE          NULL,
    monto          DECIMAL(10,2) NOT NULL CHECK (monto >= 0),
    CONSTRAINT FK_PRECIO_plato    FOREIGN KEY (plato_id) REFERENCES PLATOS(plato_id),
    CONSTRAINT CK_PRECIO_vigencia CHECK (vigencia_hasta IS NULL OR vigencia_hasta >= vigencia_desde)
)
GO

-- ─────────────────────────────────────────────
-- MÓDULO 5: PEDIDOS
-- DETALLES_PEDIDOS simplificado:
--   · plato_id NOT NULL (siempre obligatorio)
--   · Sin combo_id (tabla COMBO eliminada)
--   · Sin promocion_id (tabla PROMOCION eliminada)
--   · Sin constraint XOR (ya no aplica)
-- ─────────────────────────────────────────────

CREATE TABLE PEDIDOS (
    pedido_id                 INT           IDENTITY(1,1) PRIMARY KEY,
    fecha_pedido              DATETIME      NOT NULL DEFAULT GETDATE(),
    fecha_entrega             DATETIME      NULL,
    canal_id                  INT           NOT NULL,
    mesa_id                   INT           NULL,
    cliente_id                INT           NULL,
    domicilio_id              INT           NULL,
    cant_comensales           INT           NULL,
    estado_id                 INT           NOT NULL,
    tomado_por_empleado_id    INT           NOT NULL,
    entregado_por_empleado_id INT           NULL,
    total                     DECIMAL(10,2) NOT NULL DEFAULT 0,
    observaciones             NVARCHAR(500) NULL,
    CONSTRAINT FK_PEDIDO_canal         FOREIGN KEY (canal_id)                  REFERENCES CANALES_VENTAS(canal_id),
    CONSTRAINT FK_PEDIDO_mesa          FOREIGN KEY (mesa_id)                   REFERENCES MESAS(mesa_id),
    CONSTRAINT FK_PEDIDO_cliente       FOREIGN KEY (cliente_id)                REFERENCES CLIENTES(cliente_id),
    CONSTRAINT FK_PEDIDO_domicilio     FOREIGN KEY (domicilio_id)              REFERENCES DOMICILIOS(domicilio_id),
    CONSTRAINT FK_PEDIDO_estado        FOREIGN KEY (estado_id)                 REFERENCES ESTADOS_PEDIDOS(estado_id),
    CONSTRAINT FK_PEDIDO_tomado_por    FOREIGN KEY (tomado_por_empleado_id)    REFERENCES EMPLEADOS(empleado_id),
    CONSTRAINT FK_PEDIDO_entregado_por FOREIGN KEY (entregado_por_empleado_id) REFERENCES EMPLEADOS(empleado_id)
)
GO

CREATE TABLE DETALLES_PEDIDOS (
    detalle_id      INT           IDENTITY(1,1) PRIMARY KEY,
    pedido_id       INT           NOT NULL,
    plato_id        INT           NOT NULL,
    cantidad        INT           NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal        DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT FK_DETALLE_PEDIDO_pedido FOREIGN KEY (pedido_id) REFERENCES PEDIDOS(pedido_id),
    CONSTRAINT FK_DETALLE_PEDIDO_plato  FOREIGN KEY (plato_id)  REFERENCES PLATOS(plato_id)
)
GO

-- ─────────────────────────────────────────────
-- MÓDULO 6: AUDITORÍA
-- ─────────────────────────────────────────────
-- NOTA: La tabla AUDITORIA fue eliminada (v2.0).
-- La auditoría del sistema se maneja con AUDITORIAS_SIMPLES,
-- creada automáticamente por tr_AuditoriaPedidos en Bundle E1.
-- ─────────────────────────────────────────────

-- =============================================
-- VALIDACIÓN FINAL
-- =============================================

PRINT ''
PRINT 'RESUMEN BUNDLE A1:'
PRINT '   Base de datos : EsbirrosDB'
PRINT '   Negocio       : Bodegon Los Esbirros de Claudio'
PRINT '   Tablas creadas: 12'
PRINT '   FK configuradas: 14'
PRINT '   Eliminadas    : COMBO, COMBO_DETALLE, PROMOCION, PROMOCION_PLATO, AUDITORIA'
PRINT ''
PRINT 'SIGUIENTE PASO: Ejecutar Bundle_A2_Indices_Datos.sql'
PRINT '=================================================='
GO
