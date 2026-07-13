# REGLAS DE NEGOCIO Y VALIDACIONES — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**        | **Descripción**                                     |
|------------------|-----------------------------------------------------|
| **Documento**    | Reglas de Negocio y Validaciones — Sistema EsbirrosDB |
| **Proyecto**     | Sistema de Gestión de Pedidos — Bodegón Porteño     |
| **Cliente**      | Bodegón Los Esbirros de Claudio                     |
| **Desarrollado por** | SQLeaders S.A.                                  |
| **Versión**      | 1.0                                                 |
| **Fecha**        | Abril 2026                                          |
| **Instituto**    | ISTEA                                               |
| **Materia**      | Laboratorio de Administración de Bases de Datos     |
| **Profesor**     | Carlos Alejandro Caraccio                           |
| **Estado**       | Implementado y Funcional                            |

---

## ¿QUÉ SON LAS REGLAS DE NEGOCIO?

Las reglas de negocio son las restricciones y políticas que definen cómo debe comportarse el sistema para reflejar fielmente la realidad operativa del Bodegón Los Esbirros de Claudio. No son decisiones técnicas arbitrarias: cada regla existe porque el negocio lo requiere así.

EsbirrosDB implementa estas reglas en tres niveles:
- **Nivel de base de datos:** constraints, índices y claves foráneas que el motor de SQL Server garantiza en todo momento
- **Nivel de stored procedures:** validaciones de lógica de negocio más complejas que se ejecutan al operar el sistema
- **Nivel de triggers:** automatizaciones que se disparan solas ante determinados eventos, sin intervención del usuario

---

## MÓDULO 1 — PERSONAL Y SUCURSALES

### Empleados
- Cada empleado pertenece a **una única sucursal** y tiene un **rol asignado obligatorio**
- El nombre de usuario de cada empleado es único en todo el sistema
- Las contraseñas se almacenan de forma segura (hasheadas), nunca en texto plano
- Solo empleados marcados como **activos** pueden tomar pedidos

### Sucursales y Mesas
- Cada sucursal tiene un nombre único
- Las mesas pertenecen a una única sucursal y su número es único dentro de ella (puede haber mesa 1 en dos sucursales distintas, pero no dos mesa 1 en la misma sucursal)
- Cada mesa tiene un **código QR único** para identificación
- La capacidad de una mesa siempre debe ser un número positivo

---

## MÓDULO 2 — MENÚ Y PRECIOS

### Menú del Bodegón
- Cada plato del menú tiene un nombre único
- Todo plato debe pertenecer a una de las categorías válidas: **Entradas, Pastas, Carnes a la Leña, Guarniciones, Postres o Bebidas**
- Solo los platos marcados como **activos** pueden agregarse a un pedido. Si un plato se discontinúa, se desactiva en lugar de eliminarse para preservar el historial

### Política de Precios — Regla Clave
Los precios en EsbirrosDB **nunca se modifican**: cada cambio de precio genera un nuevo registro con su fecha de vigencia, mientras el anterior se cierra. Esto garantiza que el sistema pueda responder en cualquier momento a la pregunta "¿cuánto costaba este plato el mes pasado?" con total precisión.

**Por ejemplo:** si el Bife de Chorizo costaba $8.500 en marzo y sube a $9.200 en abril, el sistema conserva ambos registros. Un pedido del 15 de marzo siempre mostrará $8.500, aunque se consulte hoy.

Otras validaciones de precios:
- Los precios no pueden ser negativos
- Todo precio debe tener fecha de inicio; la fecha de fin es opcional
- La fecha de fin siempre debe ser posterior a la de inicio

---

## MÓDULO 3 — PEDIDOS

### Creación de un Pedido
Todo pedido debe tener:
- Un **canal de venta** (Mostrador, Delivery, Mesa QR o Teléfono)
- Un **empleado responsable** que lo tomó (debe estar activo)
- Un **estado inicial** siempre igual a "Pendiente" (asignado automáticamente)

Según el canal, se aplican reglas adicionales:
- **Mesa QR / Mostrador:** requiere una mesa asignada de la sucursal
- **Delivery:** requiere cliente registrado y domicilio de entrega

### Flujo de Estados — Regla de Transición Secuencial
Los pedidos avanzan por estados en orden estricto. No se puede saltear pasos ni retroceder:

```
Pendiente → Confirmado → En Preparación → Listo → En Reparto → Entregado → Cerrado
```

