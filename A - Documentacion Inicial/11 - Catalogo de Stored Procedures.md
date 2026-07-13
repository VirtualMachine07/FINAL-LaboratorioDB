# CATÁLOGO DE STORED PROCEDURES — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**            | **Descripción**                                     |
|----------------------|-----------------------------------------------------|
| **Documento**        | Catálogo de Stored Procedures — EsbirrosDB          |
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

## RESUMEN POR GRUPO

| **Grupo**                | **SPs** | **Bundle** | **Función**                              |
|--------------------------|---------|------------|------------------------------------------|
| A — Pedidos Core         | 1       | B1         | Crear pedidos con validaciones completas |
| B — Ítems y Cálculos     | 2       | B2         | Agregar ítems y recalcular totales       |
| C — Estados y Cierre     | 3       | B3         | Cerrar, cancelar y avanzar estados       |
| D — Consultas Operativas | 4       | D          | Menú, mesas, pedidos y resumen del día   |
| E — Control Avanzado     | 3       | E2         | Notificaciones y stock                   |
| F — Reportes             | 5       | R1         | Ventas diarias, ranking y análisis       |
| **Total**                | **18**  |            |                                          |

---

## GRUPO A — PEDIDOS CORE (Bundle B1)

---

### `sp_CrearPedido`

**Propósito:** Crea un nuevo pedido con validaciones completas antes de cualquier INSERT. Es el punto de entrada al ciclo de vida de un pedido.

**Parámetros de entrada:**

| **Parámetro**              | **Tipo**      | **Obligatorio** | **Descripción**                        |
|----------------------------|---------------|-----------------|----------------------------------------|
| `@canal_id`                | INT           | Sí              | ID del canal de venta                  |
| `@mesa_id`                 | INT           | No              | ID de mesa (solo canal MESAS QR)       |
| `@cliente_id`              | INT           | No              | ID del cliente (delivery)              |
| `@domicilio_id`            | INT           | No              | ID del domicilio (delivery)            |
| `@cant_comensales`         | INT           | No              | Número de comensales                   |
| `@tomado_por_empleado_id`  | INT           | Sí              | ID del empleado que toma el pedido     |

**Parámetros de salida:**

| **Parámetro** | **Tipo**       | **Descripción**                            |
|---------------|----------------|--------------------------------------------|
| `@pedido_id`  | INT OUTPUT     | ID del pedido creado (0 si hubo error)     |
| `@mensaje`    | NVARCHAR(500) OUTPUT | Confirmación o descripción del error |

**Validaciones que realiza:**
1. Canal de venta existe en la tabla `CANALES_VENTAS`
2. Estado "Pendiente" existe en `ESTADOS_PEDIDOS`
3. Empleado existe y está activo (`activo = 1`)
4. Mesa existe y está activa (si se proporciona `@mesa_id`)
5. Empleado y mesa pertenecen a la misma sucursal (validación cruzada)

**Comportamiento:** Si todas las validaciones pasan, inserta el pedido con `estado_id = Pendiente` y `total = 0`. El total se recalculará automáticamente cuando se agreguen ítems.

**Ejemplo de uso:**
```sql
DECLARE @id INT, @msg NVARCHAR(500)
EXEC sp_CrearPedido
    @canal_id = 3, @mesa_id = 1, @cant_comensales = 4,
    @tomado_por_empleado_id = 2,
    @pedido_id = @id OUTPUT, @mensaje = @msg OUTPUT
SELECT @id AS pedido_id, @msg AS resultado
```

---

## GRUPO B — ÍTEMS Y CÁLCULOS (Bundle B2)

---

### `sp_AgregarItemPedido`

**Propósito:** Agrega un ítem (plato) a un pedido existente. Obtiene el precio vigente automáticamente y calcula el subtotal. Dispara los triggers `tr_ActualizarTotales`, `tr_AuditoriaDetalle` y `tr_ValidarStock`.

**Parámetros de entrada:**

| **Parámetro** | **Tipo** | **Obligatorio** | **Descripción**                      |
|---------------|----------|-----------------|--------------------------------------|
| `@pedido_id`  | INT      | Sí              | ID del pedido al que agregar el ítem |
| `@plato_id`   | INT      | Sí              | ID del plato del menú                |
| `@cantidad`   | INT      | Sí              | Cantidad pedida (debe ser > 0)       |

**Parámetros de salida:**

