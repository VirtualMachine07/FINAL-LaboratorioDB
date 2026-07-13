# CATÁLOGO DE VISTAS — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**            | **Descripción**                                     |
|----------------------|-----------------------------------------------------|
| **Documento**        | Catálogo de Vistas — EsbirrosDB                     |
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

## RESUMEN DE VISTAS

| **Vista**                | **Bundle** | **Caso de uso principal**                         |
|--------------------------|------------|---------------------------------------------------|
| `vw_PedidosCompletos`    | D          | Consulta detallada de cualquier pedido            |
| `vw_EstadoMesas`         | D          | Estado operativo de cada mesa en tiempo real      |
| `vw_DashboardEjecutivo`  | R2         | KPIs de ventas del día y del mes                  |
| `vw_MonitoreoTiempoReal` | R2         | Cola de cocina y ocupación en tiempo real         |

---

## VISTA 1 — `vw_PedidosCompletos`
**Bundle:** D (`Bundle_D_Consultas_Basicas.sql`)

### Propósito
Consolida en una sola fila toda la información relevante de un pedido: estado, canal, cliente, mesa, empleado, sucursal, total y tiempos. Elimina la necesidad de hacer JOINs manuales al consultar pedidos.

### Tablas que une

| **Tabla**        | **Tipo de JOIN** | **Condición**                                    |
|------------------|------------------|--------------------------------------------------|
| `PEDIDOS`        | Base             | —                                                |
| `ESTADOS_PEDIDOS`| INNER JOIN       | `PEDIDOS.estado_id = ESTADOS_PEDIDOS.estado_id`  |
| `CANALES_VENTAS` | INNER JOIN       | `PEDIDOS.canal_id = CANALES_VENTAS.canal_id`     |
| `EMPLEADOS`      | INNER JOIN       | `PEDIDOS.tomado_por_empleado_id = EMPLEADOS.empleado_id` |
| `SUCURSALES`     | INNER JOIN       | `EMPLEADOS.sucursal_id = SUCURSALES.sucursal_id` |
| `MESAS`          | LEFT JOIN        | `PEDIDOS.mesa_id = MESAS.mesa_id` (NULL en delivery) |
| `CLIENTES`       | LEFT JOIN        | `PEDIDOS.cliente_id = CLIENTES.cliente_id` (NULL en mostrador) |

### Columnas expuestas

| **Columna**               | **Origen**        | **Descripción**                                  |
|---------------------------|-------------------|--------------------------------------------------|
| pedido_id                 | PEDIDOS           | ID del pedido                                    |
| fecha_pedido              | PEDIDOS           | Fecha y hora completa                            |
| fecha_pedido_formato      | PEDIDOS           | Fecha en formato `yyyy-MM-dd`                    |
| hora_pedido               | PEDIDOS           | Hora en formato `HH:mm`                          |
| dia_semana                | PEDIDOS           | Nombre del día (`Lunes`, `Martes`, etc.)         |
| estado_nombre             | ESTADOS_PEDIDOS   | Estado actual del pedido                         |
| estado_orden              | ESTADOS_PEDIDOS   | Número de orden del estado en el flujo           |
| canal_nombre              | CANALES_VENTAS    | Canal de venta                                   |
| cliente_id                | CLIENTES          | ID del cliente (NULL si sin cliente)             |
| cliente_nombre            | CLIENTES          | Nombre del cliente                               |
| cliente_telefono          | CLIENTES          | Teléfono del cliente                             |
| cliente_email             | CLIENTES          | Email del cliente                                |
| mesa_id                   | MESAS             | ID de mesa (NULL en delivery)                   |
| mesa_numero               | MESAS             | Número de mesa                                   |
| mesa_capacidad            | MESAS             | Capacidad de la mesa                             |
| cant_comensales           | PEDIDOS           | Comensales declarados al crear el pedido         |
| empleado_id               | EMPLEADOS         | ID del empleado que tomó el pedido               |
| empleado_nombre           | EMPLEADOS         | Nombre del empleado                              |
| empleado_usuario          | EMPLEADOS         | Usuario de sistema del empleado                  |
| sucursal_id               | SUCURSALES        | ID de la sucursal                                |
| sucursal_nombre           | SUCURSALES        | Nombre de la sucursal                            |
| sucursal_direccion        | SUCURSALES        | Dirección de la sucursal                         |
| total_pedido              | PEDIDOS           | Total calculado por trigger                      |
| fecha_entrega             | PEDIDOS           | Fecha de entrega (solo delivery o cerrado)       |
| minutos_transcurridos     | Calculado         | Minutos desde creación hasta entrega o ahora     |

