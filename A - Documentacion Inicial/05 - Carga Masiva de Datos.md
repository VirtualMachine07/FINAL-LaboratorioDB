# CARGA MASIVA DE DATOS — SISTEMA ESBIRROSDB

## **INFORMACIÓN DEL DOCUMENTO**

| **Campo**        | **Descripción**                                     |
|------------------|-----------------------------------------------------|
| **Documento**    | Carga Masiva de Datos — Sistema EsbirrosDB          |
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

## ¿QUÉ ES LA CARGA MASIVA?

La carga masiva es el proceso de insertar grandes volúmenes de datos en la base de datos de forma automática, sin hacerlo registro por registro. Sirve para simular un entorno real de producción con miles de clientes y pedidos, lo que permite probar el rendimiento del sistema, validar que los triggers y stored procedures funcionan a escala, y generar reportes con datos representativos.

EsbirrosDB incluye **dos métodos** de carga masiva, cada uno con su propio propósito:

---

## MÉTODO 1 — Bundle F: Carga masiva con T-SQL puro

**Archivo:** `B - Scripts SQL/07_Carga_Masiva_Datos/Bundle_F_Carga_Masiva.sql`

### ¿Qué genera?

| Tabla | Registros generados | Origen |
|-------|-------------------|--------|
| `CLIENTES` | 3.000 | INSERT directo |
| `DOMICILIOS` | 3.000 | INSERT directo (1 por cliente) |
| `PEDIDOS` | 10.000 | INSERT directo (WHILE loop) |
| `DETALLES_PEDIDOS` | ~30.000 | INSERT directo (2 a 4 ítems por pedido) |
| `AUDITORIAS_SIMPLES` | ~50.000 | Automático por triggers (ver detalle abajo) |
| `NOTIFICACIONES` | 0 | No se generan (pedidos insertados con estado final) |
| **Total estimado** | **~96.000 registros** | |

#### ¿Por qué ~50.000 registros de auditoría?

Los triggers activos generan registros en `AUDITORIAS_SIMPLES` de forma automática en tres momentos:

1. **`tr_AuditoriaPedidos` — INSERT:** al insertar cada pedido (uno por uno en el WHILE loop) → **10.000 registros**
2. **`tr_AuditoriaDetalle` — INSERT:** al insertar todos los ítems en un solo batch → **~30.000 registros**
3. **`tr_ActualizarTotales` + `tr_AuditoriaPedidos` — UPDATE:** al insertar los ítems, el trigger recalcula el total de cada pedido, lo que dispara el trigger de auditoría de pedidos por UPDATE → **~10.000 registros**

> Las **notificaciones** no se generan porque `tr_SistemaNotificaciones` solo dispara ante cambios de estado vía UPDATE. El Bundle F inserta los pedidos directamente con su estado final (Cerrado/Entregado), sin pasar por transiciones reales.

### ¿Cómo distribuye los pedidos?

| Canal de venta | Proporción |
|---------------|-----------|
| Mostrador     | 50%       |
| Delivery      | 30%       |
| Mesa QR       | 15%       |
| Teléfono      | 5%        |

### Rango de DNI utilizado

Los clientes generados usan DNIs del rango **30.000.001 al 30.003.000**. Este rango fue elegido para no colisionar con datos reales o con los empleados ya cargados en el sistema.

### ¿Cómo cambiar el rango de DNI?

Dentro del script, buscar la línea:

```sql
30000000 + @i
```

Por ejemplo, para usar DNIs del rango 25.000.001 al 25.003.000, cambiar a:

```sql
25000000 + @i
```

> ⚠️ **Importante:** el nuevo rango no debe superponerse con DNIs ya existentes en la tabla `CLIENTES`, ya que hay un índice filtrado de unicidad sobre `doc_nro`.

### ¿Cómo ejecutarlo?

1. Asegurarse de haber ejecutado previamente los Bundles A1, A2, B1, B2, B3, C, D, E1 y E2
2. Abrir el archivo en SSMS
3. Verificar que la base seleccionada sea `EsbirrosDB`
4. Ejecutar (F5)
5. Tiempo estimado: **30 a 60 segundos**

### ¿Qué pasa con los datos anteriores?

El script **limpia automáticamente** los datos de pruebas anteriores antes de insertar:
- Elimina todos los registros de `DETALLES_PEDIDOS`, `PEDIDOS`, `DOMICILIOS` y `NOTIFICACIONES`
- Elimina clientes con `cliente_id > 19` (preserva empleados y usuarios del sistema)
- **No toca** los catálogos (platos, estados, roles, canales, etc.)

---

## MÉTODO 2 — Bundle H: Carga masiva con BULK INSERT desde CSV

