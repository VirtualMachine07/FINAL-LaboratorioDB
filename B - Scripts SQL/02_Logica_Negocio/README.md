# LÓGICA DE NEGOCIO - EsbirrosDB

**Orden de ejecución:** PASO 2  
**Dependencias:** 01_Infraestructura_Base completado

## CONTENIDO DE LA CARPETA

### **Bundle_B1_Pedidos_Core.sql**
- **Propósito:** Stored procedure principal de creación de pedidos
- **Tiempo estimado:** 1 minuto
- **Crea:** `sp_CrearPedido`
- **Función:** Valida SUCURSALES, canal, MESAS/CLIENTES según canal, crea PEDIDOS en estado Pendiente

### **Bundle_B2_Items_Calculos.sql**
- **Propósito:** Gestión de ítems de PEDIDOS y cálculos de totales
- **Tiempo estimado:** 1 minuto
- **Crea:** `sp_AgregarItemPedido`, `sp_CalcularTotalPedido`
- `@plato_id` es obligatorio (NOT NULL).

### **Bundle_B3_Estados_Finalizacion.sql**
- **Propósito:** Gestión del ciclo de vida del PEDIDOS
- **Tiempo estimado:** 1 minuto
- **Crea:** `sp_CerrarPedido`, `sp_CancelarPedido`, `sp_ActualizarEstadoPedido`

## ORDEN DE EJECUCIÓN

1. Bundle_B1_Pedidos_Core.sql
2. Bundle_B2_Items_Calculos.sql
3. Bundle_B3_Estados_Finalizacion.sql

## VALIDACIÓN

```sql
USE EsbirrosDB;

SELECT COUNT(*) as SPs_Logica
FROM sys.objects
WHERE type = 'P' AND name IN (
    'sp_CrearPedido','sp_AgregarItemPedido','sp_CalcularTotalPedido',
    'sp_CerrarPedido','sp_CancelarPedido'
)
-- Esperado: 5
```

## FLUJO DE USO

```sql
-- 1. Crear PEDIDOS
EXEC sp_CrearPedido @canal_id=1, @mesa_id=1,
    @tomado_por_empleado_id=1, @cant_comensales=4,
    @pedido_id=@id OUTPUT, @mensaje=@msg OUTPUT

-- 2. Agregar ítems
EXEC sp_AgregarItemPedido @pedido_id=@id, @plato_id=9,
    @cantidad=2, @detalle_id=@det OUTPUT, @mensaje=@msg OUTPUT

-- 3. Cerrar PEDIDOS
EXEC sp_CerrarPedido @pedido_id=@id, @mensaje=@msg OUTPUT
```
