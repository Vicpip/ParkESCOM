---
name: ParkESCOM
colors:
  primary: '#006699'
  on-primary: '#FFFFFF'
  primary-dark: '#004D73'
  primary-container: '#E3F1F8'
  on-primary-container: '#004D73'
  background: '#F5F7F9'
  on-background: '#1A1C1E'
  surface: '#FFFFFF'
  on-surface: '#1A1C1E'
  surface-alt: '#F5F7F9'
  on-surface-variant: '#5F6B73'
  outline: '#707880'
  outline-variant: '#DCE2E6'
  success: '#1B873F'
  success-container: '#E8F5E9'
  on-success-container: '#0F5124'
  error: '#C62828'
  on-error: '#FFFFFF'
  error-container: '#FFEBEE'
  on-error-container: '#7F1313'
  warning: '#B26A00'
  warning-container: '#FFF3E0'
  on-warning-container: '#6D3F00'
  neutral-container: '#E0E0E0'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-lg-medium:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  code-license-plate:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: 1.5px
  code-license-plate-xl:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: 2px
rounded:
  sm: 4px
  DEFAULT: 8px
  md: 12px
  lg: 16px
  full: 9999px
spacing:
  space-xs: 4px
  space-sm: 8px
  space-md: 16px
  space-lg: 24px
  space-xl: 32px
---

# ParkESCOM — Sistema de diseño

Fuente única de tokens visuales de la app Flutter (Android y web). Si algo aquí contradice `CLAUDE.md` o
`docs/planeacion.md`, mandan esos dos.

## Marca y estilo

Sistema de control de acceso vehicular para ESCOM-IPN. Estilo institucional, limpio y legible, basado en Material 3
y en los colores de ESCOM: azul y blanco.

- **Claridad antes que adorno:** listas, tarjetas y resultados de validación sin elementos decorativos, legibles en exteriores.
- **Identidad institucional:** el azul ESCOM es el único color de marca.
- **A prueba de errores:** áreas táctiles grandes y estados que siempre combinan ícono y texto, nunca solo color.

## Colores

| Rol | Valor | Uso |
| --- | --- | --- |
| `primary` | `#006699` | Azul ESCOM. Botones primarios, enlaces, foco, destino activo de la navegación |
| `primary-dark` | `#004D73` | Botón primario presionado, encabezados destacados |
| `primary-container` | `#E3F1F8` | Fondo de tarjetas destacadas, elementos seleccionados, píldora de navegación activa |
| `background` | `#F5F7F9` | Fondo de pantallas y secciones |
| `surface` | `#FFFFFF` | Tarjetas, diálogos, campos de texto, barra inferior |
| `outline-variant` | `#DCE2E6` | Bordes de 1 px de tarjetas y campos |
| `on-surface` | `#1A1C1E` | Texto principal |
| `on-surface-variant` | `#5F6B73` | Texto secundario y etiquetas |

**Estados** (solo para estados, nunca como color de marca; siempre con ícono y texto):

| Estado | Color | Contenedor | Texto sobre contenedor |
| --- | --- | --- | --- |
| Éxito, aprobado, acceso permitido | `#1B873F` | `#E8F5E9` | `#0F5124` |
| Error, rechazado, acceso denegado | `#C62828` | `#FFEBEE` | `#7F1313` |
| Advertencia, pendiente | `#B26A00` | `#FFF3E0` | `#6D3F00` |

En Flutter: `ColorScheme.fromSeed(seedColor: Color(0xFF006699))` y luego `.copyWith(...)` con los valores exactos de
esta tabla, porque `fromSeed` altera el tono del primario. Éxito y advertencia van en un `ThemeExtension` propio.

## Tipografía

**Inter** en toda la app, empaquetada como asset (no descargada en tiempo de ejecución, para que funcione sin red).

- El texto de cuerpo nunca baja de 16 px (`body-lg`) en flujos operativos.
- **Placas:** `code-license-plate` en tarjetas y listas; `code-license-plate-xl` en el resultado de la caseta (G3),
  que el guardia lee a distancia. Siempre en mayúsculas.
- Títulos en 700 y 600. Ningún texto se corta con "…" en pantallas de caseta: si no cabe, va en dos líneas.

## Layout y tamaños de pantalla

Ritmo de 8 px.

| Formato | Ancho | Distribución |
| --- | --- | --- |
| Celular y MC33xR | desde 320 dp hasta 599 dp | Una columna, márgenes de 16 px, barra de navegación inferior |
| Tablet (ET401) | 600–1023 dp | Riel o menú de navegación lateral; listas y detalle en dos paneles donde aplique |
| Web (panel de administración) | 1024 dp o más | Menú lateral, contenido con máximo 1280 px centrado, márgenes de 32 px |

