# ParkESCOM

Sistema de control de acceso vehicular para ESCOM-IPN. Proyecto final de Desarrollo de Aplicaciones Móviles Nativas.
Un solo desarrollador. Entrega: **15 de noviembre de 2026**.

- **App Flutter (Android):** usuario (vehículos, QR dinámico, historial) y guardia (modo caseta con lectores Zebra).
- **Panel web (Flutter Web, mismo código):** administración de solicitudes, usuarios, vehículos y credenciales.
- **API REST en Dart Frog + PostgreSQL**, desplegada con Docker Compose en un VPS detrás de Nginx con Certbot.

La planeación completa está en **`docs/planeacion.md`** (requerimientos RF/RNF, pantallas, flujos, modelo de datos,
plan por fases) y es la fuente de verdad. Léela antes de empezar cada fase.
Los requerimientos del profesor están en `docs/requerimientos-profesor.pdf`.
Si una tarea contradice la planeación, **detente y pregunta** antes de escribir código.

## Reglas no negociables

1. **Todo el código es Dart.** No escribir Kotlin, Java ni Swift. El hardware se usa solo mediante paquetes de pub.dev.
2. **Nada de secretos en el código ni en Git.** Todo va en variables de entorno; el repo solo tiene `.env.example` con nombres, sin valores.
3. **MVVM por funcionalidad** en la app. Las vistas no llaman repositorios ni la API directamente.
4. **Las reglas críticas viven en PostgreSQL**, no solo en la API (ver "Base de datos").
5. **Migraciones inmutables:** una migración ya aplicada no se edita; los cambios van en una migración nueva.
6. **No agregar dependencias** fuera de las listadas abajo sin preguntar primero.
7. **No inventar APIs de paquetes.** Si no estás seguro de cómo funciona un paquete, revisa su README o código fuente antes de usarlo.
8. **Trabaja solo la fase o tarea pedida.** No adelantes fases ni refactorices fuera del alcance.

## Estructura del monorepo

```
parkescom/
  app/                  # Flutter: Android + web
  backend/              # Dart Frog
  shared/               # paquete Dart puro: modelos, motor de validación, TOTP, verificación de pases
  db/migrations/        # 001_init.sql, 002_..., aplicadas en orden
  nginx/                # configuración de referencia para el VPS (no se usa en local)
  docs/                 # planeacion.md, requerimientos-profesor.pdf, design/ (mockups), diagramas UML
  docker-compose.yml    # api + postgres
  .env.example
  CLAUDE.md
```

`shared/` no depende de Flutter ni de IO: lo importan `app/` y `backend/`.

## Comandos

```bash
# Base de datos local
docker compose up -d db            # [listo] PostgreSQL 16 en 127.0.0.1 (puerto POSTGRES_PORT, 5432 por defecto)

# Paquete compartido
cd shared && dart pub get          # [listo]
dart analyze                       # [listo]
dart test                          # [listo] validadores de registro (el motor de validación llega en la Fase 4)

# Backend
cd backend && dart pub get         # [listo]
dart run bin/migrate.dart          # [listo] aplica las migraciones pendientes de db/migrations
dart run bin/migrate.dart --seed   # [listo] además aplica los catálogos de db/seeds (idempotente)
dart run bin/seed_usuarios.dart    # [listo] cuentas de demostración con la contraseña de SEED_PASSWORD (idempotente)
dart_frog dev --port 8081          # [listo] API en http://localhost:8081 con las rutas de /auth
dart test                          # [listo] test/db y test/routes contra DATABASE_URL_TEST (la base se recrea)
dart analyze                       # [listo]

# App
cd app && flutter pub get          # [listo]
flutter analyze                    # [listo]
flutter test                       # [listo] solo la prueba de la plantilla
flutter run                        # Android (MC33xR, ET401 o celular)
flutter run -d chrome              # panel web

# Formato (antes de cada commit)
dart format .
```

El backend lee las variables del entorno del proceso y, si faltan, del `.env` de la raíz (`backend/lib/config/entorno.dart`).
Para arrancar, la API exige `DATABASE_URL`, `JWT_ACCESS_SECRET` (32 caracteres o más), `ALLOWED_EMAIL_DOMAINS` y
`APP_WEB_URL`; si falta alguna se detiene con un mensaje claro (`backend/main.dart`).

