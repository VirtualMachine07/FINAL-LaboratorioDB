# DICCIONARIO DE DATOS E ÍNDICES — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**            | **Descripción**                                     |
|----------------------|-----------------------------------------------------|
| **Documento**        | Diccionario de Datos e Índices — EsbirrosDB         |
| **Proyecto**         | Sistema de Gestión de Pedidos — Bodegón Porteño     |
| **Cliente**          | Bodegón Los Esbirros de Claudio                     |
| **Desarrollado por** | SQLeaders S.A.                                      |
| **Versión**          | 1.0                                                 |
| **Fecha**            | Abril 2026                                          |
| **Instituto**        | ISTEA                                               |
| **Materia**          | Laboratorio de Administración de Bases de Datos     |
| **Profesor**         | Carlos Alejandro Caraccio                           |
| **Estado**           | Implementado y Funcional                            |

---

## RESUMEN DEL MODELO

| **Métrica**                | **Valor** | **Descripción**                               |
|----------------------------|-----------|-----------------------------------------------|
| **Tablas (Bundle A1)**     | 12        | Entidades principales del sistema             |
| **Tablas auxiliares**      | 4         | Creadas automáticamente por Bundles E1/E2/R1  |
| **Total tablas**           | **16**    |                                               |
| **Claves Primarias**       | 16        | Una por tabla                                 |
| **Claves Foráneas**        | 17        | Referencias entre tablas                      |
| **Índices non-clustered**  | 14        | 11 definidos en Bundle A2 + 3 en Bundle R1    |
| **Triggers**               | 5         | Auditoría, totales, stock, notificaciones      |
| **Stored Procedures**      | 18        | Operacionales, consultas, reportes, control   |

---

## PARTE 1 — TABLAS PRINCIPALES (Bundle A1)

---

### 1. SUCURSALES
**Propósito:** Almacena las sucursales del bodegón. El sistema está diseñado para escalar a múltiples sucursales.

| **Campo**    | **Tipo**       | **Nulo** | **Clave** | **Default**   | **Descripción**                   |
|--------------|----------------|----------|-----------|---------------|-----------------------------------|
| sucursal_id  | INT            | NO       | PK        | IDENTITY(1,1) | Identificador único               |
| nombre       | NVARCHAR(100)  | NO       | UK        | —             | Nombre comercial (único)          |
| direccion    | NVARCHAR(255)  | NO       | —         | —             | Dirección física                  |

---

### 2. CANALES_VENTAS
**Propósito:** Catálogo de canales por los que llegan los pedidos.

| **Campo** | **Tipo**      | **Nulo** | **Clave** | **Default**   | **Descripción**          |
|-----------|---------------|----------|-----------|---------------|--------------------------|
| canal_id  | INT           | NO       | PK        | IDENTITY(1,1) | Identificador del canal  |
| nombre    | NVARCHAR(50)  | NO       | UK        | —             | Nombre del canal         |

**Valores iniciales:** Mostrador · Delivery · MESAS QR · Telefono

---

### 3. ESTADOS_PEDIDOS
**Propósito:** Catálogo de estados del flujo operativo de pedidos con su orden secuencial.

| **Campo**  | **Tipo**      | **Nulo** | **Clave** | **Default**   | **Descripción**                     |
|------------|---------------|----------|-----------|---------------|-------------------------------------|
| estado_id  | INT           | NO       | PK        | IDENTITY(1,1) | Identificador del estado            |
| nombre     | NVARCHAR(50)  | NO       | UK        | —             | Nombre del estado                   |
| orden      | INT           | NO       | UK        | —             | Orden secuencial del flujo          |

**Flujo de estados:**
```
Pendiente(1) → Confirmado(2) → En Preparación(3) → Listo(4) → En Reparto(5) → Entregado(6) → Cerrado(7)
Cancelado(99) — aplica desde cualquier estado activo
```

---

### 4. ROLES
**Propósito:** Roles del personal del bodegón para control de acceso.

| **Campo**   | **Tipo**      | **Nulo** | **Clave** | **Default**   | **Descripción**           |
|-------------|---------------|----------|-----------|---------------|---------------------------|
| rol_id      | INT           | NO       | PK        | IDENTITY(1,1) | Identificador del rol     |
| nombre      | NVARCHAR(50)  | NO       | UK        | —             | Nombre del rol (único)    |
| descripcion | NVARCHAR(255) | SÍ       | —         | —             | Descripción del rol       |

**Valores iniciales:** Administrador · Gerente · Mozo · Cajero · Cocinero · Repartidor · !!!! Hostess !!!!

