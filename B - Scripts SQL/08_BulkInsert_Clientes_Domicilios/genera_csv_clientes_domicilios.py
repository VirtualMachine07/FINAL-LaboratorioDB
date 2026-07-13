# =============================================
# GENERADOR DE CSV: clientes_domicilios.csv
# EsbirrosDB - Sistema de Gestion de Bodegon Porteno
# Negocio: Bodegon Los Esbirros de Claudio
# Descripcion: Genera un CSV unico desnormalizado con
#              clientes y sus domicilios.
#              - 80% de clientes: 1 domicilio
#              - 15% de clientes: 2 domicilios
#              -  5% de clientes: 3 domicilios
# Proyecto Educativo ISTEA - Uso academico exclusivo
# =============================================

import csv
import random
import os

# ─────────────────────────────────────────────
# CONFIGURACION
# ─────────────────────────────────────────────

TOTAL_CLIENTES  = 10000
DNI_BASE        = 40000001
OUTPUT_DIR      = r'C:\SQLData'
OUTPUT_FILE     = os.path.join(OUTPUT_DIR, 'clientes_domicilios.csv')

# ─────────────────────────────────────────────
# DATOS DE REFERENCIA
# (sin tildes, encoding limpio - igual que Bundle F)
# ─────────────────────────────────────────────

NOMBRES = [
    'Juan', 'Maria', 'Carlos', 'Ana', 'Luis', 'Laura', 'Pedro', 'Sofia',
    'Miguel', 'Elena', 'Jorge', 'Carmen', 'Roberto', 'Isabel', 'Diego',
    'Patricia', 'Fernando', 'Lucia', 'Ricardo', 'Martina', 'Andres', 'Valentina'
]

APELLIDOS = [
    'Gonzalez', 'Rodriguez', 'Fernandez', 'Lopez', 'Martinez', 'Sanchez',
    'Perez', 'Gomez', 'Martin', 'Jimenez', 'Ruiz', 'Hernandez', 'Diaz',
    'Moreno', 'Munoz', 'Alvarez', 'Romero', 'Alonso', 'Gutierrez', 'Navarro'
]

CALLES = [
    'Av. Corrientes', 'Av. Santa Fe', 'Av. Cabildo', 'Av. Rivadavia',
    'Calle Florida', 'Av. Callao', 'Av. Cordoba', 'Calle Lavalle',
    'Av. Las Heras', 'Av. Pueyrredon', 'Calle Reconquista', 'Av. 9 de Julio',
    'Calle Defensa', 'Av. San Juan', 'Calle Peru', 'Av. Entre Rios'
]

LOCALIDADES = ['CABA', 'CABA', 'CABA', 'CABA', 'Palermo', 'Belgrano', 'San Telmo']
PROVINCIAS  = ['Buenos Aires'] * 7

# Tipos validos segun CHECK constraint de la tabla DOMICILIOS
TIPOS_DOMICILIO = ['Particular', 'Laboral', 'Temporal', 'Otro']

# Observaciones por tipo
OBS_PRINCIPAL = {
    'Particular': 'Domicilio principal del cliente',
    'Laboral':    'Domicilio laboral / oficina',
    'Temporal':   'Residencia temporal',
    'Otro':       'Domicilio adicional',
}
OBS_ADICIONAL = {
    'Particular': 'Segundo domicilio particular',
    'Laboral':    'Lugar de trabajo / oficina',
    'Temporal':   'Domicilio transitorio',
    'Otro':       'Otro domicilio registrado',
}


# ─────────────────────────────────────────────
# FUNCION: generar un domicilio
# ─────────────────────────────────────────────

def generar_domicilio(i, es_principal, tipo=None):
    """Devuelve dict con los campos de un domicilio."""
    if tipo is None:
        tipo = 'Particular' if es_principal else random.choice(TIPOS_DOMICILIO)

    # Piso y depto: solo 1 de cada 3
    tiene_piso = (i % 3 == 0)
    piso  = str((i % 20) + 1) if tiene_piso else ''
    depto = chr(65 + (i % 10)) if tiene_piso else ''  # A, B, C...

    obs = OBS_PRINCIPAL[tipo] if es_principal else OBS_ADICIONAL[tipo]

    idx_loc = i % len(LOCALIDADES)

    return {
        'calle':          random.choice(CALLES),
        'numero':         str(100 + (i % 9000)),
        'piso':           piso,
        'depto':          depto,
        'localidad':      LOCALIDADES[idx_loc],
        'provincia':      PROVINCIAS[idx_loc],
        'es_principal':   1 if es_principal else 0,
        'tipo_domicilio': tipo,
        'observaciones':  obs,
    }


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Determinar cuantos domicilios tendra cada cliente
    # 80% -> 1,  15% -> 2,  5% -> 3
    def cantidad_domicilios(idx):
        r = idx % 100
        if r < 80:
            return 1
        elif r < 95:
            return 2
        else:
            return 3

    columnas = [
        'doc_nro', 'nombre', 'telefono', 'email', 'doc_tipo',
        'calle', 'numero', 'piso', 'depto',
        'localidad', 'provincia', 'es_principal', 'tipo_domicilio', 'observaciones'
    ]

    total_filas = 0

    print(f'Generando CSV para {TOTAL_CLIENTES} clientes...')

    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=columnas)
        writer.writeheader()

        for i in range(TOTAL_CLIENTES):
            dni      = DNI_BASE + i
            nombre   = random.choice(NOMBRES)
            apellido = random.choice(APELLIDOS)
            n_dom    = cantidad_domicilios(i)

            cliente = {
                'doc_nro':  str(dni),
                'nombre':   f'{nombre} {apellido}',
                'telefono': f'11{(40000000 + i):08d}',
                'email':    f'{nombre.lower()}.{apellido.lower()}{i + 1}@mail.com',
                'doc_tipo': 'DNI',
            }

            # Primer domicilio: siempre Particular y es_principal = 1
            dom = generar_domicilio(i, es_principal=True, tipo='Particular')
            writer.writerow({**cliente, **dom})
            total_filas += 1

            # Domicilios adicionales (solo si n_dom > 1)
            for j in range(1, n_dom):
                tipo_adicional = random.choice(['Laboral', 'Temporal', 'Otro'])
                dom = generar_domicilio(i * 10 + j, es_principal=False, tipo=tipo_adicional)
                writer.writerow({**cliente, **dom})
                total_filas += 1

            if (i + 1) % 2000 == 0:
                print(f'  Clientes procesados: {i + 1}')

    print()
    print(f'Archivo generado: {OUTPUT_FILE}')
    print(f'Total de filas (sin encabezado): {total_filas}')
    print(f'  - Clientes unicos: {TOTAL_CLIENTES}')
    print(f'  - Clientes con 1 domicilio:  ~{int(TOTAL_CLIENTES * 0.80):>6}')
    print(f'  - Clientes con 2 domicilios: ~{int(TOTAL_CLIENTES * 0.15):>6}')
    print(f'  - Clientes con 3 domicilios: ~{int(TOTAL_CLIENTES * 0.05):>6}')
    print()
    print('Listo para ejecutar Bundle_H_BulkInsert_Clientes_Domicilios.sql')


if __name__ == '__main__':
    main()
