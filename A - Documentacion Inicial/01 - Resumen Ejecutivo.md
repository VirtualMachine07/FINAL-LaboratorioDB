# RESUMEN EJECUTIVO — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**        | **Descripción**                                                   |
|------------------|-------------------------------------------------------------------|
| **Documento**    | Resumen Ejecutivo — Sistema EsbirrosDB                            |
| **Proyecto**     | Sistema de Gestión de Pedidos — Bodegón Porteño                   |
| **Cliente**      | Bodegón Los Esbirros de Claudio                                   |
| **Desarrollado por** | SQLeaders S.A.                                                |
| **Versión**      | 1.0                                                               |
| **Fecha**        | Abril 2026                                                        |
| **Instituto**    | ISTEA                                                             |
| **Materia**      | Laboratorio de Administración de Bases de Datos                   |
| **Profesor**     | Carlos Alejandro Caraccio                                         |
| **Estado**       | Implementado y Funcional                                          |

---

## ¿QUÉ ES ESBIRROSDB?

**EsbirrosDB** es un sistema de gestión de base de datos diseñado a medida para el **Bodegón Los Esbirros de Claudio**, un restaurante tradicional porteño especializado en cocina a la leña, pastas artesanales y carnes. El sistema centraliza y digitaliza toda la operatoria del negocio: desde que el cliente hace su pedido hasta que se genera el cierre de caja del día.

El proyecto fue desarrollado por el equipo **SQLeaders S.A.** como trabajo práctico final de la materia **Laboratorio de Administración de Bases de Datos** en el **Instituto ISTEA**, a cargo del profesor **Carlos Alejandro Caraccio**, aplicando conceptos reales de diseño, normalización, seguridad y automatización sobre SQL Server.

---

## EL NEGOCIO: BODEGÓN LOS ESBIRROS DE CLAUDIO

Un bodegón porteño es un tipo de restaurante tradicional de Buenos Aires, caracterizado por su cocina casera, ambiente informal y trato cercano. El Bodegón Los Esbirros de Claudio opera actualmente con **una única sucursal**, aunque el dueño, Claudio, ya está planificando su expansión a nuevas ubicaciones en el mediano plazo. Por eso, el sistema fue diseñado desde el inicio para soportar **múltiples sucursales** sin necesidad de rediseño futuro.

El bodegón cuenta con:

- **Una sucursal activa**, con sus propias mesas y personal asignado, y estructura lista para escalar
- **Menú fijo** con 22 platos organizados en categorías: Entradas, Pastas, Carnes a la Leña, Guarniciones, Postres y Bebidas
- **Canales de venta** diferenciados: mostrador, delivery, mesa con QR y teléfono
- **Equipo de trabajo** compuesto por mozos, cocineros, cajeros, supervisores y gerentes, cada uno con distintos niveles de acceso al sistema

---

## ¿QUÉ PROBLEMA RESUELVE?

Antes de EsbirrosDB, el bodegón manejaba sus pedidos y operaciones de forma manual o con herramientas no integradas. Esto generaba:

- **Errores en pedidos** por falta de registro formal
- **Pérdida de información** sobre ventas y clientes
- **Imposibilidad de generar reportes** de rentabilidad o productos más vendidos
- **Sin control de stock**, no se sabía cuándo un plato se agotaba
- **Sin auditoría**, no quedaba registro de quién hizo qué cambio

EsbirrosDB resuelve todos estos problemas con una base de datos relacional centralizada, automatizada y segura.

---

## ¿QUÉ PUEDE HACER EL SISTEMA?

### Gestión de Pedidos
El núcleo del sistema. Un mozo puede crear un pedido para una mesa o canal de venta, agregar los platos que el cliente eligió, y el sistema calcula automáticamente el total. Luego el pedido avanza por un flujo de estados controlado:

**Pendiente → En Preparación → Listo → Entregado → Cerrado**

Cada transición es validada automáticamente: no se puede cerrar un pedido que no fue entregado, no se puede modificar un pedido ya cerrado, y los pedidos cancelados quedan registrados con su motivo.

