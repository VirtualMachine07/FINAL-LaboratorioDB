# CATÁLOGO DE TRIGGERS — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**            | **Descripción**                                     |
|----------------------|-----------------------------------------------------|
| **Documento**        | Catálogo de Triggers — EsbirrosDB                   |
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

## RESUMEN DE TRIGGERS

| **Trigger**                 | **Bundle** | **Tabla**         | **Evento**                  | **Función principal**                              |
|-----------------------------|------------|-------------------|-----------------------------|----------------------------------------------------|
| `tr_ActualizarTotales`      | E1         | DETALLES_PEDIDOS  | AFTER INSERT, UPDATE, DELETE| Mantiene `PEDIDOS.total` siempre actualizado       |
| `tr_AuditoriaPedidos`       | E1         | PEDIDOS           | AFTER INSERT, UPDATE, DELETE| Registra toda la actividad sobre pedidos           |
| `tr_AuditoriaDetalle`       | E1         | DETALLES_PEDIDOS  | AFTER INSERT, UPDATE, DELETE| Registra toda la actividad sobre ítems de pedidos  |
| `tr_ValidarStock`           | E2         | DETALLES_PEDIDOS  | AFTER INSERT                | Descuenta stock y genera alerta si hay faltante    |
| `tr_SistemaNotificaciones`  | E2         | PEDIDOS           | AFTER UPDATE                | Genera notificaciones automáticas por cambio de estado |

---

## TRIGGER 1 — `tr_ActualizarTotales`
**Bundle:** E1 (`Bundle_E1_Triggers_Principales.sql`)

### Especificación técnica

| **Atributo**     | **Valor**                            |
|------------------|--------------------------------------|
| **Tabla**        | `DETALLES_PEDIDOS`                   |
| **Evento**       | `AFTER INSERT, UPDATE, DELETE`       |
| **Tablas que modifica** | `PEDIDOS` (campo `total`)     |

### Propósito
Garantiza que el campo `total` de la tabla `PEDIDOS` refleje siempre la suma exacta de todos los subtotales de sus ítems. Se ejecuta automáticamente sin ninguna acción manual.

### Lógica de ejecución (paso a paso)

1. **Identifica los pedidos afectados:** recolecta los `pedido_id` de las filas en las tablas virtuales `inserted` y `deleted`, que contienen respectivamente las filas nuevas/modificadas y las eliminadas.
2. **Recalcula el total por pedido:** para cada pedido afectado, suma todos los `subtotal` vigentes en `DETALLES_PEDIDOS`.
3. **Actualiza `PEDIDOS.total`:** aplica el resultado con un UPDATE. Si el pedido quedó sin ítems, el total queda en `0`.

### Cuándo se dispara
- Al agregar un ítem con `sp_AgregarItemPedido`
- Al modificar la cantidad o precio de un ítem existente
- Al eliminar un ítem del pedido

### Resultado observable
El campo `PEDIDOS.total` se actualiza instantáneamente después de cualquier cambio en `DETALLES_PEDIDOS`, sin que el usuario ni los SPs necesiten hacer un UPDATE manual.

---

## TRIGGER 2 — `tr_AuditoriaPedidos`
**Bundle:** E1 (`Bundle_E1_Triggers_Principales.sql`)

### Especificación técnica

| **Atributo**     | **Valor**                            |
|------------------|--------------------------------------|
| **Tabla**        | `PEDIDOS`                            |
| **Evento**       | `AFTER INSERT, UPDATE, DELETE`       |
| **Tablas que modifica** | `AUDITORIAS_SIMPLES`          |

### Propósito
Registra automáticamente en `AUDITORIAS_SIMPLES` toda la actividad sobre la tabla `PEDIDOS`: creación de nuevos pedidos, cambios de estado y totales, y eliminaciones. Garantiza trazabilidad completa sin intervención manual.

### Lógica de ejecución (por tipo de operación)

#### INSERT (nuevo pedido creado)
Detecta que hay filas en `inserted` pero no en `deleted`. Registra:
- `accion = 'INSERT'`
- `datos_resumen = 'Nuevo PEDIDOS - Canal: [nombre canal], Estado: [estado inicial]'`

