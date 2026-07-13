# 08 — Bulk Insert: Clientes + Domicilios

**Carpeta:** `08_BulkInsert_Clientes_Domicilios`
**Proposito:** Carga masiva de CLIENTES y DOMICILIOS desde un CSV unico desnormalizado usando `BULK INSERT` de SQL Server.

---

## Contenido

| Archivo | Descripcion |
|---------|-------------|
| `genera_csv_clientes_domicilios.py` | Script Python que genera `C:\SQLData\clientes_domicilios.csv` |
| `Bundle_H_BulkInsert_Clientes_Domicilios.sql` | Script SQL que ejecuta el BULK INSERT con tabla staging |

---

## Uso

### 1. Generar el CSV

```powershell
python "B - Scripts SQL\08_BulkInsert_Clientes_Domicilios\genera_csv_clientes_domicilios.py"
```

Genera `C:\SQLData\clientes_domicilios.csv` con:
- 10.000 clientes unicos
- 80% con 1 domicilio, 15% con 2, 5% con 3
- ~12.500 filas totales

### 2. Ejecutar el BULK INSERT

```powershell
sqlcmd -S localhost -E -i "B - Scripts SQL\08_BulkInsert_Clientes_Domicilios\Bundle_H_BulkInsert_Clientes_Domicilios.sql"
```

---

## Prerequisitos

Ejecutar antes de este bundle:

```
Bundle_A1  → Estructura de tablas (CLIENTES y DOMICILIOS deben existir)
Bundle_A2  → Indices y datos maestros
```

---

## Resultado esperado

| Tabla      | Registros nuevos |
|------------|-----------------|
| CLIENTES   | 10.000          |
| DOMICILIOS | ~12.500         |