---

### 5. MESAS
**Propósito:** Mesas físicas del salón con soporte para escaneo de código QR.

| **Campo**   | **Tipo**      | **Nulo** | **Clave**  | **Default**   | **Descripción**                        |
|-------------|---------------|----------|------------|---------------|----------------------------------------|
| mesa_id     | INT           | NO       | PK         | IDENTITY(1,1) | Identificador único                    |
| numero      | INT           | NO       | UK(comp.)  | —             | Número de mesa (único por sucursal)    |
| capacidad   | INT           | NO       | —          | —             | Máximo de comensales (`CHECK > 0`)     |
| sucursal_id | INT           | NO       | FK         | —             | Sucursal a la que pertenece            |
| qr_token    | NVARCHAR(255) | NO       | UK         | —             | Token único del código QR              |
| activa      | BIT           | NO       | —          | 1             | Si la mesa está habilitada             |

**Constraints:** `CHECK capacidad > 0` · `UNIQUE (numero, sucursal_id)`

---

### 6. EMPLEADOS
**Propósito:** Personal del bodegón con autenticación y rol asignado.

| **Campo**      | **Tipo**      | **Nulo** | **Clave** | **Default**   | **Descripción**                |
|----------------|---------------|----------|-----------|---------------|--------------------------------|
| empleado_id    | INT           | NO       | PK        | IDENTITY(1,1) | Identificador único            |
| nombre         | NVARCHAR(100) | NO       | —         | —             | Nombre completo                |
| usuario        | NVARCHAR(50)  | NO       | UK        | —             | Usuario de sistema (único)     |
| hash_password  | NVARCHAR(255) | NO       | —         | —             | Contraseña hasheada            |
| rol_id         | INT           | NO       | FK        | —             | Rol asignado                   |
| sucursal_id    | INT           | NO       | FK        | —             | Sucursal de pertenencia        |
| activo         | BIT           | NO       | —         | 1             | Si el empleado está activo     |

---

### 7. CLIENTES
**Propósito:** Clientes registrados para delivery e historial de pedidos.

| **Campo**  | **Tipo**      | **Nulo** | **Clave** | **Default**   | **Descripción**                                              |
|------------|---------------|----------|-----------|---------------|--------------------------------------------------------------|
| cliente_id | INT           | NO       | PK        | IDENTITY(1,1) | Identificador único                                          |
| nombre     | NVARCHAR(100) | NO       | —         | —             | Nombre completo (obligatorio)                                |
| telefono   | NVARCHAR(20)  | SÍ       | —         | —             | Teléfono de contacto (opcional)                             |
| email      | NVARCHAR(100) | SÍ       | UIX       | —             | Email único cuando se registra (`WHERE email IS NOT NULL`)   |
| doc_tipo   | NVARCHAR(10)  | SÍ       | UIX(comp.)| —             | Tipo de documento (DNI, CUIL, etc.)                          |
| doc_nro    | NVARCHAR(20)  | SÍ       | UIX(comp.)| —             | Número de documento                                          |

> **Nota de diseño:** Se usan índices filtrados (UIX) en lugar de UNIQUE constraints convencionales porque SQL Server no permite múltiples valores NULL en columnas con UNIQUE estándar.

---

### 8. DOMICILIOS
**Propósito:** Direcciones de entrega vinculadas a clientes para pedidos delivery.

| **Campo**      | **Tipo**      | **Nulo** | **Clave**  | **Default**   | **Descripción**                            |
|----------------|---------------|----------|------------|---------------|--------------------------------------------|
| domicilio_id   | INT           | NO       | PK         | IDENTITY(1,1) | Identificador único                        |
| cliente_id     | INT           | NO       | FK         | —             | Cliente propietario                        |
| calle          | NVARCHAR(100) | NO       | —          | —             | Nombre de la calle                         |
| numero         | NVARCHAR(10)  | NO       | —          | —             | Número de puerta                           |
| piso           | NVARCHAR(10)  | SÍ       | —          | —             | Piso (opcional)                            |
| depto          | NVARCHAR(10)  | SÍ       | —          | —             | Departamento (opcional)                    |
| localidad      | NVARCHAR(50)  | NO       | —          | —             | Localidad                                  |
| provincia      | NVARCHAR(50)  | NO       | —          | —             | Provincia                                  |
| observaciones  | NVARCHAR(255) | SÍ       | —          | —             | Notas de entrega (timbre, acceso, etc.)    |
| es_principal   | BIT           | NO       | UIX        | 0             | Domicilio principal (solo uno por cliente) |
| tipo_domicilio | NVARCHAR(50)  | SÍ       | —          | 'Particular'  | Tipo de domicilio                          |