Cuentas de demostración de `seed_usuarios.dart` (todas activas, contraseña `SEED_PASSWORD`): `demo.admin@ipn.mx`,
`demo.guardia@ipn.mx`, `demo.usuario1@alumno.ipn.mx` y `demo.usuario2@alumno.ipn.mx`.

Las pruebas del backend corren un archivo a la vez (`backend/dart_test.yaml`) porque comparten la base de pruebas.

Puertos en este equipo:
- La API corre en el **8081** (`dart_frog dev --port 8081`) porque el 8080 está ocupado.
- `POSTGRES_PORT` es opcional (5432 por defecto); en este equipo es **5433** y `DATABASE_URL` y `DATABASE_URL_TEST` usan ese mismo puerto.

Si un comando de esta lista todavía no existe, créalo como parte de la fase que lo necesite y actualiza esta sección.

## Dependencias permitidas

**shared:** `otp`, `uuid`, `dart_jsonwebtoken`, `meta`, `test`.

**backend:** `dart_frog`, `postgres`, `bcrypt`, `crypto`, `dart_jsonwebtoken`, `mailer`, `uuid`, `shared` (path), `test`, `mocktail`.

**app:** `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `sqflite_sqlcipher`, `workmanager`,
`flutter_local_notifications`, `qr_flutter`, `otp`, `flutter_datawedge`, `mobile_scanner`, `nfc_manager`,
`nfc_host_card_emulation`, `image_picker`, `flutter_image_compress`, `cached_network_image`, `geolocator`,
`connectivity_plus`, `fl_chart`, `uuid`, `intl`, `shared` (path).

**Dependencias de desarrollo (análisis estático):** `dart_frog_lint` (backend), `lints` (shared), `flutter_lints` (app).

## Arquitectura de la app (MVVM)

```
app/lib/
  core/            # tema, router, cliente HTTP, manejo global de errores, constantes
  data/
    repositories/  # única puerta de los ViewModels hacia los datos
    sources/
      remote/      # API (dio)
      local/       # SQLite, secure storage
      hardware/    # DataWedge, NFC, HCE (solo Android)
  features/<funcionalidad>/
    view/          # widgets; solo leen estado y llaman métodos del ViewModel
    viewmodel/     # Notifier/AsyncNotifier de Riverpod
  main.dart
