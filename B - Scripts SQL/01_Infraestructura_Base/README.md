# INFRAESTRUCTURA BASE - EsbirrosDB

**Orden de ejecución:** PASO 1  
**Dependencias:** Ninguna

## CONTENIDO DE LA CARPETA

### **Bundle_A1_BaseDatos_Estructura.sql**
- **Propósito:** Crear estructura completa de base de datos EsbirrosDB
- **Tiempo estimado:** 2-3 minutos
- **Contenido:**
  - 12 tablas principales
  - Relaciones y claves foráneas (14 FK en A1, 17 total)
  - Restricciones de integridad (CHECK, UNIQUE, NOT NULL)
  - DETALLES_PEDIDOS con `plato_id NOT NULL`

### **Bundle_A2_Indices_Datos.sql**
- **Propósito:** Optimización de performance + datos iniciales + menú del bodegón
- **Tiempo estimado:** 1-2 minutos
- **Contenido:**
  - 8+ índices de performance no-clustered
  - Datos de referencia: 8 estados, 5 canales, 7 roles
  - 2 sucursales (San Telmo, Palermo)
  - 22 platos del menú bodegón con precios 2026

## ORDEN DE EJECUCIÓN

1. **PRIMERO:** Bundle_A1_BaseDatos_Estructura.sql (conectar a `master`)
2. **SEGUNDO:** Bundle_A2_Indices_Datos.sql (conectar a `EsbirrosDB`)

## VALIDACIÓN

```sql
USE EsbirrosDB;

-- Verificar tablas creadas
SELECT COUNT(*) as TablesCreated
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
-- Esperado: 12 (tablas principales)

-- Verificar datos iniciales
SELECT COUNT(*) as Platos FROM PLATOS        -- Esperado: 22
SELECT COUNT(*) as Precios FROM PRECIOS       -- Esperado: 22
SELECT COUNT(*) as Roles FROM ROLES            -- Esperado: 7
SELECT COUNT(*) as Sucursales FROM SUCURSALES  -- Esperado: 2
```

## PRERREQUISITOS

- Conectar con usuario que tenga permisos `sysadmin` o `dbcreator`
- SQL Server 2019 o superior
- No requiere ningún bundle anterior