#### UPDATE (cambio de estado o total)
Detecta filas en ambas tablas virtuales. Solo registra si el estado o el total cambiaron:
- `accion = 'UPDATE'`
- `datos_resumen = 'Estado: [estado anterior] → [estado nuevo], Total: $[total]'`

#### DELETE (pedido eliminado)
Detecta filas solo en `deleted`:
- `accion = 'DELETE'`
- `datos_resumen = 'PEDIDOS eliminado - Total: $[total]'`

### Resultado observable
Cada operación sobre un pedido genera una fila en `AUDITORIAS_SIMPLES` con timestamp automático (`GETDATE()`) y usuario del sistema (`SYSTEM_USER`). Permite reconstruir el historial completo de cualquier pedido.

**Ejemplo de registros generados para un pedido completo:**
```
INSERT | pedido_id=10011 | 'Nuevo PEDIDOS - Canal: MESAS QR, Estado: Pendiente'
UPDATE | pedido_id=10011 | 'Estado: Pendiente → Confirmado, Total: $0'
UPDATE | pedido_id=10011 | 'Estado: Confirmado → En Preparación, Total: $3200'
UPDATE | pedido_id=10011 | 'Estado: En Preparación → Listo, Total: $3200'
UPDATE | pedido_id=10011 | 'Estado: Listo → Cerrado, Total: $3200'
```

---

## TRIGGER 3 — `tr_AuditoriaDetalle`
**Bundle:** E1 (`Bundle_E1_Triggers_Principales.sql`)

### Especificación técnica

| **Atributo**     | **Valor**                            |
|------------------|--------------------------------------|
| **Tabla**        | `DETALLES_PEDIDOS`                   |
| **Evento**       | `AFTER INSERT, UPDATE, DELETE`       |
| **Tablas que modifica** | `AUDITORIAS_SIMPLES`          |

### Propósito
Registra automáticamente en `AUDITORIAS_SIMPLES` toda la actividad sobre los ítems de los pedidos: qué se agregó, qué se modificó y qué se eliminó, con cantidades y subtotales.

### Lógica de ejecución (por tipo de operación)

#### INSERT (ítem agregado)
- `accion = 'INSERT'`
- `datos_resumen = 'Ítem agregado al PEDIDOS [id] - Cantidad: [N], Subtotal: $[X]'`

#### UPDATE (ítem modificado)
Solo registra si cambió la cantidad o el subtotal:
- `accion = 'UPDATE'`
- `datos_resumen = 'PEDIDOS=[id] Cant: [antes]→[después] Subtotal: $[antes]→$[después]'`

#### DELETE (ítem eliminado)
- `accion = 'DELETE'`
- `datos_resumen = 'Ítem eliminado del PEDIDOS [id] - Subtotal: $[X]'`

### Resultado observable
Complementa a `tr_AuditoriaPedidos`. Mientras ese trigger registra los cambios del pedido como un todo, este registra el detalle de cada ítem individualmente.

---

## TRIGGER 4 — `tr_ValidarStock`
**Bundle:** E2 (`Bundle_E2_Control_Avanzado.sql`)

### Especificación técnica

| **Atributo**     | **Valor**                                   |
|------------------|---------------------------------------------|
| **Tabla**        | `DETALLES_PEDIDOS`                          |
| **Evento**       | `AFTER INSERT`                              |
| **Tablas que modifica** | `STOCKS_SIMULADOS`, `NOTIFICACIONES` |

### Propósito
Gestiona el inventario simulado del bodegón. Ante cada nuevo ítem agregado a un pedido, descuenta las unidades del stock y, si el stock disponible es insuficiente para cubrir la cantidad pedida, genera una notificación de alerta crítica para la cocina.

### Lógica de ejecución (paso a paso)

1. **Detecta platos sin stock suficiente:** compara la cantidad pedida (en `inserted`) con el `stock_disponible` en `STOCKS_SIMULADOS`. Si hay platos donde `stock_disponible < cantidad`, los identifica.

2. **Genera notificación CRÍTICA (si aplica):** para cada plato con stock insuficiente, inserta en `NOTIFICACIONES`:
   - `tipo = 'STOCK_BAJO'`
   - `prioridad = 'CRITICA'`
   - `usuario_destino = 'COCINA'`
   - `mensaje` incluye el nombre del plato, el stock actual y la cantidad pedida