**Constraints:** `CHECK tipo_domicilio IN ('Particular', 'Laboral', 'Temporal', 'Otro')`  
**Índice filtrado:** `UIX_DOMICILIO_principal` — garantiza máximo un domicilio principal por cliente (`WHERE es_principal = 1`)

---

### 9. PLATOS
**Propósito:** Catálogo de ítems del menú (entradas, pastas, carnes, bebidas, postres).

| **Campo** | **Tipo**      | **Nulo** | **Clave** | **Default**   | **Descripción**                        |
|-----------|---------------|----------|-----------|---------------|----------------------------------------|
| plato_id  | INT           | NO       | PK        | IDENTITY(1,1) | Identificador único                    |
| nombre    | NVARCHAR(100) | NO       | UK        | —             | Nombre del plato (único en el menú)    |
| categoria | NVARCHAR(50)  | NO       | —         | —             | Categoría del menú                     |
| activo    | BIT           | NO       | —         | 1             | Si el plato está disponible            |

**Categorías:** Entradas · Pastas · Carnes a la Leña · Guarniciones · Postres · Bebidas

---

### 10. PRECIOS
**Propósito:** Historial de precios con vigencia temporal por plato. Los precios nunca se modifican: cada cambio genera un nuevo registro.

| **Campo**      | **Tipo**       | **Nulo** | **Clave** | **Default**   | **Descripción**                              |
|----------------|----------------|----------|-----------|---------------|----------------------------------------------|
| precio_id      | INT            | NO       | PK        | IDENTITY(1,1) | Identificador único del registro             |
| plato_id       | INT            | NO       | FK        | —             | Plato al que aplica                          |
| vigencia_desde | DATE           | NO       | —         | —             | Fecha de inicio de vigencia                  |
| vigencia_hasta | DATE           | SÍ       | —         | —             | Fecha de fin (NULL = vigente indefinidamente)|
| monto          | DECIMAL(10,2)  | NO       | —         | —             | Precio en pesos (≥ 0)                        |

**Constraints:** `CHECK monto >= 0` · `CHECK vigencia_hasta >= vigencia_desde`

> **Regla de negocio RN-004.6:** Al cambiar el precio de un plato, se cierra la vigencia del registro anterior y se inserta uno nuevo. Nunca se actualiza el precio original, garantizando trazabilidad financiera completa.

---

### 11. PEDIDOS
**Propósito:** Entidad central del sistema. Registra cada transacción del bodegón.

| **Campo**                   | **Tipo**       | **Nulo** | **Clave** | **Default** | **Descripción**                              |
|-----------------------------|----------------|----------|-----------|-------------|----------------------------------------------|
| pedido_id                   | INT            | NO       | PK        | IDENTITY    | Identificador único                          |
| fecha_pedido                | DATETIME       | NO       | —         | GETDATE()   | Fecha y hora de creación                     |
| fecha_entrega               | DATETIME       | SÍ       | —         | —           | Fecha y hora de entrega (delivery)           |
| canal_id                    | INT            | NO       | FK        | —           | Canal de venta                               |
| mesa_id                     | INT            | SÍ       | FK        | —           | Mesa asignada (solo canal MESAS QR)          |
| cliente_id                  | INT            | SÍ       | FK        | —           | Cliente (delivery o registrado)              |
| domicilio_id                | INT            | SÍ       | FK        | —           | Domicilio de entrega (solo delivery)         |
| cant_comensales             | INT            | SÍ       | —         | —           | Número de comensales en mesa                 |
| estado_id                   | INT            | NO       | FK        | —           | Estado actual del pedido                     |
| tomado_por_empleado_id      | INT            | NO       | FK        | —           | Empleado que tomó el pedido                  |
| entregado_por_empleado_id   | INT            | SÍ       | FK        | —           | Empleado que entregó (delivery)              |
| total                       | DECIMAL(10,2)  | NO       | —         | 0           | Total calculado automáticamente por trigger  |
| observaciones               | NVARCHAR(500)  | SÍ       | —         | —           | Notas especiales del pedido                  |

---

### 12. DETALLES_PEDIDOS
**Propósito:** Líneas de pedido. Cada registro representa un ítem (plato) dentro de un pedido.

