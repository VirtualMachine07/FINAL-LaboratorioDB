# 07 - Prompts de IA Utilizados
## EsbirrosDB — Bodegón Los Esbirros de Claudio

| Campo | Detalle |
|---|---|
| **Institución** | ISTEA |
| **Materia** | Laboratorio de Administración de Bases de Datos |
| **Profesor** | Carlos Alejandro Caraccio |
| **Versión** | 1.0 |
| **Fecha** | Abril 2026 |
| **Herramienta de IA** | GitHub Copilot (Claude Sonnet 4.6) vía Visual Studio Code |

---

## 1. Introducción

Durante el desarrollo del proyecto EsbirrosDB se utilizó inteligencia artificial generativa (**GitHub Copilot con Claude Sonnet 4.6**) como herramienta de asistencia en cuatro áreas específicas:

1. **Organización y escritura de bundles de despliegue** — estructurar y escribir los bundles a partir de la base de datos ya armada
2. **Generación del script Python** — para crear el CSV con 10.000 clientes ficticios
3. **Debugging y corrección de errores** — errores de entorno surgidos durante la ejecución
4. **Redacción de documentos de entrega** — los archivos de la carpeta `A - Documentacion Inicial`

---

## 2. Área 1 — Organización y Escritura de Bundles de Despliegue

**Contexto:** Una vez desarrollada la base de datos, se utilizó la IA para tomar todo el código existente y organizarlo en bundles de despliegue con estructura clara, nombres consistentes y orden de ejecución correcto. Se trabajó en conversación iterativa: primero se describieron las tablas y la estructura general, luego se fue copiando el código de cada SP, trigger y vista para que la IA lo incorporara al bundle correspondiente.

**Secuencia de prompts utilizada:**

**Prompt inicial:**
> "Tengo una base de datos SQL Server llamada EsbirrosDB para un bodegón. Tiene las siguientes tablas: CLIENTES, DOMICILIOS, EMPLEADOS, SUCURSALES, CANALES_VENTA, PLATOS, CATEGORIAS_PLATO, PEDIDOS, ITEMS_PEDIDO, ESTADOS_PEDIDO, AUDITORIA_PEDIDOS, AUDITORIA_ITEMS. Necesito organizar el código en bundles de despliegue ejecutables en orden. ¿Cómo los agrupo?"

**Prompt por cada objeto (ejemplo):**
> "Este es el stored procedure sp_CrearPedido. Integralo al bundle de lógica de negocio con el encabezado y comentarios correspondientes: [código del SP pegado]"

**Prompt de cierre por bundle:**
> "Revisá el Bundle B1 completo y verificá que no falte ningún GO entre objetos y que el orden de creación sea correcto."

**Resultado obtenido:**
- Propuesta de estructura en carpetas numeradas por etapa de despliegue
- Criterio de agrupación: infraestructura → lógica de negocio → seguridad → automatización → reportes → carga de datos
- Convención de nombres `Bundle_XX_Descripcion.sql` con prefijos A, B, C, D, E, F, G, H
- Escritura del contenido de cada bundle integrando el código real de EsbirrosDB
- Identificación de dependencias entre bundles (ej: los triggers dependen de las tablas y los SPs)

**Estructura resultante:**

| Carpeta | Bundles | Contenido |
|---|---|---|
| `01_Infraestructura_Base` | A1, A2 | DDL de tablas, índices, datos maestros |
| `02_Logica_Negocio` | B1, B2, B3 | Stored procedures de pedidos, ítems y estados |
| `03_Seguridad_Consultas` | C, D | Roles, usuarios, consultas básicas |
| `04_Automatizacion_Avanzada` | E1, E2 | Triggers de auditoría y control |
| `05_Reportes_Dashboard` | R1, R2 | Stored procedures de reportes y vistas |
| `06_Validacion_Post_Bundles` | — | Scripts de validación y demo |

> Las carpetas `07_Carga_Masiva_Datos` y `08_BulkInsert_Clientes_Domicilios` fueron incorporadas en una etapa posterior. La IA participó en todo el proceso de esas carpetas: diseño, escritura de scripts y generación del CSV (ver Áreas 2 y 3).

**Decisión tomada:** Se adoptó la estructura propuesta y se trabajó junto con la IA para escribir cada bundle. Se realizaron ajustes manuales donde fue necesario (por ejemplo, separar E1 y E2, ajustar el orden de algunos objetos por dependencias).

---

## 3. Área 2 — Script Python Generador de CSV

**Contexto:** Para la carga masiva con BULK INSERT (Bundle H) se necesitaba un archivo CSV con 10.000 clientes ficticios y sus domicilios. El script se construyó en conversación iterativa: primero se pidió una versión base y luego se fue ajustando la distribución, los campos y los datos ficticios hasta llegar al resultado final.