```

- Flujo: **View → ViewModel → Repository → Source**. Nunca saltarse capas.
- Estado de pantalla con `AsyncValue`: siempre manejar carga (skeleton o spinner), error (mensaje para el usuario) y datos.
- Rutas por rol con `go_router`: usuario, guardia y admin ven shells distintos.
- Código solo Android (`sqflite_sqlcipher`, DataWedge, NFC, HCE, workmanager) se aísla con importaciones condicionales y `kIsWeb`, para que `flutter build web` compile.
- Diseño responsivo: probar en celular, MC33xR (pantalla chica), ET401 (tablet) y navegador.

## Pantallas (32)

Usa estos IDs en nombres de archivos, commits y reportes. El detalle de cada una está en `docs/planeacion.md`.
P1 = obligatoria; P2 = se recorta primero si falta tiempo.

**App móvil, comunes y usuario** (barra inferior: Inicio, Vehículos, Historial, Perfil)

| ID | Pantalla | Contenido clave | Prio |
| --- | --- | --- | --- |
| M1 | Splash | Revisa sesión y rol, redirige | P1 |
| M2 | Inicio de sesión | Correo, contraseña, enlaces a registro y recuperación | P1 |
| M3 | Registro | Correo institucional, boleta o núm. de empleado, foto del titular y de su credencial, aviso de privacidad | P1 |
| M4 | Recuperar contraseña | Envía el correo con el enlace (el enlace abre W11) | P1 |
| M5 | Inicio (mi credencial) | QR dinámico con contador, botón HCE, vehículo activo | P1 |
| M6 | Mis vehículos | Tarjetas, búsqueda, filtro por tipo | P1 |
| M7 | Detalle de vehículo | Fotos, datos, credenciales, usuarios autorizados, reportar credencial perdida | P1 |
| M8 | Formulario de vehículo | Alta o cambio con fotos (y foto de placa en motos); genera solicitud | P1 |
| M9 | Mis solicitudes | Lista con estado | P1 |
| M10 | Historial | Entradas y salidas con filtros por fecha, vehículo y puerta | P1 |
| M11 | Pases de visitante | Lista y estado | P2 |
| M12 | Nuevo pase | Nombre, placa, fecha y ventana de horario | P2 |
| M13 | Perfil | Avatar, datos, preferencias de notificaciones, cambiar contraseña (diálogo: actual y nueva), cerrar sesión | P1 |

**App móvil, guardia y admin en sitio** (MC33xR y ET401)

| ID | Pantalla | Contenido clave | Prio |
| --- | --- | --- | --- |
| G1 | Configurar caseta | Puerta, sentido, lectores activos | P1 |
| G2 | Modo caseta | Pantalla completa escuchando RFID, QR y NFC; conexión, última sincronización, cola offline | P1 |
| G3 | Resultado de validación | Verde o rojo, foto del titular, vehículo y placa, motivo | P1 |
| G4 | Registro manual | Búsqueda por placa o usuario, motivo obligatorio | P1 |
| G5 | Incidentes | Lista con filtro por estado | P1 |
| G6 | Formulario de incidente | Foto, descripción, GPS opcional | P1 |
| G7 | Enrolar credencial | Leer TID (MC33xR) o UID NFC y ligarlo a un vehículo; solo admin | P1 |
| G8 | Turno | Dentro ahora, ocupación por zona, movimientos del turno con búsqueda por placa | P1 |

**Panel web** (Flutter Web, menú lateral)

| ID | Pantalla | Contenido clave | Prio |
| --- | --- | --- | --- |
| W1 | Dashboard | Dentro ahora, entradas y salidas por hora y por tipo | P2 |
| W2 | Solicitudes | Aprobar o rechazar comparando la foto de la credencial con el registro | P1 |
| W3 | Usuarios | Tabla con búsqueda; alta, baja, cambio de rol | P1 |
| W4 | Vehículos | Tabla con filtros por tipo y estado | P1 |
| W5 | Credenciales | Revocar, reportar perdida, vigencia | P1 |
| W6 | Pases de visitante | Aprobar y consultar | P2 |
| W7 | Movimientos | Bitácora con filtros y exportación a CSV | P2 |
| W8 | Incidentes | Seguimiento y cambio de estado | P2 |
| W9 | Configuración | Puertas, zonas y cupos | P2 |
| W10 | Auditoría | Quién cambió qué y cuándo | P2 |
| W11 | Nueva contraseña | Página pública del enlace de recuperación; valida el token | P1 |

Inicio de sesión y perfil se comparten entre móvil y web. El enrolamiento de tags vive en la app (G7) porque el navegador no puede leer el MC33xR.

## Diseño

```
docs/design/
  DESIGN.md              # tokens de diseño (colores, tipografía, radios, componentes)
  00-sistema/            # hoja de estilo: screen.png + code.html
  M5-mi-credencial/      # una carpeta por pantalla, nombrada por ID
    screen.png           # captura del mockup
    code.html            # HTML con Tailwind exportado de Stitch
  ...
```

- **Orden de prioridad:** `CLAUDE.md` > `docs/planeacion.md` > `docs/design/DESIGN.md` > mockups.
- Los mockups (`screen.png` y `code.html`) son **referencia visual**, no fuente de verdad del texto ni del comportamiento.
- `code.html` sirve para ver jerarquía, espaciado y componentes. **No se traduce literal a Flutter:** cada pantalla se
  reconstruye con los widgets compartidos y el tema de `core/theme`.
- El MC33xR tiene pantalla de 4": las pantallas de caseta se diseñan para un ancho de ~320 dp. Verifícalo con `MediaQuery` en el equipo.

**Tokens** (en `app/lib/core/theme/`; ningún color ni tamaño se escribe a mano fuera del tema):

| Token | Valor | Uso |
| --- | --- | --- |
| primario | `#006699` | Azul ESCOM: botones primarios, barra de navegación activa |
| primario oscuro | `#004D73` | Encabezados, estados presionados |
| contenedor primario | `#E3F1F8` | Fondos de tarjetas destacadas y chips |
| fondo / superficie | `#FFFFFF` / `#F5F7F9` | Pantallas / secciones |
| texto / texto secundario | `#1A1C1E` / `#5F6B73` | |
| éxito / rechazo / advertencia | `#1B873F` / `#C62828` / `#B26A00` | Solo estados; nunca como color de marca |