El estado **Cancelado** es especial: puede aplicarse desde cualquier punto del flujo (siempre que el pedido no esté ya cerrado o cancelado), y el motivo se registra en el campo de observaciones del pedido. El motivo es **opcional** — si no se especifica, queda registrado como "Sin motivo especificado".

Esta secuencia se valida automáticamente — el sistema rechaza cualquier intento de cambiar el estado fuera del orden establecido.

### Ítems del Pedido
- Cada ítem referencia siempre un **plato individual** del menú (sin combos ni promociones)
- Los ítems solo pueden agregarse mientras el pedido esté en estado **Pendiente o Confirmado** — una vez que pasa a "En Preparación" o más, el pedido ya no puede modificarse
- La cantidad debe ser positiva
- El precio unitario se toma automáticamente del precio vigente al momento del pedido
- El subtotal se calcula automáticamente: `cantidad × precio_unitario`
- El **total del pedido** se recalcula automáticamente via trigger cada vez que se agrega, modifica o elimina un ítem
- No se puede cerrar un pedido que no tenga al menos un ítem

---

## MÓDULO 4 — CLIENTES Y DOMICILIOS

### Clientes
- El nombre es obligatorio; email, teléfono y documento son opcionales
- Si se registra un email, debe ser único en el sistema (no puede haber dos clientes con el mismo email)
- Si se registra un documento (DNI, CUIT, etc.), la combinación tipo + número debe ser única
- Un cliente puede tener **múltiples domicilios** registrados

> **Nota técnica relevante:** Para garantizar unicidad sobre campos opcionales (que pueden estar vacíos), se usan índices únicos filtrados en lugar de constraints UNIQUE convencionales. Esto es porque SQL Server no permite múltiples valores nulos en una columna con UNIQUE constraint estándar.

### Domicilios
- Todo domicilio pertenece a un cliente
- Calle, número, localidad y provincia son obligatorios
- Piso y departamento son opcionales
- Cada domicilio tiene un tipo: **Particular, Laboral, Temporal u Otro**
- Un cliente puede tener marcado un único **domicilio principal** (garantizado por índice filtrado)

---

## MÓDULO 5 — AUDITORÍA AUTOMÁTICA

El sistema registra automáticamente toda la actividad operativa crítica sin necesidad de intervención manual, a través de triggers:

| Evento | Trigger | Qué registra |
|--------|---------|-------------|
| Crear / modificar / eliminar un pedido | `tr_AuditoriaPedidos` | Tabla afectada, acción, estado anterior y nuevo, total |
| Agregar / modificar / eliminar un ítem | `tr_AuditoriaDetalle` | Pedido afectado, cantidad y subtotal antes y después |
| Cambio de estado del pedido | `tr_SistemaNotificaciones` | Genera notificación automática al área correspondiente |
| Agregar ítems a un pedido | `tr_ActualizarTotales` | Recalcula y actualiza el total del pedido |
| Ítems bajo stock mínimo | `tr_ValidarStock` | Descuenta stock y dispara notificación al área correspondiente |

Cada registro de auditoría incluye: tabla afectada, ID del registro, tipo de acción (INSERT/UPDATE/DELETE), fecha y hora automática, usuario del sistema y un resumen del cambio.

---

## RESUMEN DE VALIDACIONES POR CAPA

### Capa 1 — Base de datos (siempre activas, no se pueden saltear)
- 17 claves foráneas que garantizan integridad referencial entre todas las tablas
- Constraints CHECK para cantidades positivas, fechas coherentes y valores dentro de rangos válidos
- Índices únicos para nombres de catálogos, usuarios, QR de mesas y documentos de clientes

### Capa 2 — Stored Procedures (validaciones de lógica de negocio)
- `sp_CrearPedido` — valida canal, empleado activo, mesa disponible, cliente y domicilio según el canal
- `sp_AgregarItemPedido` — valida que el plato esté activo y que exista un precio vigente
- `sp_ActualizarEstadoPedido` — valida la secuencia de estados y rechaza transiciones inválidas
- `sp_CerrarPedido` / `sp_CancelarPedido` — controlan las transiciones finales del flujo

### Capa 3 — Triggers (automatizaciones sin intervención del usuario)
- Totales siempre actualizados
- Auditoría completa de todas las operaciones
- Notificaciones automáticas entre áreas (cocina, mozos, delivery, caja)
- Control de stock con alertas cuando se alcanza el mínimo

---

**Desarrollado por:** SQLeaders S.A.  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — Abril 2026**