**Secuencia de prompts utilizada:**

**Prompt inicial:**
> "Necesito un script Python que genere un CSV para cargar clientes y domicilios en SQL Server. Las columnas del CSV son: doc_nro, nombre, apellido, email, telefono, direccion, numero, piso, depto, localidad, tipo_domicilio, es_principal. Generá 10.000 clientes con DNIs desde 40000001."

**Ajuste de distribución:**
> "Ahora necesito que cada cliente tenga entre 1 y 3 domicilios con esta distribución: 80% con 1, 15% con 2, 5% con 3. El primero siempre es tipo 'Particular' y es_principal=1. Los adicionales son tipos aleatorios entre 'Laboral', 'Temporal' y 'Otro'."

**Ajuste de datos ficticios:**
> "Los nombres, apellidos, calles y localidades tienen que ser argentinos, del área metropolitana de Buenos Aires. Sin tildes en ningún campo porque va a ir en un CSV para SQL Server."

**Ajuste de campos opcionales:**
> "El piso y depto tienen que ser opcionales: que aparezcan vacíos en aproximadamente 2 de cada 3 filas."

**Prompt de validación:**
> "Agregá al final del script un resumen con: total de filas generadas, cantidad de clientes con 1, 2 y 3 domicilios."

**Resultado obtenido:**
- Script completo con funciones `generar_domicilio()` y `generar_cliente()`
- Listas de nombres, apellidos, calles y localidades del área metropolitana de Buenos Aires
- Lógica de distribución de domicilios implementada con `i % 100`
- Manejo de campos opcionales: piso y departamento presentes en 1 de cada 3 domicilios
- Output con estadísticas al finalizar: total de filas y distribución real por cantidad de domicilios

**Verificación post-generación:**

| Métrica | Objetivo | Resultado real |
|---|---|---|
| Clientes generados | 10.000 | 10.000 |
| Filas totales en CSV | ~12.500 | 12.513 |
| Clientes con 1 domicilio | 80% | ~84,6% |
| Clientes con 2 domicilios | 15% | ~11,6% |
| Clientes con 3 domicilios | 5% | ~3,9% |
| DNI mínimo | 40.000.001 | 40.000.001 |

> La distribución real difiere ligeramente del objetivo teórico por la aleatoriedad del generador. Los valores están dentro de rango aceptable y no afectan la carga.

**Decisión tomada:** Se adoptó el script sin cambios estructurales. Se verificó la ejecución real antes de usar el CSV en el BULK INSERT.

---

## 4. Área 3 — Debugging y Corrección de Errores

### 4.1 Error RAISERROR con concatenación en sqlcmd

**Contexto:** Al ejecutar el bundle desde `sqlcmd`, un stored procedure fallaba. Se copió el mensaje de error exacto de la consola y se lo pegó a la IA.

**Prompt utilizado:**
> "Al ejecutar desde sqlcmd me aparece este error: 'Msg 102, Level 15, State 1, Incorrect syntax near +'. El código que falla es: `RAISERROR('Canal no válido: ' + @canal, 16, 1)`. ¿Qué está mal y cómo lo corrijo?"

**Respuesta de la IA:**
> `RAISERROR` no acepta expresiones de concatenación como primer argumento. Declarar una variable intermedia: `DECLARE @msg NVARCHAR(500) = 'Canal no válido: ' + @canal; RAISERROR(@msg, 16, 1)`.

**Decisión tomada:** Se aplicó la corrección en los stored procedures afectados. Error resuelto.

---

### 4.2 Error SET QUOTED_IDENTIFIER al ejecutar desde sqlcmd

**Contexto:** El Bundle H fallaba al ejecutarse desde `sqlcmd` pero funcionaba correctamente desde SSMS. Se pegó el error exacto.

**Prompt utilizado:**
> "Ejecuto un script SQL desde sqlcmd y me da este error: 'Msg 1934, Level 16, State 1, INSERT failed because the following SET options have incorrect settings: QUOTED_IDENTIFIER'. El mismo script funciona bien desde SSMS. ¿Por qué pasa esto y cómo lo soluciono?"

**Respuesta de la IA:**
> `sqlcmd` ejecuta con `QUOTED_IDENTIFIER OFF` por defecto. Si hay índices filtrados en las tablas involucradas, SQL Server exige que esté `ON`. Agregar `SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;` al inicio del script.

**Decisión tomada:** Se agregaron ambas sentencias `SET` al encabezado del Bundle H. Error resuelto.

---

### 4.3 Corrección de encoding en archivos Markdown

**Contexto:** Al modificar archivos `.md` con PowerShell, el contenido guardado quedaba con caracteres ilegibles. Se describió el problema con el comando exacto usado.