### Quién la usa
- **Mozos** → para ver el estado de un pedido durante el servicio
- **Cajeros** → para cerrar y cobrar pedidos
- **Gerencia** → para auditar cualquier pedido histórico
- **SPs de reportes** → `sp_ConsultarPedidosPorEstado` la usa como fuente base

### Ejemplo de uso
```sql
-- Ver todos los pedidos activos de hoy
SELECT * FROM vw_PedidosCompletos
WHERE fecha_pedido_formato = CAST(GETDATE() AS DATE)
  AND estado_nombre NOT IN ('Cerrado', 'Cancelado')
ORDER BY fecha_pedido;

-- Ver un pedido específico (con su ID)
SELECT * FROM vw_PedidosCompletos WHERE pedido_id = 10011;
```

---

## VISTA 2 — `vw_EstadoMesas`
**Bundle:** D (`Bundle_D_Consultas_Basicas.sql`)

### Propósito
Muestra el estado operativo actual de cada mesa en tiempo real. El estado **no se almacena en la tabla MESAS** — la vista lo deriva dinámicamente según si la mesa tiene o no un pedido activo (es decir, un pedido que no esté en estado Cerrado, Cancelado ni Entregado).

### Tablas que une

| **Tabla**        | **Tipo de JOIN**     | **Condición**                                            |
|------------------|----------------------|----------------------------------------------------------|
| `MESAS`          | Base                 | —                                                        |
| `SUCURSALES`     | INNER JOIN           | `MESAS.sucursal_id = SUCURSALES.sucursal_id`             |
| `PEDIDOS` (activos) | LEFT JOIN (subquery) | Último pedido no cerrado/cancelado por mesa (ROW_NUMBER) |
| `ESTADOS_PEDIDOS`| LEFT JOIN            | Estado del pedido activo                                 |
| `EMPLEADOS`      | LEFT JOIN            | Empleado responsable del pedido activo                   |

### Columnas expuestas

| **Columna**             | **Origen**       | **Descripción**                                              |
|-------------------------|------------------|--------------------------------------------------------------|
| mesa_id                 | MESAS            | ID de la mesa                                                |
| mesa_numero             | MESAS            | Número de mesa                                               |
| capacidad               | MESAS            | Capacidad máxima de comensales                               |
| qr_token                | MESAS            | Token del código QR                                          |
| sucursal_id             | SUCURSALES       | ID de la sucursal                                            |
| sucursal_nombre         | SUCURSALES       | Nombre de la sucursal                                        |
| estado_actual           | Calculado        | `'Ocupada'` si hay pedido activo, `'Disponible'` si no      |
| pedido_activo_id        | PEDIDOS          | ID del pedido activo (NULL si disponible)                    |
| pedido_inicio           | PEDIDOS          | Fecha/hora de inicio del pedido activo                       |
| cant_comensales         | PEDIDOS          | Comensales del pedido activo                                 |
| total                   | PEDIDOS          | Total acumulado del pedido activo                            |
| estado_pedido_activo    | ESTADOS_PEDIDOS  | Nombre del estado del pedido activo                          |
| empleado_responsable    | EMPLEADOS        | Nombre del empleado que tomó el pedido                       |
| minutos_ocupada         | Calculado        | Minutos que lleva ocupada la mesa (0 si disponible)          |
| estado_operativo        | Calculado        | Descripción amigable del estado actual (ver detalle abajo)   |

**Valores posibles de `estado_operativo`:**

| **Valor**               | **Condición**                          |
|-------------------------|----------------------------------------|
| `Fuera de servicio`     | Mesa marcada como inactiva (`activa = 0`) |
| `Lista para uso`        | Mesa activa sin pedido activo          |
| `Esperando orden`       | Pedido en estado Pendiente             |
| `Comida en preparacion` | Pedido en Confirmado o En Preparación  |
| `Comida lista`          | Pedido en estado Listo                 |
| `En uso`                | Cualquier otro estado activo           |

### Quién la usa
- **Hostess / Recepción** → para asignar mesas disponibles a nuevos clientes
- **Mozos** → para ver qué mesas tienen pedidos en qué estado
- **Dashboard** → como fuente de ocupación en tiempo real