- `ColorScheme.fromSeed(seedColor: Color(0xFF006699))` y luego `.copyWith(primary: ..., ...)` con los valores exactos, porque `fromSeed` altera el tono.
- Tipografía **Inter empaquetada como asset** en `pubspec.yaml` (no `google_fonts`, que la descarga en tiempo de ejecución y falla sin red). Cuerpo mínimo 16 px.
- Esquinas de 12 px, botones de al menos 48 px de alto. Ningún estado se comunica solo con color: siempre ícono + texto.
- Fechas y horas con `intl` en `es_MX`, formato de 24 horas (`13:15`).

**Navegación:** misma lista de destinos en celular (`NavigationBar`) y en tablet o web (`NavigationRail` o menú lateral).
- Usuario: Inicio, Vehículos, Historial, Perfil.
- Guardia: Caseta, Manual, Turno, Incidentes. Admin agrega Enrolar y Configuración.
- Panel web: Dashboard, Solicitudes, Usuarios, Vehículos, Credenciales, Pases, Movimientos, Incidentes, Configuración, Auditoría.
- Sin campana de notificaciones en los encabezados (no hay pantalla de notificaciones).

**Textos de la interfaz:** los mockups inventaron cosas que el sistema no hace. Nunca escribas en la UI:
- Hardware o integraciones fuera de alcance: biometría, detección de rostro, OCR o lectura de placas, plumas, barreras, torniquetes, SAES, padrón o catálogos del IPN, tarjeta universitaria (TUI).
- Promesas de tiempo real: "notificación instantánea", "replicación inmediata". Las notificaciones se revisan cada 15 min y las revocaciones llegan a la caseta en su siguiente sincronización.
- Reglamentos, límites, horarios, plazos o áreas administrativas inventadas. La única autoridad es "Administración".
- Nombres de lugar distintos a **Puerta A** y **Puerta B** (nada de "garita", "poste", "acceso norte").
- IDs de pantalla o de requerimientos (M5, RF-04…), ni detalles técnicos para el usuario (TOTP, SHA, dBm).

**Estados de interfaz** (`docs/design/00-estados/`): skeletons, vacío, error de red con "Reintentar", franja de
"Sin conexión · datos guardados", error de campo y diálogo destructivo. Se implementan como widgets compartidos en la
Fase 2 y toda pantalla con datos remotos usa los cuatro estados: carga, vacío, error y datos.

**Reglas transversales**
- **Placas:** se aceptan letras, números y guiones. Se guardan en mayúsculas y sin espacios. La validación es de formato, no de estado de emisión.
- **Bajas:** el usuario nunca da de baja directamente; en M7 *solicita* la baja y Administración la ejecuta desde el panel web (W3, W4). Toda baja es lógica y el texto de confirmación dice que las credenciales dejan de funcionar en las casetas en su próxima sincronización y que el historial se conserva.

