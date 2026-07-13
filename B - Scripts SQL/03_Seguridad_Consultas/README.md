# SEGURIDAD Y CONSULTAS - EsbirrosDB

**Orden de ejecución:** PASO 3  
**Dependencias:** 01_Infraestructura_Base + 02_Logica_Negocio completados

## CONTENIDO DE LA CARPETA

### **Bundle_C_Seguridad.sql**
- **Propósito:** Configuración completa del modelo de seguridad
- **Tiempo estimado:** 1-2 minutos
- **Requiere:** Permisos `sysadmin`
- **Crea:**
  - 7 roles de base de datos: `rol_administrador`, `rol_gerente`, `rol_cajero`,
    `rol_mesero`, `rol_cocinero`, `rol_delivery`, `rol_auditor`
  - Permisos granulares por ROLES (SELECT, INSERT, UPDATE, EXECUTE según función)
  - Usuarios sin login para aplicación: `app_esbirros_web`, `app_esbirros_reportes`,
    `app_esbirros_delivery`
  - SP de auditoría de seguridad: `sp_AuditoriaSeguridad`

### **Bundle_D_Consultas_Basicas.sql**
- **Propósito:** Vistas y consultas base del sistema
- **Tiempo estimado:** 1 minuto
- **Crea:** Vistas base (`vw_PedidosCompletos`, etc.) y SPs de consulta frecuente
- `sp_ConsultarPedidosPorEstado` usa STRING_AGG para agregar platos del PEDIDOS

## ORDEN DE EJECUCIÓN

1. Bundle_C_Seguridad.sql
2. Bundle_D_Consultas_Basicas.sql

## VALIDACIÓN

```sql
USE EsbirrosDB;

-- Verificar roles de seguridad
SELECT COUNT(*) as Roles
FROM sys.database_principals
WHERE type = 'R' AND name LIKE 'rol_%'
-- Esperado: 7

-- Verificar usuarios de aplicación
SELECT name FROM sys.database_principals
WHERE name LIKE 'app_esbirros%'
-- Esperado: app_esbirros_web, app_esbirros_reportes, app_esbirros_delivery

-- Verificar vistas base
SELECT COUNT(*) as Vistas
FROM sys.views
WHERE name LIKE 'vw_%'
-- Esperado: >= 2
```

## MODELO DE SEGURIDAD

| **ROLES** | **Tablas principales** | **SPs** |
|---------|----------------------|---------|
| `rol_administrador` | Full (SELECT/INSERT/UPDATE/DELETE) | EXECUTE todos |
| `rol_gerente` | SELECT all, INSERT/UPDATE pedidos | EXECUTE reportes |
| `rol_cajero` | SELECT pedidos, UPDATE estado | EXECUTE sp_Cerrar |
| `rol_mesero` | SELECT menú, INSERT pedidos | EXECUTE sp_Crear/Agregar |
| `rol_cocinero` | SELECT pedidos, UPDATE estado | EXECUTE sp_Actualizar |
| `rol_delivery` | SELECT delivery, UPDATE estado | EXECUTE sp_Actualizar |
| `rol_auditor` | SELECT only (todas las tablas) | — |
