# MODELO ENTIDAD-RELACIÓN — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**         | **Descripción**                                  |
|-------------------|--------------------------------------------------|
| **Documento**     | Modelo Entidad-Relación (DER) — EsbirrosDB       |
| **Proyecto**      | Sistema de Gestión de Bodegón Porteño            |
| **CLIENTES**       | Bodegón Los Esbirros de Claudio                  |
| **Instituto**     | ISTEA                                            |
| **Materia**       | Laboratorio de Administración de Bases de Datos  |
| **Profesor**      | Carlos Alejandro Caraccio                        |
| **Versión**       | 1.0                                              |
| **Estado**        | Implementado y Funcional                         |

---

## **RESUMEN EJECUTIVO**

### Objetivo del Documento
Presenta el Modelo Entidad-Relación del sistema **EsbirrosDB**, diseñado para la gestión operativa del **Bodegón Los Esbirros de Claudio**. Documenta las relaciones entre entidades y la arquitectura visual del modelo de datos.

### Componentes del Modelo

| **Métrica**           | **Valor** |
|-----------------------|-----------|
| Entidades (tablas A1) | 12        |
| Tablas auxiliares     | 4 (AUDITORIAS_SIMPLES, STOCKS_SIMULADOS, NOTIFICACIONES, REPORTES_GENERADOS) |
| **Total tablas**      | **16**    |
| Relaciones FK         | 17        |
| Módulos funcionales   | 7         |

### Decisiones de Diseño
- **`DETALLES_PEDIDOS` directo:** `plato_id NOT NULL`, cada ítem referencia un PLATOS individual
- **Contexto de negocio:** bodegón porteño (cocina a la leña, pastas, carnes)

---

## **DIAGRAMA ENTIDAD-RELACIÓN COMPLETO**