### Control de Stock
El sistema lleva un stock simulado de cada plato. Cada vez que se agrega un ítem a un pedido, el stock se descuenta automáticamente. Si un plato llega a su nivel mínimo, el sistema genera una **notificación automática** para que el equipo pueda reabastecer a tiempo.

### Historial de Precios
Los precios no se modifican: cada cambio genera un nuevo registro con su fecha de vigencia. Esto permite reconstruir exactamente cuánto valía cada plato en cualquier momento pasado, garantizando trazabilidad financiera completa.

### Seguridad y Roles
Cada empleado accede al sistema con su propio usuario y contraseña (almacenada de forma segura). El sistema tiene **8 roles diferenciados** — desde el mozo que solo puede tomar pedidos, hasta el gerente que puede ver todos los reportes y acceder a la información de auditoría.

### Reportes y Dashboard
El sistema genera reportes automáticos de ventas diarias, platos más vendidos, rendimiento por canal de venta y análisis mensual. También cuenta con un **dashboard ejecutivo en tiempo real** que muestra el estado actual de todas las mesas y pedidos activos.

### Auditoría Completa
Cada acción importante queda registrada: quién creó un pedido, quién lo modificó, cuándo se cambió el estado. Esto permite detectar errores, resolver disputas y cumplir con requisitos de control interno.

### Carga Masiva de Clientes
El sistema soporta la incorporación masiva de clientes y sus domicilios mediante archivos CSV, lo que facilita la migración de datos existentes o la carga inicial de grandes volúmenes de información.

---

## ESTRUCTURA DE LA BASE DE DATOS

EsbirrosDB está compuesta por **12 tablas principales** y 4 tablas auxiliares, organizadas en módulos lógicos:

| **Módulo**           | **Tablas**                                                      |
|----------------------|-----------------------------------------------------------------|
| **Organización**     | SUCURSALES, MESAS, ROLES, EMPLEADOS                             |
| **Clientes**         | CLIENTES, DOMICILIOS                                            |
| **Menú y Precios**   | PLATOS, PRECIOS                                                 |
| **Pedidos**          | PEDIDOS, DETALLE_PEDIDOS, ESTADOS_PEDIDOS, CANALES_VENTAS       |
| **Automatización**   | STOCKS_SIMULADOS, NOTIFICACIONES, AUDITORIAS_SIMPLES            |
| **Reportes**         | REPORTES_GENERADOS                                              |

---

## COMPONENTES DEL SISTEMA

| **Componente**             | **Cantidad** | **Descripción**                                      |
|----------------------------|:------------:|------------------------------------------------------|
| Tablas principales         | 12           | Estructura central de la base de datos               |
| Tablas auxiliares          | 4            | Estructura auxiliar de la base de datos              |
| Stored Procedures          | 19           | Lógica de negocio encapsulada y reutilizable         |
| Triggers                   | 5            | Automatizaciones que se ejecutan sin intervención manual |
| Roles de seguridad         | 9            | Perfiles de acceso diferenciados por función         |
| Índices de performance     | 11           | Optimización de las consultas más frecuentes         |
| Vistas                     | 4            | Vistas consolidadas para consultas, monitoreo y dashboard |
| Stored Procedures de reporte | 5          | Generación automática de informes de negocio         |

---

## DECISIONES DE DISEÑO DESTACADAS

- **Sin combos ni promociones:** El menú del bodegón es simple. Se decidió no incorporar esa complejidad para mantener el sistema robusto y fiel a la realidad del cliente.
- **Historial de precios separado:** Los precios viven en su propia tabla para garantizar auditoría total sin perder datos históricos.
- **Stock como módulo independiente:** El control de stock es operativo y volátil; separarlo de la tabla de platos respeta el principio de responsabilidad única y facilita el mantenimiento.
- **Flujo de estados controlado:** Los pedidos solo pueden avanzar en orden, evitando inconsistencias operativas.

---

## EQUIPO DE DESARROLLO

**SQLeaders S.A.** — Proyecto Educativo ISTEA  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — Abril 2026**