| **Campo**       | **Tipo**       | **Nulo** | **Clave** | **Default**   | **Descripción**                          |
|-----------------|----------------|----------|-----------|---------------|------------------------------------------|
| detalle_id      | INT            | NO       | PK        | IDENTITY(1,1) | Identificador único de la línea          |
| pedido_id       | INT            | NO       | FK        | —             | Pedido al que pertenece                  |
| plato_id        | INT            | NO       | FK        | —             | Plato pedido (obligatorio)               |
| cantidad        | INT            | NO       | —         | —             | Cantidad pedida (`CHECK > 0`)            |
| precio_unitario | DECIMAL(10,2)  | NO       | —         | —             | Precio vigente al momento del pedido     |
| subtotal        | DECIMAL(10,2)  | NO       | —         | —             | `cantidad × precio_unitario`             |

**Constraints:** `CHECK cantidad > 0` · `CHECK precio_unitario >= 0` · `CHECK subtotal >= 0`

---

## PARTE 2 — TABLAS AUXILIARES

Creadas automáticamente por los Bundles de automatización; no forman parte del Bundle A1.

---

### AUDITORIAS_SIMPLES (creada por Bundle E1)
**Propósito:** Log automático de toda la actividad sobre PEDIDOS y DETALLES_PEDIDOS, generado por triggers sin intervención manual.

| **Campo**       | **Tipo**       | **Descripción**                              |
|-----------------|----------------|----------------------------------------------|
| auditoria_id    | INT PK         | Identificador (IDENTITY)                     |
| tabla_afectada  | NVARCHAR(50)   | Tabla modificada (`PEDIDOS` / `DETALLES_PEDIDOS`) |
| registro_id     | INT            | ID del registro afectado                     |
| accion          | VARCHAR(20)    | `INSERT` / `UPDATE` / `DELETE`               |
| fecha_auditoria | DATETIME       | Timestamp automático (`DEFAULT GETDATE()`)   |
| usuario_sistema | VARCHAR(128)   | Usuario SQL (`DEFAULT SYSTEM_USER`)          |
| datos_resumen   | NVARCHAR(500)  | Resumen legible del cambio                   |

---

### STOCKS_SIMULADOS (creada por Bundle E2)
**Propósito:** Inventario simulado por plato. Gestionado automáticamente por `tr_ValidarStock` en cada INSERT de DETALLES_PEDIDOS.

| **Campo**            | **Tipo** | **Descripción**                              |
|----------------------|----------|----------------------------------------------|
| plato_id             | INT PK/FK| Plato (referencia a PLATOS)                  |
| stock_disponible     | INT      | Unidades disponibles (`DEFAULT 100`, ≥ 0)   |
| stock_minimo         | INT      | Umbral de alerta (`DEFAULT 10`)              |
| ultima_actualizacion | DATETIME | Última modificación por trigger              |

---

### NOTIFICACIONES (creada por Bundle E2)
**Propósito:** Alertas automáticas generadas por `tr_SistemaNotificaciones` y `tr_ValidarStock` ante cambios de estado y problemas de stock.

| **Campo**       | **Tipo**      | **Descripción**                                     |
|-----------------|---------------|-----------------------------------------------------|
| notificacion_id | INT PK        | Identificador (IDENTITY)                            |
| tipo            | VARCHAR(50)   | `PEDIDO_LISTO` / `PEDIDO_CERRADO` / `STOCK_BAJO` / etc. |
| titulo          | NVARCHAR(200) | Título de la notificación                           |
| mensaje         | NVARCHAR(500) | Cuerpo del mensaje                                  |
| pedido_id       | INT NULL      | Pedido relacionado (referencia lógica)              |
| mesa_id         | INT NULL      | Mesa relacionada (referencia lógica)                |
| prioridad       | VARCHAR(20)   | `BAJA` / `NORMAL` / `ALTA` / `CRITICA`              |
| fecha_creacion  | DATETIME      | Timestamp de creación (`DEFAULT GETDATE()`)         |
| leida           | BIT           | Si fue leída (`DEFAULT 0`)                          |
| fecha_lectura   | DATETIME NULL | Cuándo fue leída                                    |
| usuario_destino | VARCHAR(100)  | Destinatario: `COCINA` / `MOZOS` / `CAJA` / `DELIVERY` |

---

### REPORTES_GENERADOS (creada por Bundle R1)
**Propósito:** Registro persistente de reportes ejecutados. Los SPs de reporte pueden guardar sus resultados aquí cuando se llaman con `@guardar_reporte = 1`.