| **Parámetro**  | **Tipo**       | **Descripción**                              |
|----------------|----------------|----------------------------------------------|
| `@detalle_id`  | INT OUTPUT     | ID del detalle creado (0 si hubo error)      |
| `@mensaje`     | NVARCHAR(500) OUTPUT | Confirmación con subtotal o error      |

**Validaciones que realiza:**
1. El pedido existe
2. El pedido está en estado **Pendiente o Confirmado** (no se pueden agregar ítems en preparación o posterior)
3. `@plato_id` no es NULL
4. El plato existe y está activo (`activo = 1`)
5. La cantidad es mayor a cero
6. Existe un precio vigente para el plato a la fecha actual

**Cálculo de precio:** Toma el `monto` de la tabla `PRECIOS` con `vigencia_desde <= hoy` y `(vigencia_hasta IS NULL OR vigencia_hasta >= hoy)`, ordenado por `vigencia_desde DESC`. Garantiza el precio del momento exacto del pedido.

**Ejemplo de uso:**
```sql
DECLARE @did INT, @msg NVARCHAR(500)
EXEC sp_AgregarItemPedido @pedido_id=10011, @plato_id=5, @cantidad=2,
     @detalle_id=@did OUTPUT, @mensaje=@msg OUTPUT
SELECT @did AS detalle_id, @msg AS resultado
```

---

### `sp_CalcularTotalPedido`

**Propósito:** Recalcula manualmente el total de un pedido sumando todos sus subtotales. En operación normal **no es necesario llamarlo** porque `tr_ActualizarTotales` lo hace automáticamente; se usa para correcciones manuales o como utilidad interna de `sp_CerrarPedido`.

**Parámetros de entrada:**

| **Parámetro** | **Tipo** | **Obligatorio** | **Descripción**    |
|---------------|----------|-----------------|--------------------|
| `@pedido_id`  | INT      | Sí              | ID del pedido      |

**Parámetros de salida:**

| **Parámetro**   | **Tipo**       | **Descripción**                         |
|-----------------|----------------|-----------------------------------------|
| `@nuevo_total`  | DECIMAL(10,2) OUTPUT | Total recalculado                 |
| `@mensaje`      | NVARCHAR(500) OUTPUT | Confirmación o descripción de error |

**Comportamiento:** Suma todos los `subtotal` de `DETALLES_PEDIDOS` para el pedido dado y actualiza el campo `PEDIDOS.total`.

---

## GRUPO C — ESTADOS Y CIERRE (Bundle B3)

---

### `sp_CerrarPedido`

**Propósito:** Cierra un pedido llevándolo al estado "Cerrado". Verifica que el pedido tenga ítems antes de cerrarlo y recalcula el total como paso previo al cierre.

**Parámetros de entrada:**

| **Parámetro** | **Tipo** | **Obligatorio** | **Descripción**    |
|---------------|----------|-----------------|--------------------|
| `@pedido_id`  | INT      | Sí              | ID del pedido      |

**Parámetros de salida:**

| **Parámetro** | **Tipo**       | **Descripción**                              |
|---------------|----------------|----------------------------------------------|
| `@mensaje`    | NVARCHAR(500) OUTPUT | Confirmación con total final o error   |

**Validaciones que realiza:**
1. El pedido existe
2. El pedido no está ya en estado Cerrado o Cancelado
3. El pedido tiene al menos un ítem en `DETALLES_PEDIDOS`
4. El estado "Cerrado" existe en `ESTADOS_PEDIDOS`

**Comportamiento al cerrar:** Llama a `sp_CalcularTotalPedido` para asegurar que el total esté actualizado, cambia el estado a "Cerrado" y registra `fecha_entrega = GETDATE()`.

---

### `sp_CancelarPedido`

**Propósito:** Cancela un pedido desde cualquier estado activo. El motivo de cancelación es opcional y se registra en el campo `observaciones` del pedido.

**Parámetros de entrada:**

| **Parámetro** | **Tipo**      | **Obligatorio** | **Descripción**                        |
|---------------|---------------|-----------------|----------------------------------------|
| `@pedido_id`  | INT           | Sí              | ID del pedido a cancelar               |
| `@motivo`     | NVARCHAR(255) | No              | Motivo de cancelación (texto libre)    |

**Parámetros de salida:**

| **Parámetro** | **Tipo**       | **Descripción**                           |
|---------------|----------------|-------------------------------------------|
| `@mensaje`    | NVARCHAR(500) OUTPUT | Confirmación o descripción del error |