### Ejemplo de uso
```sql
-- Ver estado de todas las mesas
SELECT mesa_numero, estado_actual, estado_operativo, empleado_responsable, minutos_ocupada
FROM vw_EstadoMesas
ORDER BY mesa_numero;

-- Solo mesas disponibles
SELECT mesa_numero, capacidad FROM vw_EstadoMesas WHERE estado_actual = 'Disponible';
```

---

## VISTA 3 — `vw_DashboardEjecutivo`
**Bundle:** R2 (`Bundle_R2_Reportes_Vistas_Dashboard.sql`)

### Propósito
Devuelve en una sola fila los KPIs de negocio más importantes del día y del mes actual. Diseñada para ser consultada desde un panel gerencial o de control sin necesidad de parámetros.

### Tablas que usa
Subconsultas independientes sobre: `PEDIDOS`, `ESTADOS_PEDIDOS`, `DETALLES_PEDIDOS`, `PLATOS`, `MESAS`.  
No hace JOINs directos — cada métrica es una subconsulta escalar.

### Columnas expuestas

| **Columna**             | **Descripción**                                                    |
|-------------------------|--------------------------------------------------------------------|
| ventas_hoy              | Suma de totales de pedidos Entregados o Cerrados del día           |
| pedidos_hoy             | Cantidad de pedidos Entregados o Cerrados del día                  |
| ticket_promedio_hoy     | Promedio de total por pedido del día                               |
| ventas_mes              | Suma de totales Entregados o Cerrados del mes en curso             |
| pedidos_mes             | Cantidad de pedidos Entregados o Cerrados del mes en curso         |
| plato_top_hoy           | Nombre del plato más vendido en cantidad del día                   |
| mesas_ocupadas          | Mesas con pedido activo (no Entregado/Cerrado/Cancelado) ahora     |
| pedidos_pendientes      | Pedidos en estados Pendiente, Confirmado, En Preparación o Listo   |
| ultima_actualizacion    | Timestamp de la última consulta a la vista (`GETDATE()`)           |

### Quién la usa
- **Gerencia / Dueño** → para monitoreo rápido del negocio
- **Cajero** → para ver facturación del turno

### Ejemplo de uso
```sql
SELECT * FROM vw_DashboardEjecutivo;
```

---

## VISTA 4 — `vw_MonitoreoTiempoReal`
**Bundle:** R2 (`Bundle_R2_Reportes_Vistas_Dashboard.sql`)

### Propósito
Muestra la cola de cocina y la ocupación operacional en tiempo real. Pensada para pantallas de monitoreo en cocina o caja, actualizándose en cada consulta.

### Tablas que usa
Subconsultas independientes sobre: `PEDIDOS`, `ESTADOS_PEDIDOS`, `MESAS`.  
No hace JOINs directos — cada métrica es una subconsulta escalar.

### Columnas expuestas

| **Columna**             | **Descripción**                                                 |
|-------------------------|-----------------------------------------------------------------|
| tipo_monitoreo          | Literal `'TIEMPO_REAL'` (identificador del tipo de consulta)   |
| momento                 | Timestamp actual (`GETDATE()`)                                  |
| pendientes              | Pedidos en estado Pendiente ahora                               |
| confirmados             | Pedidos en estado Confirmado ahora                              |
| en_preparacion          | Pedidos en estado En Preparación ahora                          |
| listos_entrega          | Pedidos en estado Listo ahora                                   |
| en_reparto              | Pedidos en estado En Reparto ahora                              |
| mesas_ocupadas          | Mesas con pedido activo en este momento                         |
| mesas_totales           | Total de mesas activas (`activa = 1`)                           |
| ventas_acumuladas_hoy   | Facturación acumulada del día (Entregado + Cerrado)             |
| empleados_activos_hoy   | Empleados que tomaron al menos un pedido hoy                    |

### Quién la usa
- **Cocina** → para ver la cola de pedidos pendientes de preparación
- **Supervisión** → para monitorear el ritmo de trabajo en tiempo real
- **Caja** → para ver facturación acumulada del turno

### Ejemplo de uso
```sql
SELECT * FROM vw_MonitoreoTiempoReal;

-- Ver solo la cola de cocina (pedidos no entregados)
SELECT pendientes, confirmados, en_preparacion, listos_entrega, momento
FROM vw_MonitoreoTiempoReal;
```

---

**Desarrollado por:** SQLeaders S.A.  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — 2026**