| **Campo**        | **Tipo**       | **Descripción**                                   |
|------------------|----------------|---------------------------------------------------|
| reporte_id       | INT PK         | Identificador (IDENTITY)                          |
| tipo_reporte     | NVARCHAR(50)   | `VENTAS_DIARIO` / `TOP_PLATOS_DIARIO` / etc.      |
| fecha_generacion | DATETIME       | Timestamp de ejecución (`DEFAULT GETDATE()`)      |
| fecha_reporte    | DATE           | Fecha del período reportado                       |
| sucursal_id      | INT NULL FK    | Sucursal filtrada (NULL = todas)                  |
| datos_json       | NVARCHAR(MAX)  | Resultados del reporte en formato JSON            |
| ejecutado_por    | NVARCHAR(100)  | Usuario que ejecutó (`DEFAULT SYSTEM_USER`)       |
| estado           | NVARCHAR(20)   | Estado del reporte (`DEFAULT 'COMPLETADO'`)       |
| observaciones    | NVARCHAR(500)  | Notas adicionales                                 |

---

## PARTE 3 — ÍNDICES

**Total: 14 índices non-clustered** (11 en Bundle A2 + 3 en Bundle R1)

### Índices de Performance (Bundle A2)

| **Índice**                  | **Tabla**        | **Columnas**                      | **Tipo**          | **Propósito**                             |
|-----------------------------|------------------|-----------------------------------|-------------------|-------------------------------------------|
| `IX_PEDIDO_fecha_estado`    | PEDIDOS          | fecha_pedido, estado_id           | Non-clustered     | Consultas de ventas diarias               |
| `IX_PEDIDO_mesa`            | PEDIDOS          | mesa_id (filtrado NOT NULL)       | Non-clustered     | Lookup de pedido activo por mesa          |
| `IX_PEDIDO_cliente`         | PEDIDOS          | cliente_id (filtrado NOT NULL)    | Non-clustered     | Historial de cliente / delivery           |
| `IX_DETALLE_PEDIDO_pedido`  | DETALLES_PEDIDOS | pedido_id                         | Non-clustered     | JOIN principal detalle → pedido           |
| `IX_DETALLE_PEDIDO_plato`   | DETALLES_PEDIDOS | plato_id                          | Non-clustered     | Ranking de productos populares            |
| `IX_MESA_sucursal_activa`   | MESAS            | sucursal_id, activa               | Non-clustered     | Mesas activas por sucursal                |
| `IX_EMPLEADO_sucursal_activo` | EMPLEADOS      | sucursal_id, activo               | Non-clustered     | Empleados activos por sucursal            |
| `IX_PRECIO_plato_vigencia`  | PRECIOS          | plato_id, vigencia_desde, vigencia_hasta | Non-clustered | Precio vigente (evita table scan)    |

### Índices de Unicidad Filtrada (Bundle A2)

| **Índice**                  | **Tabla**   | **Columnas / Filtro**                                     | **Propósito**                              |
|-----------------------------|-------------|-----------------------------------------------------------|--------------------------------------------|
| `UIX_CLIENTE_email`         | CLIENTES    | email `WHERE email IS NOT NULL`                           | Email único solo en clientes registrados   |
| `UIX_CLIENTE_documento`     | CLIENTES    | doc_tipo, doc_nro `WHERE ambos IS NOT NULL`               | Documento único sin restringir NULLs       |
| `UIX_DOMICILIO_principal`   | DOMICILIOS  | cliente_id `WHERE es_principal = 1`                       | Máximo un domicilio principal por cliente  |

> **Por qué índices filtrados y no UNIQUE constraints:** SQL Server no permite múltiples valores NULL en columnas con UNIQUE estándar. Los índices filtrados aplican la restricción de unicidad solo sobre los valores reales, permitiendo múltiples clientes sin email o sin documento registrado.

### Índices de Reportes (Bundle R1)

| **Índice**                | **Tabla**           | **Columnas**                  | **Propósito**                      |
|---------------------------|---------------------|-------------------------------|------------------------------------|
| `IX_REPORTES_tipo_fecha`  | REPORTES_GENERADOS  | tipo_reporte, fecha_reporte   | Consultas por tipo y período       |
| `IX_REPORTES_sucursal`    | REPORTES_GENERADOS  | sucursal_id, fecha_reporte    | Consultas filtradas por sucursal   |
| `IX_REPORTES_generacion`  | REPORTES_GENERADOS  | fecha_generacion DESC         | Historial de reportes recientes    |

---

**Desarrollado por:** SQLeaders S.A.  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — 2026**