**Validaciones que realiza:**
1. El pedido existe
2. El pedido no está ya en estado Cerrado o Cancelado (no se puede cancelar dos veces)
3. El estado "Cancelado" existe en `ESTADOS_PEDIDOS`

**Comportamiento:** Cambia el estado a "Cancelado" y concatena el motivo en `observaciones`. El trigger `tr_SistemaNotificaciones` genera automáticamente notificaciones a CAJA y COCINA.

---

### `sp_ActualizarEstadoPedido`

**Propósito:** Avanza un pedido al siguiente estado según la secuencia definida por el campo `orden` de `ESTADOS_PEDIDOS`. Rechaza cualquier transición fuera de orden.

**Parámetros de entrada:**

| **Parámetro**                  | **Tipo**      | **Obligatorio** | **Descripción**                                    |
|--------------------------------|---------------|-----------------|----------------------------------------------------|
| `@pedido_id`                   | INT           | Sí              | ID del pedido a actualizar                         |
| `@nuevo_estado`                | NVARCHAR(50)  | Sí              | Nombre del nuevo estado (ej: `'Confirmado'`)        |
| `@entregado_por_empleado_id`   | INT           | Solo si Entregado | ID del empleado que entregó (delivery)           |

**Parámetros de salida:**

| **Parámetro** | **Tipo**       | **Descripción**                              |
|---------------|----------------|----------------------------------------------|
| `@mensaje`    | NVARCHAR(500) OUTPUT | Confirmación del cambio o error        |

**Validaciones que realiza:**
1. El pedido existe
2. El pedido no está ya Cerrado o Cancelado
3. El nuevo estado existe en `ESTADOS_PEDIDOS`
4. El nuevo estado no es "Cancelado" (para eso existe `sp_CancelarPedido`)
5. El `orden` del nuevo estado es exactamente `orden_actual + 1` (progresión estrictamente secuencial)
6. Si el nuevo estado es "Entregado": el empleado de entrega debe existir y estar activo

**Ejemplo de uso:**
```sql
DECLARE @msg NVARCHAR(500)
EXEC sp_ActualizarEstadoPedido
    @pedido_id = 10011, @nuevo_estado = 'En Preparación',
    @mensaje = @msg OUTPUT
SELECT @msg AS resultado
```

---

## GRUPO D — CONSULTAS OPERATIVAS (Bundle D)

---

### `sp_ConsultarMenuActual`

**Propósito:** Devuelve el menú vigente con precios activos a la fecha de la consulta. Filtrables por categoría.

**Parámetros de entrada:**

| **Parámetro** | **Tipo**     | **Obligatorio** | **Descripción**                                      |
|---------------|--------------|-----------------|------------------------------------------------------|
| `@categoria`  | NVARCHAR(50) | No              | Filtro por categoría (NULL = todas las categorías)   |

**Devuelve:** plato_id, nombre, categoría, precio actual, fechas de vigencia, estado del precio, si está activo.

---

### `sp_MesasDisponibles`

**Propósito:** Lista las mesas activas de una sucursal indicando su estado actual (Disponible / Ocupada) y el pedido activo si corresponde.

**Parámetros de entrada:**

| **Parámetro**  | **Tipo** | **Obligatorio** | **Descripción**                          |
|----------------|----------|-----------------|------------------------------------------|
| `@sucursal_id` | INT      | No              | Filtro por sucursal (NULL = todas)       |

**Devuelve:** mesa_id, número, capacidad, sucursal, qr_token, estado_mesa, pedido_activo_id.

---

### `sp_ConsultarPedidosPorEstado`

**Propósito:** Consulta pedidos filtrados por estado, sucursal y rango de fechas. Usa `vw_PedidosCompletos` como fuente e incluye el detalle textual de los ítems de cada pedido.

**Parámetros de entrada:**

| **Parámetro**   | **Tipo**     | **Obligatorio** | **Descripción**                               |
|-----------------|--------------|-----------------|-----------------------------------------------|
| `@estado_nombre`| NVARCHAR(50) | No              | Estado a filtrar (NULL = todos los estados)   |
| `@sucursal_id`  | INT          | No              | Sucursal a filtrar (NULL = todas)             |
| `@fecha_desde`  | DATE         | No              | Inicio del rango (default: hoy)               |
| `@fecha_hasta`  | DATE         | No              | Fin del rango (default: hoy)                  |