**Prompt utilizado:**
> "Uso este comando de PowerShell para reemplazar texto en un .md: `(Get-Content archivo.md) -replace 'texto viejo', 'texto nuevo' | Set-Content archivo.md`. Después de ejecutarlo el archivo queda con caracteres raros, las tildes se rompen. ¿Qué está pasando?"

**Respuesta de la IA:**
> PowerShell 5.1 lee el archivo como UTF-8 pero `Set-Content` lo guarda como UTF-16 LE por defecto, lo que rompe los caracteres especiales. Usar `Set-Content -Encoding UTF8` o `[System.IO.File]::WriteAllText($path, $contenido, [System.Text.Encoding]::UTF8)`.

**Decisión tomada:** Se abandonó el enfoque de PowerShell para edición de `.md` y se usó la herramienta de edición directa del editor. Error resuelto.

---

## 5. Área 4 — Redacción de Documentos de Entrega

**Contexto:** Para cada documento de entrega, primero se verificó manualmente la información técnica contra los scripts SQL reales. Luego se le pasó ese contenido a la IA para que lo redactara con formato académico. El proceso fue siempre: verificar → pasar contenido → redactar → revisar.

**Ejemplo de prompt utilizado (para el Resumen Ejecutivo):**
> "Redactá un resumen ejecutivo académico para un proyecto de base de datos llamado EsbirrosDB. Es para un bodegón porteño llamado Los Esbirros de Claudio. Tiene 1 sucursal activa. La base tiene estas tablas: [lista de tablas]. Estos stored procedures: [lista de SPs]. Estos roles de seguridad: [lista de roles]. Usá formato markdown con tabla de metadatos al inicio. Materia: Laboratorio de Administración de Bases de Datos. Profesor: Carlos Alejandro Caraccio."

**Ejemplo de prompt utilizado (para Reglas de Negocio):**
> "Redactá un documento de reglas de negocio para EsbirrosDB basado en estos stored procedures: [código de sp_CrearPedido, sp_AgregarItemPedido, sp_CancelarPedido pegados]. Organizá las reglas por dominio: pedidos, ítems, estados, cancelación. Formato markdown académico."

| Documento | Contenido que se le pasó a la IA |
|---|---|
| `01 - Resumen Ejecutivo.md` | Lista de objetos de la BD verificados manualmente |
| `02 - Modelo Entidad-Relacion (DER).md` | DDL de las tablas y relaciones |
| `03 - Reglas de Negocio y Validaciones.md` | Código de los SPs de pedidos, ítems y estados |
| `04 - Guia de Despliegue Inicial.md` | Lista de bundles, orden y dependencias |
| `05 - Carga Masiva de Datos.md` | Código de Bundle F, Bundle H y script Python |
| `06 - Plan de Backup y Recuperacion.md` | Configuración real de SQLBackupAndFTP |

> **Validación:** Todos los documentos fueron revisados manualmente después de la redacción para verificar que los datos (nombres de objetos, cantidades, configuraciones) coincidan exactamente con lo que está implementado en EsbirrosDB.

---

## 6. Errores Detectados y Corregidos Manualmente

| # | Error | Causa raíz | Corrección aplicada |
|---|---|---|---|
| 1 | `RAISERROR` con `+` en sqlcmd | Concatenación no permitida como argumento directo | Variable `NVARCHAR` intermedia |
| 2 | `SET QUOTED_IDENTIFIER` en sqlcmd | sqlcmd desactiva la opción por defecto | `SET QUOTED_IDENTIFIER ON` al inicio del script |
| 3 | Encoding corrompido en `.md` | PowerShell 5.1 usa UTF-16 por defecto | Edición directa con herramienta del editor |

---

## 7. Reflexión sobre el Uso de IA

### Qué aportó la IA
- Estructuración y escritura de los bundles de despliegue a partir de la base de datos ya armada
- Generación de código Python funcional con lógica de distribución correcta
- Diagnóstico rápido de errores de entorno (sqlcmd, PowerShell)
- Redacción clara y estructurada de documentación técnica a partir de información ya verificada

### Qué requirió intervención humana
- Todo el diseño del modelo relacional y la lógica de negocio
- Verificar que el código de los bundles coincida exactamente con los objetos reales de EsbirrosDB
- Detectar y corregir errores de la IA en contextos de ejecución específicos
- Validar el CSV generado antes de ejecutar el BULK INSERT

### Conclusión
La IA fue una herramienta de **aceleración y asistencia**, utilizada en tareas concretas y acotadas. El diseño, la lógica de negocio y la validación técnica fueron desarrollados de forma independiente. El valor real estuvo en la combinación: criterio técnico propio + IA para tareas de soporte específicas.

---

*Proyecto Educativo ISTEA — Laboratorio de Administración de Bases de Datos 2026*
*Versión: 1.0*