El MC33xR tiene una pantalla de 4 pulgadas; su ancho útil probablemente ronda los 320 dp. Verifícalo con
`MediaQuery` en el equipo real y diseña las pantallas de caseta para ese ancho.

## Elevación

Capas tonales de Material 3 con bordes de 1 px `#DCE2E6`, sin sombras dramáticas.

- **Nivel 0:** fondo `#F5F7F9`.
- **Nivel 1 (tarjetas, tablas, grupos de campos):** `#FFFFFF`, borde de 1 px y sombra sutil `0 1px 3px rgba(26,28,30,0.06)`.
- **Nivel 2 (tarjeta en hover o arrastre):** sombra `0 4px 12px rgba(26,28,30,0.08)`.
- **Nivel 3 (diálogos, barra inferior):** sombra `0 8px 24px rgba(26,28,30,0.12)`.

## Formas

- Botones, campos de texto, tarjetas y diálogos: `md` (12 px).
- Chips de estado: `full` (píldora).
- Barra de navegación inferior: esquinas superiores `lg` (16 px), inferiores rectas.

## Componentes

### Botones
- Alto mínimo 48 px, padding horizontal de 20 px, texto `label-lg`.
- **Primario:** fondo `#006699`, texto blanco; presionado `#004D73`; foco con anillo de 2 px `#006699` separado 2 px.
- **Secundario:** fondo blanco, borde de 1 px `#006699`, texto `#006699`; hover `#E3F1F8`.
- **Texto:** sin fondo, texto `#006699`. Para "Ver detalle" o "Cancelar".
- **Destructivo:** fondo `#C62828`, texto blanco. Siempre con diálogo de confirmación.

### Campos de texto
- Alto de 52 px, fondo blanco, borde de 1 px `#DCE2E6`, radio de 12 px, padding de 16 px.
- Valor en `body-lg`; etiqueta arriba en `label-md` `#5F6B73`.
- **Foco:** borde de 2 px `#006699`. **Error:** borde `#C62828` y mensaje en rojo con ícono de advertencia, en tiempo real.
- **Placa:** mayúsculas automáticas y `code-license-plate`.

### Chips de estado
Alto de 28 px, píldora, padding horizontal de 10 px, ícono de 16 px, separación de 4 px. Siempre ícono + texto.

| Estado | Texto | Fondo | Ícono |
| --- | --- | --- | --- |
| Pendiente | `#6D3F00` | `#FFF3E0` | reloj |
| Aprobada | `#0F5124` | `#E8F5E9` | palomita en círculo |
| Activa | `#004D73` | `#E3F1F8` | escudo con palomita |
| Rechazada | `#7F1313` | `#FFEBEE` | X en círculo |
| Revocada | `#1A1C1E` | `#E0E0E0` | círculo tachado |

### Tarjeta de vehículo
- Fondo blanco, borde de 1 px `#DCE2E6`, radio de 12 px, padding de 16 px.
- Izquierda: foto del vehículo o ícono de su tipo (auto, moto, bici, scooter) y la placa en `code-license-plate`.
- Derecha: marca y modelo, color, titular y credenciales ligadas.
- Esquina superior derecha: chip de estado.

### Resultado de validación (G3)
- Fondo verde `#1B873F` (permitido) o rojo `#C62828` (denegado) a **pantalla completa**, texto blanco.
- Ícono grande, título en dos líneas si no cabe ("ACCESO / PERMITIDO"), placa en `code-license-plate-xl`.
- Fotos del titular y del vehículo; en rechazo, el motivo en texto grande.
- Cierre automático a los 3 s con contador visible.

### Barra de navegación inferior
- Alto de 64 px, fondo blanco, borde superior de 1 px `#DCE2E6`, nivel 3.
- **Activo:** píldora `#E3F1F8` detrás del ícono `#006699` y etiqueta `label-md` `#004D73`.
- **Inactivo:** ícono y etiqueta `#5F6B73`.
- Destinos por rol:
  - Usuario: Inicio, Vehículos, Historial, Perfil.
  - Guardia: Caseta, Manual, Turno, Incidentes (admin agrega Enrolar y Configuración en el menú).

## Reglas de contenido

Los mockups de Stitch inventaron funciones que el sistema no tiene. En la interfaz **nunca** aparecen:

- Biometría, detección de rostro, OCR o lectura automática de placas, cámaras en vivo, plumas, barreras o torniquetes.
- Integraciones con SAES, padrones o catálogos del IPN, ni la tarjeta universitaria (TUI).
- Promesas de tiempo real ("notificación instantánea", "replicación inmediata").
- Reglamentos, límites, horarios, plazos o áreas administrativas inventados. La autoridad es "Administración".
- Nombres de lugar distintos a **Puerta A** y **Puerta B**.
- IDs de pantalla o de requerimientos (M5, RF-04), ni términos técnicos para el usuario (TOTP, SHA, dBm).