**Devuelve:** Datos completos del pedido (desde la vista) más cantidad de ítems y listado textual de platos con cantidades.

---

### `sp_ResumenOperativoDiario`

**Propósito:** Genera un resumen del día para una sucursal: pedidos cerrados, cancelados, activos, facturación total, ticket promedio, mesas y canales.

**Parámetros de entrada:**

| **Parámetro**  | **Tipo** | **Obligatorio** | **Descripción**                          |
|----------------|----------|-----------------|------------------------------------------|
| `@fecha`       | DATE     | No              | Fecha a resumir (default: hoy)           |
| `@sucursal_id` | INT      | No              | Sucursal (NULL = todas)                  |

**Devuelve:** total_pedidos, pedidos_cerrados, pedidos_cancelados, pedidos_activos, facturacion_total, ticket_promedio, mesas_utilizadas, pedidos_delivery, pedidos_qr, total_items_vendidos, platos_diferentes_vendidos.

---

## GRUPO E — CONTROL AVANZADO (Bundle E2)

---

### `sp_ConsultarNotificaciones`

**Propósito:** Consulta las notificaciones del sistema filtradas por destinatario, estado de lectura y prioridad. Incluye el estado actual del pedido relacionado y el número de mesa.

**Parámetros de entrada:**

| **Parámetro**      | **Tipo**    | **Obligatorio** | **Descripción**                                      |
|--------------------|-------------|-----------------|------------------------------------------------------|
| `@usuario_destino` | VARCHAR(100)| No              | Destinatario (`COCINA`, `MOZOS`, `CAJA`, `DELIVERY`) |
| `@solo_no_leidas`  | BIT         | No              | `1` = solo no leídas (default), `0` = todas         |
| `@prioridad`       | VARCHAR(20) | No              | Filtrar por prioridad (`CRITICA`, `ALTA`, etc.)      |

**Devuelve:** Datos completos de la notificación más estado actual del pedido relacionado, número de mesa y minutos de antigüedad. Ordenadas por prioridad (CRITICA primero) y fecha.

---

### `sp_MarcarNotificacionLeida`

**Propósito:** Marca una notificación como leída, registrando la fecha y hora de lectura.

**Parámetros de entrada:**

| **Parámetro**     | **Tipo** | **Obligatorio** | **Descripción**           |
|-------------------|----------|-----------------|---------------------------|
| `@notificacion_id`| INT      | Sí              | ID de la notificación     |

**Comportamiento:** Actualiza `leida = 1` y `fecha_lectura = GETDATE()`. Si la notificación no existe o ya estaba leída, retorna -1.

---

### `sp_ConsultarStock`

**Propósito:** Consulta el stock actual de los platos con su clasificación de estado. Permite filtrar por plato específico o mostrar solo los que están en niveles críticos.

**Parámetros de entrada:**

| **Parámetro**     | **Tipo** | **Obligatorio** | **Descripción**                            |
|-------------------|----------|-----------------|--------------------------------------------|
| `@plato_id`       | INT      | No              | Filtro por plato específico (NULL = todos) |
| `@solo_stock_bajo`| BIT      | No              | `1` = solo platos en estado CRITICO        |

**Devuelve:** plato_id, nombre, categoría, stock_disponible, stock_minimo, última actualización, `estado_stock` (`CRITICO` / `BAJO` / `NORMAL`), precio actual.

---

## GRUPO F — REPORTES (Bundle R1)

---

### `sp_ReporteVentasDiario`

**Propósito:** Genera el reporte de ventas del día: facturación total, pedidos completados, ticket promedio, comparación con el día anterior (crecimiento porcentual), ítems vendidos y mesas utilizadas.

**Parámetros de entrada:**

| **Parámetro**     | **Tipo** | **Obligatorio** | **Descripción**                                    |
|-------------------|----------|-----------------|----------------------------------------------------|
| `@fecha`          | DATE     | No              | Fecha del reporte (default: hoy)                   |
| `@sucursal_id`    | INT      | No              | Sucursal (NULL = todas)                            |
| `@guardar_reporte`| BIT      | No              | `1` = guarda resultado en `REPORTES_GENERADOS`     |

**Devuelve:** tipo_reporte, fecha, sucursal, facturación total, pedidos completados, ticket promedio, facturación anterior, % de crecimiento, total ítems, mesas utilizadas.

---