> Renderizable en [mermaid.live](https://mermaid.live) o en cualquier editor compatible con Mermaid (VS Code + extensión, GitHub, Notion, etc.)

```mermaid
erDiagram

    %% ─── CATÁLOGOS ───────────────────────────────────────────

    SUCURSALES {
        int     sucursal_id  PK
        nvarchar nombre      UK
        nvarchar direccion
    }

    CANALES_VENTAS {
        int     canal_id  PK
        nvarchar nombre   UK
    }

    ESTADOS_PEDIDOS {
        int     estado_id PK
        nvarchar nombre   UK
        int     orden     UK
    }

    ROLES {
        int     rol_id      PK
        nvarchar nombre     UK
        nvarchar descripcion
    }

    %% ─── PERSONAL Y UBICACIÓN ────────────────────────────────

    MESAS {
        int     mesa_id     PK
        int     numero
        int     capacidad
        int     sucursal_id FK
        nvarchar qr_token   UK
        bit     activa
    }

    EMPLEADOS {
        int     empleado_id   PK
        nvarchar nombre
        nvarchar usuario      UK
        nvarchar hash_password
        int     rol_id        FK
        int     sucursal_id   FK
        bit     activo
    }

    %% ─── CLIENTES Y DOMICILIOS ───────────────────────────────

    CLIENTES {
        int     cliente_id PK
        nvarchar nombre
        nvarchar telefono
        nvarchar email     "UIX filtrado"
        nvarchar doc_tipo
        nvarchar doc_nro   "UIX filtrado"
    }

    DOMICILIOS {
        int     domicilio_id  PK
        int     cliente_id    FK
        nvarchar calle
        nvarchar numero
        nvarchar piso
        nvarchar depto
        nvarchar localidad
        nvarchar provincia
        nvarchar observaciones
        bit     es_principal
        nvarchar tipo_domicilio
    }

    %% ─── PRODUCTOS Y PRECIOS ─────────────────────────────────


    PLATOS {
        int     plato_id  PK
        nvarchar nombre   UK
        nvarchar categoria
        bit     activo
    }

    PRECIOS {
        int     precio_id      PK
        int     plato_id       FK
        date    vigencia_desde
        date    vigencia_hasta
        decimal monto
    }

    %% ─── PEDIDOS ─────────────────────────────────────────────

    PEDIDOS {
        int     pedido_id                 PK
        datetime fecha_pedido
        datetime fecha_entrega
        int     canal_id                  FK
        int     mesa_id                   FK
        int     cliente_id                FK
        int     domicilio_id              FK
        int     cant_comensales
        int     estado_id                 FK
        int     tomado_por_empleado_id    FK
        int     entregado_por_empleado_id FK
        decimal total
        nvarchar observaciones
    }

    DETALLES_PEDIDOS {
        int     detalle_id      PK
        int     pedido_id       FK
        int     plato_id        FK
        int     cantidad
        decimal precio_unitario
        decimal subtotal
    }

    %% ─── TABLAS AUXILIARES (Bundles E1, E2, R1) ──────────────

    AUDITORIAS_SIMPLES {
        int      auditoria_id    PK
        nvarchar tabla_afectada
        int      registro_id
        varchar  accion
        datetime fecha_auditoria
        varchar  usuario_sistema
        nvarchar datos_resumen
    }

    STOCKS_SIMULADOS {
        int      plato_id             PK "FK"
        int      stock_disponible
        int      stock_minimo
        datetime ultima_actualizacion
    }

    NOTIFICACIONES {
        int      notificacion_id PK
        varchar  tipo
        nvarchar titulo
        nvarchar mensaje
        int      pedido_id       FK
        int      mesa_id         FK
        varchar  prioridad
        datetime fecha_creacion
        bit      leida
        datetime fecha_lectura
        varchar  usuario_destino
    }

    REPORTES_GENERADOS {
        int      reporte_id       PK
        nvarchar tipo_reporte
        datetime fecha_generacion
        date     fecha_reporte
        int      sucursal_id      FK
        nvarchar datos_json
        nvarchar ejecutado_por
        nvarchar estado
        nvarchar observaciones
    }

    %% ─── RELACIONES ──────────────────────────────────────────

    SUCURSALES      ||--o{ MESAS      : "tiene mesas"
    SUCURSALES      ||--o{ EMPLEADOS  : "tiene empleados"
    ROLES           ||--o{ EMPLEADOS  : "asigna ROLES"

    CLIENTES       ||--o{ DOMICILIOS : "tiene domicilios"
    CLIENTES       |o--o{ PEDIDOS    : "realiza"
    DOMICILIOS     |o--o{ PEDIDOS    : "dirección de entrega"

    CANALES_VENTAS   ||--o{ PEDIDOS    : "canal de venta"
    ESTADOS_PEDIDOS ||--o{ PEDIDOS    : "estado actual"
    MESAS          |o--o{ PEDIDOS    : "MESAS asignada"

    EMPLEADOS      ||--o{ PEDIDOS    : "tomado por"
    EMPLEADOS      |o--o{ PEDIDOS    : "entregado por"

    PEDIDOS        ||--o{ DETALLES_PEDIDOS : "contiene ítems"

    PLATOS         ||--o{ DETALLES_PEDIDOS : "incluido en PEDIDOS"
    PLATOS         ||--o{ PRECIOS         : "historial de precios"

    %% Relaciones tablas auxiliares
    PLATOS           ||--o| STOCKS_SIMULADOS     : "stock por PLATOS"
    PEDIDOS          |o--o{ NOTIFICACIONES     : "genera notificación"
    MESAS            |o--o{ NOTIFICACIONES     : "notifica MESAS"
    SUCURSALES        |o--o{ REPORTES_GENERADOS : "reporte por SUCURSALES"
```

---

## **DESCRIPCIÓN DE MÓDULOS**

### Módulo 1 — Catálogos Base
| Tabla | Función | Cardinalidad clave |
|-------|-----|--------------------|
| `SUCURSALES` | Hub central del sistema | 1:N con MESAS y EMPLEADOS |
| `CANALES_VENTAS` | Catalog de canales (MESAS QR, Delivery, etc.) | 1:N con PEDIDOS |
| `ESTADOS_PEDIDOS` | Estados ordenados del flujo | 1:N con PEDIDOS |
| `ROLES` | Roles del personal | 1:N con EMPLEADOS |

### Módulo 2 — Personal y Ubicación
| Tabla | Función | Cardinalidad clave |
|-------|-----|--------------------|
| `MESAS` | Mesas físicas con QR | N:1 con SUCURSALES |
| `EMPLEADOS` | Personal con autenticación | N:1 con ROLES y SUCURSALES |

### Módulo 3 — Clientes
| Tabla | Función | Cardinalidad clave |
|-------|-----|--------------------|
| `CLIENTES` | Datos del cliente | 1:N con DOMICILIOS |
| `DOMICILIOS` | Direcciones de entrega | N:1 con CLIENTES |

### Módulo 4 — Productos y Precios
| Tabla | Función | Cardinalidad clave |
|-------|-----|--------------------|
| `PLATOS` | Catálogo del menú (pastas, carnes, bebidas…) | 1:N con PRECIOS, DETALLES_PEDIDOS |
| `PRECIOS` | Historial de precios con vigencia temporal | N:1 con PLATOS |

### Módulo 5 — Pedidos
| Tabla | Función | Cardinalidad clave |
|-------|-----|--------------------|
| `PEDIDOS` | Entidad central de transacciones | N:1 con múltiples catálogos |
| `DETALLES_PEDIDOS` | Líneas de pedido (siempre un PLATOS) | N:1 con PEDIDOS y PLATOS |

### Módulo 6 — Auditoría
| Tabla | Función | Cardinalidad clave |
|-------|-----|--------------------|
| `AUDITORIAS_SIMPLES` | Log simplificado de INSERT/UPDATE/DELETE sobre las entidades principales | — (sin FK, registro independiente) |

### Módulo 7 — Reportes
| Tabla | Función | Cardinalidad clave |
|-------|-----|--------------------|
| `REPORTES_GENERADOS` | Registro de reportes ejecutados | N:1 con SUCURSALES |

### Tablas auxiliares (creadas por Bundles E1/E2/R1)
| Tabla | Bundle | Propósito | FK |
|-------|--------|-----------|----|
| `AUDITORIAS_SIMPLES` | E1 | Log simplificado de INSERT/UPDATE/DELETE | — |
| `STOCKS_SIMULADOS` | E2 | Inventario simulado por PLATOS | `plato_id` → PLATOS |
| `NOTIFICACIONES` | E2 | Alertas automáticas de estado de pedidos | `pedido_id` → PEDIDOS, `mesa_id` → MESAS |
| `REPORTES_GENERADOS` | R1 | Registro de reportes generados por SPs | `sucursal_id` → SUCURSALES |

---

## **FLUJOS DE DATOS CRÍTICOS**

### Flujo 1 — PEDIDOS en Salón (MESAS QR)
```
CANALES_VENTAS (MESAS QR) → PEDIDOS → DETALLES_PEDIDOS → PLATOS → PRECIOS
                    ↗ MESAS ↗ EMPLEADOS (mozo)
```

### Flujo 2 — PEDIDOS Delivery
```
CANALES_VENTAS (Delivery) → PEDIDOS → DETALLES_PEDIDOS → PLATOS
                      ↗ CLIENTES → DOMICILIOS
                      ↗ EMPLEADOS (tomado) + EMPLEADOS (entregado)
```

### Flujo 3 — Trazabilidad
```
PEDIDOS (UPDATE estado) → tr_AuditoriaPedidos → AUDITORIAS_SIMPLES
                       → tr_SistemaNotificaciones → NOTIFICACIONES
```

---

**Documento generado por SQLeaders S.A.**  
**Versión: 1.0 — Adaptación EsbirrosDB — 2026**