**Archivos:**
- `B - Scripts SQL/08_BulkInsert_Clientes_Domicilios/genera_csv_clientes_domicilios.py`
- `B - Scripts SQL/08_BulkInsert_Clientes_Domicilios/Bundle_H_BulkInsert_Clientes_Domicilios.sql`

Este método usa una técnica diferente: primero un script Python genera un archivo CSV con los datos, y luego SQL Server lo lee e inserta usando `BULK INSERT` — que es significativamente más rápido que INSERT fila por fila para grandes volúmenes.

### ¿Qué genera?

| Tabla | Registros generados |
|-------|-------------------|
| `CLIENTES` | 10.000 clientes |
| `DOMICILIOS` | ~12.500 domicilios (distribución variable por cliente) |

Distribución de domicilios por cliente:
- **80%** de los clientes tienen 1 domicilio
- **15%** tienen 2 domicilios
- **5%** tienen 3 domicilios

### Rango de DNI utilizado

Los clientes generados por este método usan DNIs del rango **40.000.001 al 40.010.000**, diferente al Bundle F para que ambos puedan coexistir sin conflictos.

### ¿Cómo cambiar el rango de DNI?

En el archivo `genera_csv_clientes_domicilios.py`, buscar la variable:

```python
DNI_BASE = 40000001
```

Y cambiarla al número inicial deseado. Por ejemplo, para empezar desde 35.000.001:

```python
DNI_BASE = 35000001
```

También se puede cambiar la cantidad total de clientes:

```python
TOTAL_CLIENTES = 10000
```

### Paso a paso para ejecutar

**Paso 1 — Generar el CSV con Python:**

```bash
python genera_csv_clientes_domicilios.py
```

Esto genera el archivo `C:\SQLData\clientes_domicilios.csv`. Si la carpeta `C:\SQLData\` no existe, el script la crea automáticamente.

> Requiere Python 3 instalado. No requiere librerías externas.

**Paso 2 — Cargar el CSV en la base con SSMS:**

Abrir `Bundle_H_BulkInsert_Clientes_Domicilios.sql` en SSMS y ejecutarlo. El script:

1. Verifica que el archivo CSV exista antes de continuar
2. Crea una tabla intermedia temporal (staging) que recibe los datos del CSV tal cual
3. Normaliza los datos: separa clientes de domicilios y resuelve las claves foráneas
4. Inserta en `CLIENTES` y luego en `DOMICILIOS` respetando la relación entre tablas
5. Elimina la tabla temporal al finalizar

> **Tiempo estimado:** 10 a 30 segundos para 10.000 clientes.

---

## COMPARACIÓN ENTRE AMBOS MÉTODOS

| Característica | Bundle F (T-SQL) | Bundle H (BULK INSERT) |
|---------------|-----------------|----------------------|
| **Qué carga** | Clientes, domicilios, pedidos e ítems | Solo clientes y domicilios |
| **Volumen** | ~43.000 registros | ~12.500 registros |
| **Requiere Python** | No | Sí |
| **Velocidad** | 30-60 segundos | 10-30 segundos |
| **Rango DNI** | 30.000.001 - 30.003.000 | 40.000.001 - 40.010.000 |
| **Técnica** | INSERT con WHILE + NEWID() | BULK INSERT + tabla staging |
| **Limpia datos previos** | Sí (automático) | No |

---

## VERIFICACIÓN POST-CARGA

Luego de ejecutar cualquiera de los dos métodos, se puede verificar que los datos se insertaron correctamente ejecutando `Bundle_G_Verificacion_Carga.sql`:

**Archivo:** `B - Scripts SQL/07_Carga_Masiva_Datos/Bundle_G_Verificacion_Carga.sql`

Este script verifica:
- Cantidad de registros en cada tabla
- Integridad referencial (que no haya FKs rotas)
- Distribución por canal de venta
- Distribución por estado de pedido
- Consistencia de totales

---

## UBICACIÓN DE LOS ARCHIVOS

```
B - Scripts SQL/
├── 07_Carga_Masiva_Datos/
│   ├── Bundle_F_Carga_Masiva.sql          ← Carga masiva T-SQL (~43.000 registros)
│   └── Bundle_G_Verificacion_Carga.sql   ← Verificación post-carga
│
└── 08_BulkInsert_Clientes_Domicilios/
    ├── genera_csv_clientes_domicilios.py  ← Generador de CSV (Python)
    └── Bundle_H_BulkInsert_Clientes_Domicilios.sql  ← Carga via BULK INSERT
```

---

**Desarrollado por:** SQLeaders S.A.  
Materia: Laboratorio de Administración de Bases de Datos | Profesor: Carlos Alejandro Caraccio  
Uso exclusivamente académico — Prohibida la comercialización  
**EsbirrosDB v1.0 — Abril 2026**