### `sp_PlatosMasVendidosDiario`

**Propósito:** Ranking de los N platos más vendidos del día por cantidad, con ingresos generados y promedio por pedido.

**Parámetros de entrada:**

| **Parámetro**     | **Tipo** | **Obligatorio** | **Descripción**                                  |
|-------------------|----------|-----------------|--------------------------------------------------|
| `@fecha`          | DATE     | No              | Fecha del reporte (default: hoy)                 |
| `@top_cantidad`   | INT      | No              | Cuántos platos mostrar (default: 10)             |
| `@sucursal_id`    | INT      | No              | Sucursal (NULL = todas)                          |
| `@guardar_reporte`| BIT      | No              | `1` = guarda resultado en `REPORTES_GENERADOS`   |

**Devuelve:** posición, nombre del plato, categoría, cantidad vendida, ingresos generados, pedidos incluidos, promedio por pedido.

---

### `sp_RendimientoCanalDiario`

**Propósito:** Compara el rendimiento de cada canal de venta (Mostrador, Delivery, MESAS QR, Teléfono) para un día dado: pedidos totales, completados, cancelados, facturación, tasa de completación y porcentaje sobre la facturación total.

**Parámetros de entrada:**

| **Parámetro**     | **Tipo** | **Obligatorio** | **Descripción**                                  |
|-------------------|----------|-----------------|--------------------------------------------------|
| `@fecha`          | DATE     | No              | Fecha del reporte (default: hoy)                 |
| `@sucursal_id`    | INT      | No              | Sucursal (NULL = todas)                          |
| `@guardar_reporte`| BIT      | No              | `1` = guarda resultado en `REPORTES_GENERADOS`   |

---

### `sp_AnalisisVentasMensual`

**Propósito:** Análisis de ventas de un mes completo: facturación total, pedidos completados y cancelados, ticket promedio, ítems vendidos y días con ventas.

**Parámetros de entrada:**

| **Parámetro**     | **Tipo** | **Obligatorio** | **Descripción**                                  |
|-------------------|----------|-----------------|--------------------------------------------------|
| `@anio`           | INT      | No              | Año del reporte (default: año actual)            |
| `@mes`            | INT      | No              | Mes del reporte (default: mes actual)            |
| `@sucursal_id`    | INT      | No              | Sucursal (NULL = todas)                          |
| `@guardar_reporte`| BIT      | No              | `1` = guarda resultado en `REPORTES_GENERADOS`   |

---

### `sp_RankingProductosMensual`

**Propósito:** Ranking de los N platos más vendidos en un mes completo, con precio máximo, mínimo y promedio por pedido del mes.

**Parámetros de entrada:**

| **Parámetro**     | **Tipo** | **Obligatorio** | **Descripción**                                  |
|-------------------|----------|-----------------|--------------------------------------------------|
| `@anio`           | INT      | No              | Año del reporte (default: año actual)            |
| `@mes`            | INT      | No              | Mes del reporte (default: mes actual)            |
| `@top_cantidad`   | INT      | No              | Cuántos platos mostrar (default: 10)             |
| `@sucursal_id`    | INT      | No              | Sucursal (NULL = todas)                          |
| `@guardar_reporte`| BIT      | No              | `1` = guarda resultado en `REPORTES_GENERADOS`   |

---

## NOTA: DISCREPANCIA EN CONTEO DE SPs

La `10 - Guia de Defensa Oral.md` del equipo técnico indica 19 SPs, pero el inventario real de los scripts SQL suma **18**. La diferencia corresponde a `sp_ObtenerPrecioVigente`, mencionado en la guía de defensa como SP independiente.

**Resolución:** Esta funcionalidad no fue implementada como SP separado. La lógica de obtención del precio vigente quedó **embebida directamente dentro de `sp_AgregarItemPedido`** como paso 4 de su flujo interno:

```sql
-- Dentro de sp_AgregarItemPedido, paso 4:
SELECT TOP 1 @precio_unitario = monto
FROM PRECIOS
WHERE plato_id       = @plato_id
  AND vigencia_desde <= CAST(GETDATE() AS DATE)
  AND (vigencia_hasta IS NULL OR vigencia_hasta >= CAST(GETDATE() AS DATE))
ORDER BY vigencia_desde DESC, precio_id DESC
```

El conteo correcto del sistema es **18 Stored Procedures**.

---

**Desarrollado por:** SQLeaders S.A.  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — 2026**
