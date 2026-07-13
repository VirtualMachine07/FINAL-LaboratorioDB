# 06 — Carga Masiva de Datos

**Bundle:** `Bundle_F_Carga_Masiva.sql`  
**Versión definitiva:** 3.0  
**Propósito:** Poblar EsbirrosDB con 10,000+ registros de prueba para testing, análisis de performance y validación del sistema completo.

---

## Contenido generado

| Entidad | Cantidad |
|---------|----------|
| Clientes | 3,000 |
| Domicilios | 3,000 |
| Pedidos | 10,000 |
| Detalles de pedidos | ~30,000 |
| **Total estimado** | **~43,000 registros** |

**Distribución de canales:**
- 50% Mostrador
- 30% Delivery
- 15% MESAS QR
- 5% Telefono

---

## Prerequisitos

Ejecutar **todos** estos bundles antes:

```
Bundle_A1  → Estructura de tablas
Bundle_A2  → Índices y datos maestros (catálogos, menú)
Bundle_B1  → sp_CrearPedido
Bundle_B2  → sp_AgregarItemPedido, sp_CalcularTotalPedido
Bundle_B3  → sp_CerrarPedido, sp_CancelarPedido, sp_ActualizarEstadoPedido
Bundle_C   → Roles y seguridad
Bundle_D   → Consultas básicas y vistas
Bundle_E1  → Triggers de totales y auditoría (OBLIGATORIO)
Bundle_E2  → Triggers de stock y notificaciones
```

---

## Comportamiento

- **Limpia** datos previos de carga masiva (pedidos, clientes con `cliente_id > 19`, domicilios, notificaciones, auditorías)
- **Preserva** empleados, catálogos y datos de sistema
- Los totales de cada pedido son calculados automáticamente por el trigger `tr_ActualizarTotales`
- Todos los strings van **sin tildes** para compatibilidad de encoding
- El canal `Telefono` (sin tilde) coincide exactamente con el valor cargado en Bundle_A2

---

## Tiempo estimado

30–60 segundos en SQL Server local.