3. **Descuenta el stock:** independientemente de si hay o no alerta, actualiza `STOCKS_SIMULADOS` restando la cantidad pedida y registrando la fecha de actualización.

> **Nota importante:** El trigger descuenta el stock incluso si hay alerta de insuficiencia, ya que el sistema es de stock **simulado**. La alerta avisa a cocina del problema, pero no bloquea el pedido.

### Resultado observable
- El campo `stock_disponible` en `STOCKS_SIMULADOS` se reduce con cada ítem pedido.
- Si el stock cae por debajo de `stock_minimo`, aparece una notificación crítica consultable con `sp_ConsultarNotificaciones @usuario_destino = 'COCINA'`.

---

## TRIGGER 5 — `tr_SistemaNotificaciones`
**Bundle:** E2 (`Bundle_E2_Control_Avanzado.sql`)

### Especificación técnica

| **Atributo**     | **Valor**                            |
|------------------|--------------------------------------|
| **Tabla**        | `PEDIDOS`                            |
| **Evento**       | `AFTER UPDATE`                       |
| **Tablas que modifica** | `NOTIFICACIONES`              |

### Propósito
Genera notificaciones automáticas entre las distintas áreas del bodegón (cocina, mozos, caja, delivery) cada vez que un pedido cambia de estado. Implementa el sistema de comunicación interna sin intervención manual.

### Lógica de ejecución (por transición de estado)

| **Transición**                        | **Notificación generada**                                  | **Prioridad** | **Destinatario** |
|---------------------------------------|------------------------------------------------------------|---------------|------------------|
| `→ En Preparación`                    | "Nuevo Pedido para Preparar" — con número de mesa o delivery | ALTA          | COCINA           |
| `→ Listo`                             | "Pedido Listo para Entregar" — con número de mesa          | ALTA          | MOZOS            |
| `→ En Reparto`                        | "Pedido en Camino" — total del pedido                      | ALTA          | DELIVERY         |
| `→ Cerrado`                           | "Pedido Completado" — total final                          | NORMAL        | CAJA             |
| `→ Cancelado`                         | "Pedido Cancelado" — con motivo                            | CRITICA       | CAJA             |
| `→ Cancelado`                         | "Pedido Cancelado — Dejar de preparar"                     | CRITICA       | COCINA           |

### Detalle de detección de transiciones
El trigger compara el `estado_id` de las tablas virtuales `inserted` (estado nuevo) y `deleted` (estado anterior) unidas por `pedido_id`. Solo genera la notificación si el pedido efectivamente **cambió** a ese estado (no si ya estaba en él).

### Resultado observable
Cada cambio de estado relevante genera entre 1 y 2 notificaciones en `NOTIFICACIONES`, consultables con `sp_ConsultarNotificaciones`. El campo `usuario_destino` permite que cada área vea solo sus propias alertas.

**Ejemplo de notificaciones para un pedido completo:**
```
→ En Preparación : COCINA  (ALTA)    "Nuevo Pedido para Preparar - Mesa 1. Total: $3200"
→ Listo          : MOZOS   (ALTA)    "Pedido #10011 de la Mesa 1 está listo. Total: $3200"
→ Cerrado        : CAJA    (NORMAL)  "Pedido #10011 cerrado exitosamente. Total: $3200"
```

---

## TABLAS AUXILIARES CREADAS POR LOS TRIGGERS

| **Tabla**          | **Creada por**          | **Quién escribe en ella**                         |
|--------------------|-------------------------|---------------------------------------------------|
| `AUDITORIAS_SIMPLES`| `tr_AuditoriaPedidos` (Bundle E1) | `tr_AuditoriaPedidos`, `tr_AuditoriaDetalle` |
| `STOCKS_SIMULADOS` | `tr_ValidarStock` (Bundle E2)     | `tr_ValidarStock`                           |
| `NOTIFICACIONES`   | `tr_SistemaNotificaciones` (Bundle E2) | `tr_SistemaNotificaciones`, `tr_ValidarStock` |

> Estas tablas se crean automáticamente la primera vez que se ejecuta el Bundle correspondiente, si no existen aún.

---

**Desarrollado por:** SQLeaders S.A.  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — 2026**