**Notas por pantalla**
- **M5:** debajo del QR solo el contador ("Se actualiza en 12 s"). El botón NFC dice "Acerca tu celular al lector NFC de la caseta" (sin "peatonal").
- **M7:** un auto muestra solo tag RFID y QR como credenciales; NFC aplica a motos, bicis y scooters. Aquí vive "Reportar credencial perdida".
- **M8:** la sección "Fotografía de placa" solo aparece si el tipo es Moto. Sin etiqueta de estado de la placa (CDMX/EdoMex).
- **G2:** el texto de lectores activos sale de la configuración de G1 y del equipo (MC33xR: RFID y lector QR; ET401: NFC y cámara). Cada equipo (MC33xR o ET401) puede estar en cualquiera de las dos puertas; la puerta y el sentido salen de la configuración de G1.
- **G3:** fondo verde o rojo a **pantalla completa**, cierre automático a los 3 s, sin texto cortado en el MC33xR (pantalla de 4"). El título va en dos líneas si no cabe.
- **G7:** el paso de lectura cambia según el tipo elegido (UHF para tags en el MC33xR, NFC para calcomanía). No mostrar potencia ni rango de antena.
- **G8:** sin botón "Regresar a modo caseta" (ya está la pestaña).
- **W1:** gráficas tituladas "Flujo vehicular por hora" y "Tipo de vehículo".
- **W5:** la revocación avisa "Se aplicará en las casetas en su próxima sincronización".

## Backend (Dart Frog)

- Rutas en `backend/routes/`, agrupadas por recurso (`/auth`, `/vehiculos`, `/solicitudes`, `/credenciales`, `/movimientos`, `/sync`, `/pases`, `/incidentes`, `/admin`).
- Middleware de autenticación JWT y de autorización por rol; ninguna ruta protegida sin él.
- SQL siempre parametrizado. Nunca concatenar valores en consultas.
- Operaciones de varias tablas (registrar movimiento + abrir/cerrar estancia) en una transacción.
- Errores en formato uniforme: `{"error": {"code": "SNAKE_CASE", "message": "texto para el usuario"}}` con el código HTTP correcto.
- Contraseñas con `bcrypt`. JWT de acceso de 15 min y refresh token guardado como hash en `sesiones`.
- Una ruta protegida se declara con `protegida(context, _manejar, roles: {...})` (`backend/lib/middleware/autenticacion.dart`)
  y lee al usuario con `context.read<UsuarioAutenticado>()`. El pool se obtiene con `context.read<PoolDb>()`.
- Las rutas y los servicios lanzan `ErrorApi`; el middleware de errores lo convierte en respuesta. Una excepción no
  controlada responde 500 `ERROR_INTERNO` y en consola solo quedan método, ruta, tipo de excepción y traza (nunca
  cuerpo, cabeceras ni mensajes, que pueden traer contraseñas o tokens).
- CORS solo acepta el origen de `APP_WEB_URL`. La app móvil no manda `Origin` y no le afecta.
- Pases de visitante firmados con EdDSA; la llave privada solo en variables de entorno, la pública se distribuye a las casetas.
- Fotos en un volumen del VPS, registradas en `archivos`; solo JPEG o PNG, máximo 2 MB. Las fotos de credencial escolar solo las ve un admin.
- Toda escritura administrativa registra un renglón en `auditoria` (antes y después en JSONB).

### Autenticación (Fase 1B)

Rutas en `backend/routes/auth/`; cuerpos y respuestas en JSON con nombres en `snake_case`.

| Ruta | Cuerpo | Respuesta |
| --- | --- | --- |
| `POST /auth/registro` | `nombre`, `correo`, `boleta_o_empleado`, `password` | 201 con tokens y `usuario` |
| `POST /auth/login` | `correo`, `password` | 200 con tokens y `usuario` |
| `POST /auth/refresh` | `refresh_token` | 200 con tokens y `usuario` |
| `POST /auth/logout` | `refresh_token` | 204 (también si el token ya no servía) |
| `GET /auth/me` | (token de acceso) | 200 con `usuario` |
| `POST /auth/cambiar-password` | `password_actual`, `password_nueva` (token de acceso) | 200 con tokens y `usuario` |

"Tokens" es `access_token`, `refresh_token` y `expira_en` (segundos del token de acceso). `usuario` trae `id`, `nombre`,
`correo`, `boleta_o_empleado`, `rol` y `estado`; nunca el hash.

- **Token de acceso:** JWT HS256 de 15 min con los claims `sub` (id del usuario) y `rol`. No se consulta contra la
  base en cada petición: un cambio de rol o una baja tardan hasta 15 min en surtir efecto en las rutas protegidas.
- **Refresh token:** opaco, 32 bytes aleatorios; en `sesiones` solo se guarda su SHA-256. Vigencia de 30 días y
  rotación: cada uso lo revoca y emite uno nuevo.
- **Cambiar contraseña** revoca *todas* las sesiones del usuario y responde con un par de tokens nuevo: el dispositivo
  que hizo el cambio debe guardar esos tokens; los demás quedan fuera.
- **Usuario pendiente:** el registro crea la cuenta con rol `usuario` y estado `pendiente`, y ya puede iniciar sesión
  (inicio de sesión automático). Entran `pendiente` y `activo`; `baja` no entra ni renueva sesión. El inicio de
  sesión no distingue entre pendiente y activo: una ruta que exija cuenta `activo` debe comprobarlo ella misma.
- **Validación de campos:** los validadores viven en `shared/lib/src/validacion/` y devuelven códigos, no textos; la
  app los traduce a mensajes. La lista de dominios de correo sale de `ALLOWED_EMAIL_DOMAINS`.
- **Límite de intentos:** 5 inicios de sesión fallidos por correo en 15 min. Vive en memoria
  (`LimitadorIntentos`): se pierde al reiniciar la API y no se comparte entre instancias (hay una sola).

Códigos de error (`error.code`):

| Código | HTTP | Cuándo |
| --- | --- | --- |
| `VALIDACION` | 422 | Campos inválidos; `error.campos` trae el código de cada campo |
| `DOMINIO_NO_PERMITIDO` | 422 | El correo es válido pero su dominio no está en `ALLOWED_EMAIL_DOMAINS` |
| `CORREO_YA_REGISTRADO` | 409 | Registro con un correo existente |
| `BOLETA_YA_REGISTRADA` | 409 | Registro con una boleta o número de empleado existente |
| `CREDENCIALES_INVALIDAS` | 401 | Login fallido; el mismo error si el correo no existe, la contraseña no coincide o la cuenta está de baja |
| `DEMASIADOS_INTENTOS` | 429 | Sexto intento tras 5 fallidos en 15 min |
| `REFRESH_INVALIDO` | 401 | Refresh token desconocido, vencido, ya usado o revocado |
| `NO_AUTENTICADO` | 401 | Falta el token de acceso, no es válido o venció |
| `SIN_PERMISO` | 403 | El rol no alcanza para la ruta |
| `PASSWORD_ACTUAL_INCORRECTA` | 400 | Cambio de contraseña con la actual equivocada |
| `SOLICITUD_INVALIDA` | 400 | El cuerpo no es un objeto JSON |
| `METODO_NO_PERMITIDO` | 405 | Método HTTP distinto al de la ruta |
| `ERROR_INTERNO` | 500 | Excepción no controlada |

Códigos por campo dentro de `VALIDACION`: `NOMBRE_VACIO`, `NOMBRE_MUY_LARGO`, `CORREO_INVALIDO`, `DOMINIO_NO_PERMITIDO`,
`BOLETA_O_EMPLEADO_INVALIDO` (`BOLETA_INVALIDA` y `NUMERO_EMPLEADO_INVALIDO` si se validan por separado),
`PASSWORD_MUY_CORTA`, `PASSWORD_SIN_LETRA`, `PASSWORD_SIN_NUMERO`.

## Base de datos (PostgreSQL)

- Llaves primarias UUID. Fechas en `timestamptz`. Nombres de tablas y columnas en español y `snake_case`.
- Estados y tipos como `ENUM` de PostgreSQL. `estado_credencial` es `activa`, `perdida`, `revocada` o `vencida`
  (no existe "pendiente": una credencial nace activa cuando Administración la emite o enrola).
- Bajas lógicas (cambio de `estado`); nunca `DELETE` de datos de negocio.
- Reglas garantizadas por la base:
  - **Anti-passback:** `CREATE UNIQUE INDEX ... ON estancias (vehiculo_id) WHERE salida_id IS NULL;`
    y, para visitantes, el mismo índice sobre `(pase_id)`.
  - **Estancias de un vehículo o de un pase:** `estancias` tiene `vehiculo_id` y `pase_id` opcionales, con un CHECK
    de que exactamente uno de los dos tenga valor.
  - **Una credencial activa por identificador:** `CREATE UNIQUE INDEX ... ON credenciales (tipo, identificador) WHERE estado = 'activa';`
  - **Un QR activo por par usuario-vehículo:** índice único parcial en `credenciales (vehiculo_id, usuario_id)
    WHERE tipo = 'qr' AND estado = 'activa'` (`003_qr_unico.sql`).
  - **Credenciales siempre de un vehículo:** `vehiculo_id` es obligatorio para todos los tipos; si `tipo = 'qr'`,
    `usuario_id` también es obligatorio (un QR por cada par usuario-vehículo).
  - **Placa única entre vehículos vigentes:** índice único parcial en `vehiculos (placa) WHERE estado <> 'baja'`.
  - **Movimientos idempotentes:** el `id` del movimiento es el UUID generado en el dispositivo; un reintento con el mismo id no duplica.
- `incidentes` tiene además una columna `folio` con secuencia propia (único), que la interfaz muestra como `INC-0001`.
  Sirve para citar un incidente de viva voz; la llave primaria sigue siendo UUID.
- Tablas: `usuarios`, `vehiculos`, `vehiculo_usuarios`, `credenciales`, `solicitudes`, `pases`, `puertas`, `zonas`,
  `movimientos`, `estancias`, `incidentes`, `dispositivos`, `sesiones`, `restablecimientos`, `archivos`, `auditoria`.

### Decisiones de esquema

Fase 1A (`001_init.sql`):
- **Fotos como FK a `archivos`:** `usuarios.foto_titular_id` y `foto_credencial_id`, `vehiculos.foto_id` y
  `foto_placa_id`, `incidentes.foto_id`. Ninguna tabla guarda rutas de archivo sueltas.
- **`tipos_vehiculo` como arreglo** (`tipo_vehiculo[]`) en `puertas` y `zonas`, en vez de tablas intermedias.
- **`vehiculo_usuarios.activo`:** baja lógica de la autorización de un usuario sobre un vehículo, con `actualizado_en`
  para que la sincronización la vea. Un solo titular por vehículo (índice único parcial `WHERE es_titular`).
- **Restricciones extra:** correo en minúsculas y único; boleta o número de empleado único; formato de placa
  (`^[A-Z0-9-]+$`) en `vehiculos` y `pases`; `archivos` solo JPEG o PNG de hasta 2 MB; `ventana_fin > ventana_inicio`
  en `pases`; `cupo > 0` en `zonas`; un movimiento no lleva credencial y pase a la vez, y todo rechazo o registro
  manual lleva motivo; latitud y longitud de un incidente van juntas; `entrada_id` y `salida_id` únicos en `estancias`.
- **Auditoría de solo inserción:** un trigger rechaza `UPDATE` y `DELETE` sobre `auditoria`.
- **`sslmode=disable` en local:** si la URL de conexión no trae `sslmode`, `abrirConexion` usa `disable` (la base se
  alcanza por localhost o por la red interna de Docker). Para otro caso se agrega `?sslmode=require` a la URL.

Fase 1A.1 (`002_ajustes.sql`):
- **Placa única solo entre vehículos activos o pendientes:** la placa de un vehículo dado de baja se puede volver a registrar.
- **Credenciales:** `vehiculo_id` obligatorio; el QR exige además `usuario_id`. Sustituye al CHECK de "al menos uno".
- **Estancias de visitantes:** `vehiculo_id` opcional, `pase_id` nuevo, exactamente uno de los dos, y anti-passback por pase.
- **`tipo_incidente` como enum:** `antipassback`, `credencial_invalida`, `lectura_fallida`, `inconsistencia_vehiculo`, `otro`.
- **`dispositivos.tipo`** restringido a `mc33xr`, `et401` u `otro`.
- **Puertas sin restricción por tipo:** todo tipo de vehículo entra y sale por cualquiera de las dos puertas; un
  vehículo puede entrar por la Puerta A y salir por la Puerta B. Ambas se siembran con los cuatro tipos.

## Motor de validación (shared)

Función pura en `shared/`, sin IO, con pruebas unitarias para cada rama. Recibe la lectura, la lista de acceso y el estado local; devuelve `Aceptado` o `Rechazado(motivo)`. Orden obligatorio:

1. Normalizar la lectura a un identificador (TID, UID de NFC, código QR/HCE).
2. Ignorar la misma credencial si se leyó hace menos de 5 s (el RFID repite lecturas).
3. QR/HCE: verificar TOTP con tolerancia de ±1 ventana de 30 s; pase de visitante: verificar firma y ventana de horario.
4. Credencial existe en la lista local → si no, `CREDENCIAL_DESCONOCIDA`.
5. Credencial activa y vigente → si no, `CREDENCIAL_INVALIDA`.
6. Vehículo y usuario vigentes → si no, `VEHICULO_O_USUARIO_INACTIVO`.
7. Anti-passback según sentido → si no, `ANTIPASSBACK` (genera incidente).
8. Cupo de la zona en entrada → si no, `ZONA_LLENA`.
9. Aceptado: registrar movimiento local con UUID y encolarlo para sincronizar.

## Hardware (sin código nativo)

- **MC33xR:** RFID y QR llegan por DataWedge a `flutter_datawedge`. El perfil de DataWedge se configura **a mano en el equipo**:
  RFID Input habilitado con TID, Barcode Input habilitado e Intent Output con la acción que espera el paquete (ver su README).
  La fuente de cada lectura (`rfid` o código de barras) se distingue en el resultado.
- **ET401 y celulares:** QR con `mobile_scanner`; NFC con `nfc_manager`.
- **HCE (celular del usuario):** `nfc_host_card_emulation`. Requiere `res/xml/apduservice.xml` y el servicio en `AndroidManifest.xml` (configuración, no código). El paquete tiene años sin actualizarse: si falla, se usa solo QR.
- Todo lector se suscribe al entrar a la pantalla y se libera (`cancel`/`dispose`) al salir.
- Debe existir un modo **"simular lectura"** (solo en depuración) para probar el modo caseta sin hardware.

## Offline y sincronización

- La caseta valida siempre contra `lista_acceso` en SQLite cifrado; nunca espera a la red para decidir.
- La lista se actualiza de forma incremental (por `actualizado_en`) y la caseta muestra la hora de la última sincronización; con más de 15 min muestra aviso.
- Los movimientos se encolan en `movimientos_pendientes` y se envían con su UUID; la API ignora los repetidos.
- La app de usuario guarda en caché sus vehículos e historial; la semilla TOTP va en `flutter_secure_storage`.

## Calidad y Git

- `flutter analyze` y `dart analyze` sin errores ni warnings antes de dar una tarea por terminada.
- Pruebas obligatorias: motor de validación (todas las ramas), migraciones (los índices parciales rechazan duplicados) y endpoints de auth, movimientos y sync.
- Commits pequeños y frecuentes, en español, con Conventional Commits: `feat(caseta): lectura RFID por DataWedge`.
- Documentar con `///` las clases públicas de `shared/` y de los repositorios.

## Cómo trabajar en este repo

- Al empezar una tarea, resume en 3–5 líneas qué vas a hacer y qué archivos vas a tocar.
- Al terminar, reporta cada criterio de aceptación con su evidencia: comando ejecutado y resultado.
- Si algo no se pudo verificar (sobre todo hardware), dilo explícitamente; no lo marques como hecho.
- Si encuentras un problema fuera del alcance, anótalo al final del reporte en vez de arreglarlo.

## Estado por fases

- [ ] Fase 1 — base: monorepo, Docker, migración inicial, API de auth (5–11 oct)
- [ ] Fase 2 — app de usuario: M1–M10, M13 (12–18 oct)
- [ ] Fase 3 — panel web: W2–W5, W7–W11 (19–23 oct)
- [ ] Fase 4 — caseta y motor de validación: G1–G8 (24–31 oct)
- [ ] Fase 5 — offline, sincronización y corte de hardware (1–4 nov)
- [ ] Fase 6 — NFC, HCE, pases (M11, M12, W6), vehículo compartido, dashboard (W1) (5–9 nov)
- [ ] Fase 7 — despliegue en VPS, pulido, documentación y ensayo (10–14 nov)