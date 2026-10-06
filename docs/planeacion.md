# ParkESCOM — Planeación del proyecto final DAMN

Oct 4, 2026 · @Victor

## Resumen y alcance

ParkESCOM es un sistema de control de acceso vehicular para ESCOM: una app Flutter para Android (usuario y guardia) y un panel web en Flutter Web para administración. Lo desarrolla una sola persona con entrega el 15 de noviembre de 2026; el backend es una API REST en Dart con PostgreSQL, desplegada en un VPS propio.

**Problema:** hoy no hay registro de qué vehículos entran, cuántos hay dentro ni si están autorizados.

**Objetivo:** identificar cada vehículo en la puerta con la credencial adecuada a su tipo, validar reglas de acceso y llevar el conteo de entradas y salidas por hora.

**Credenciales por tipo de vehículo:**

| Tipo | Credencial principal | Verificación o respaldo | Lector |
| --- | --- | --- | --- |
| Auto | Tag RFID UHF (propio o de casetas: TAG, Televía, PASE) | QR dinámico del dueño | MC33xR |
| Moto | QR dinámico o HCE del dueño | Foto del titular y de la placa en pantalla; calcomanía NFC opcional | MC33xR o ET401 |
| Bici, scooter | Calcomanía NFC en el vehículo + QR o HCE del dueño | QR dinámico | ET401 |
| Visitante | QR firmado por el servidor, una entrada y una salida | Registro manual del guardia | MC33xR o ET401 |

**Dentro del alcance:** API propia con PostgreSQL, autenticación con roles, validación de la credencial escolar en el alta, CRUD de vehículos y solicitudes, QR dinámico, lectura RFID por DataWedge, NFC y HCE en Android, motor de validación con anti-passback, pases de visitante, incidentes, dashboard, notificaciones locales y operación offline.

**Fuera del alcance (trabajo futuro):** reconocimiento de placas con cámara fija, lectores fijos con varias antenas, pluma o barrera, Google Wallet, notificaciones push, NFC en iPhone e integración oficial con ESCOM o el IPN. Es un prototipo académico.

## Actores y arquitectura

Tres roles usan el mismo código Flutter en dispositivos distintos, y todos consumen la misma API en el VPS: Nginx recibe HTTPS con certificado de Certbot, la API en Dart Frog aplica permisos por rol y PostgreSQL guarda los datos.

| Actor | Dispositivo | Qué hace |
| --- | --- | --- |
| Usuario (alumno, docente, personal) | Su celular Android | Registra vehículos, muestra su QR o HCE, consulta su historial |
| Guardia | MC33xR o ET401 en cualquiera de las dos puertas; todo tipo de vehículo entra y sale por ambas, y cada equipo se configura con su puerta y sentido al iniciar turno | Opera el modo caseta, registra entradas manuales e incidentes |
| Administrador | Navegador (panel web) + MC33xR para enrolar tags | Aprueba solicitudes, gestiona credenciales, usuarios y reportes |

&#91;embedded content: arquitectura · 3 clientes, API en Dart y PostgreSQL en el VPS\]

La caseta (resaltada) valida contra su lista local y sincroniza después, así que una caída de red no detiene la puerta.

## Requerimientos funcionales

Son 25 requerimientos; los marcados como P1 son obligatorios y los P2 se recortan primero si falta tiempo. La columna "RF profesor" liga cada uno con el documento DAMN-20271.

| ID | Requerimiento | Rol | RF profesor | Prioridad |
| --- | --- | --- | --- | --- |
| RF-01 | Registro con correo institucional, boleta o número de empleado y contraseña; inicio de sesión | Todos | RF1 Registro e ingreso | P1 |
| RF-02 | Recuperación de contraseña por correo | Todos | RF1 Control de sesión | P1 |
| RF-03 | Sesión con JWT de acceso y de renovación; cierre de sesión que invalida el token | Todos | RF1 Control de sesión | P1 |
| RF-04 | Perfil: datos, foto del titular (obligatoria), preferencias y cambio de contraseña | Todos | RF1 Gestión de perfil | P1 |
| RF-05 | Acceso por rol: usuario, guardia, administrador | Todos | RF1 | P1 |
| RF-06 | CRUD de vehículos con foto, tipo, placa, color y modelo; en motos, foto de la placa | Usuario | RF2 CRUD | P1 |
| RF-07 | Foto de la credencial escolar o de empleado en el registro, validada por administración | Usuario | RF3 Cámara | P1 |
| RF-08 | Vehículo compartido: varios usuarios autorizados en un mismo vehículo | Usuario | RF2 CRUD | P2 |
| RF-09 | Solicitudes de alta, cambio y baja de vehículo, con estado | Usuario | RF2 CRUD | P1 |
| RF-10 | QR dinámico que cambia cada 30 s (TOTP) | Usuario | RF3 | P1 |
| RF-11 | Historial de entradas y salidas con búsqueda y filtros | Usuario | RF2 Búsqueda y filtros | P1 |
| RF-12 | Pase de visitante con QR firmado por el servidor | Usuario | RF2 CRUD | P2 |
| RF-13 | Credencial NFC por HCE (acercar el celular) | Usuario | RF3 Hardware | P2 |
| RF-14 | Lectura de tag RFID por DataWedge en modo caseta | Guardia | RF3 Hardware | P1 |
| RF-15 | Lectura de QR (lector del MC33xR o cámara) | Guardia | RF3 Hardware | P1 |
| RF-16 | Lectura de calcomanía NFC y de HCE | Guardia | RF3 Hardware | P2 |
| RF-17 | Verificación visual en caseta: foto del titular, del vehículo y de la placa | Guardia | RF2 Detalle | P1 |
| RF-18 | Motor de validación: vigencia, anti-passback y cupo; resultado verde o rojo | Guardia | RF2 + RF3 | P1 |
| RF-19 | Registro manual de entrada o salida con motivo | Guardia | RF2 CRUD | P1 |
| RF-20 | CRUD de incidentes con foto y ubicación GPS opcional | Guardia | RF2 + RF3 Cámara/GPS | P1 |
| RF-21 | Notificaciones locales: solicitud resuelta, pase aprobado, alerta de lectura inválida | Todos | RF3 Notificaciones | P1 |
| RF-22 | Operación offline: caché de vehículos y QR en la app de usuario; lista de acceso y cola de movimientos en la caseta | Usuario y guardia | RF3 Persistencia local | P1 |
| RF-23 | Aprobar o rechazar solicitudes comparando la credencial escolar; gestionar usuarios y vehículos | Admin (web) | RF2 CRUD | P1 |
| RF-24 | Ligar, revocar o reportar como perdida una credencial; vigencia por semestre | Admin (web + MC33xR) | RF2 CRUD | P1 |
| RF-25 | Dashboard: dentro ahora, entradas y salidas por hora, por tipo de vehículo | Admin y guardia | RF2 Filtros | P2 |

**Navegación (RF3):** barra inferior en la app de usuario, menú lateral en el panel web y pantalla completa en el modo caseta.

## Requerimientos no funcionales

Los criterios de aceptación son los del documento del profesor, más cuatro propios del control de acceso y del VPS (RNF-08 a RNF-11).

| ID | Atributo | Especificación | Criterio de aceptación |
| --- | --- | --- | --- |
| RNF-01 | Tiempo de respuesta | Pantallas con carga asíncrona, sin bloquear el hilo principal; índices en PostgreSQL para las consultas frecuentes | Carga < 2.0 s y transiciones a 60 fps |
| RNF-02 | Diseño adaptativo | Layouts con breakpoints para celular, MC33xR, tablet y web | Sin textos encimados en los 4 tamaños |
| RNF-03 | Usabilidad | Estados de carga (skeleton o spinner) y errores en lenguaje del usuario | Funciones clave en máximo 3 toques |
| RNF-04 | Seguridad | HTTPS/TLS con Nginx y Certbot, contraseñas con bcrypt, JWT en almacenamiento seguro, autorización por rol en la API, límite de intentos de login, secretos en variables de entorno | Cero llaves o secretos en el código ni en Git |
| RNF-05 | Confiabilidad | Manejo global de excepciones, reintentos de red y respuestas de error uniformes en la API | 0 cierres inesperados en la demo |
| RNF-06 | Eficiencia | Liberar streams de DataWedge y NFC al salir de la pantalla; imágenes comprimidas antes de subir | RAM < 180 MB en uso continuo |
| RNF-07 | Mantenibilidad | MVVM, código documentado, Git con commits periódicos, migraciones de base de datos versionadas | Estructura modular por funcionalidad |
| RNF-08 | Decisión en puerta | Validación contra la lista local, sin esperar a la red | Resultado en pantalla < 1 s tras la lectura |
| RNF-09 | Privacidad | Aviso de privacidad, consentimiento al ligar tag de casetas, fotos de credencial visibles solo para administración, retención limitada de movimientos | Aviso visible en el registro |
| RNF-10 | Sincronización | Cada movimiento lleva un UUID generado en el dispositivo; la API ignora duplicados; la caseta muestra la hora de su última sincronización | Sin duplicados tras reintentar 3 veces |
| RNF-11 | Despliegue y respaldo | Docker Compose en el VPS (API y PostgreSQL) detrás de Nginx; Certbot renueva el certificado solo y respaldo diario con pg\_dump | La base se restaura en un entorno limpio |

## Pantallas

Son 32 pantallas en total: 21 en la app móvil y 11 en el panel web. Las 24 marcadas P1 forman el mínimo entregable; varias son listas y formularios que comparten componentes.

**App móvil — comunes y usuario (barra inferior: Inicio, Vehículos, Historial, Perfil)**

| # | Pantalla | Contenido | Prioridad |
| --- | --- | --- | --- |
| M1 | Splash | Revisa sesión y rol, redirige | P1 |
| M2 | Inicio de sesión | Correo, contraseña, enlace a registro y recuperación | P1 |
| M3 | Registro | Correo institucional, boleta o número de empleado, foto del titular y de su credencial, aviso de privacidad, validación en tiempo real | P1 |
| M4 | Recuperar contraseña | Envío de correo | P1 |
| M5 | Inicio (mi credencial) | QR dinámico con contador, botón de HCE, vehículo activo | P1 |
| M6 | Mis vehículos | Lista en tarjetas, búsqueda, filtro por tipo | P1 |
| M7 | Detalle de vehículo | Foto, datos, credenciales ligadas, usuarios autorizados (vehículo compartido), estado, botón para reportar credencial perdida | P1 |
| M8 | Formulario de vehículo | Alta o cambio con fotos del vehículo y, en motos, de la placa (cámara o galería); genera solicitud | P1 |
| M9 | Mis solicitudes | Lista con estado: pendiente, aprobada, rechazada | P1 |
| M10 | Historial | Entradas y salidas, filtros por fecha, vehículo y puerta | P1 |
| M11 | Pases de visitante | Lista de pases y su estado | P2 |
| M12 | Nuevo pase | Nombre, placa, fecha y ventana de horario | P2 |
| M13 | Perfil | Avatar, datos, preferencias de notificaciones, cambiar contraseña (diálogo que pide la actual y la nueva), cerrar sesión | P1 |

**App móvil — guardia y administrador en sitio (MC33xR y ET401)**

| # | Pantalla | Contenido | Prioridad |
| --- | --- | --- | --- |
| G1 | Configurar caseta | Puerta (A o B), sentido (entrada o salida), lectores activos | P1 |
| G2 | Modo caseta | Pantalla completa escuchando RFID, QR y NFC; estado de conexión, hora de la última sincronización y cola offline | P1 |
| G3 | Resultado de validación | Verde o rojo, foto del titular, del vehículo y de la placa, motivo del rechazo | P1 |
| G4 | Registro manual | Búsqueda por placa o usuario, motivo obligatorio | P1 |
| G5 | Incidentes | Lista con filtros por estado | P1 |
| G6 | Formulario de incidente | Foto, descripción, ubicación GPS opcional | P1 |
| G7 | Enrolar credencial | Leer TID con el MC33xR o UID del NFC y ligarlo a un vehículo (solo admin) | P1 |
| G8 | Turno | Vehículos dentro ahora, ocupación por zona y movimientos del turno con búsqueda por placa | P1 |

El panel web no puede leer el MC33xR, por eso el enrolamiento de tags vive en la app móvil con rol de administrador.

**Panel web de administración (Flutter Web, menú lateral)**

| # | Pantalla | Contenido | Prioridad |
| --- | --- | --- | --- |
| W1 | Dashboard | Dentro ahora, entradas y salidas por hora, por tipo de vehículo | P2 |
| W2 | Solicitudes | Bandeja para aprobar o rechazar con comentario, comparando la foto de la credencial con los datos del registro | P1 |
| W3 | Usuarios | Tabla con búsqueda; alta, baja y cambio de rol | P1 |
| W4 | Vehículos | Tabla con filtros por tipo y estado | P1 |
| W5 | Credenciales | Revocar, reportar perdida, vigencia | P1 |
| W6 | Pases de visitante | Aprobar y consultar pases | P2 |
| W7 | Movimientos | Bitácora con filtros y exportación a CSV | P2 |
| W8 | Incidentes | Seguimiento y cambio de estado | P2 |
| W9 | Configuración | Puertas, zonas y cupos | P2 |
| W10 | Bitácora de auditoría | Quién cambió qué y cuándo | P2 |
| W11 | Nueva contraseña | Página pública que abre el enlace del correo de recuperación; valida el token y pide la nueva contraseña. Sirve para usuarios de cualquier dispositivo | P1 |

El inicio de sesión y el perfil se comparten entre móvil y web porque es el mismo código.

## Flujos principales

Toda lectura, venga de RFID, QR, NFC o HCE, termina en el mismo motor de validación; lo único que cambia es cómo llega la credencial.

**Motor de validación (orden de revisión)**

1. Normalizar la lectura a un identificador: TID, UID de NFC o token de QR/HCE.
2. Ignorar la misma credencial si se leyó hace menos de 5 s. Va antes que todo lo demás porque el RFID lee el mismo tag varias veces y, si no, cada repetición dispararía un falso anti-passback.
3. Si es QR o HCE, verificar el código TOTP con tolerancia de una ventana (±30 s) o la firma del pase de visitante.
4. Buscar la credencial en la lista local. No existe → rojo "credencial desconocida".
5. Credencial activa y vigente. Si no → rojo "revocada, perdida o vencida".
6. Vehículo y usuario vigentes. Si no → rojo "vehículo o usuario dado de baja".
7. Anti-passback: en entrada no debe haber una entrada abierta; en salida debe existir una. Si falla → rojo y se crea un incidente.
8. Cupo de la zona en entrada. Lleno → rojo "zona llena".
9. Guardar el movimiento en SQLite, mostrar verde con foto y placa, y sincronizar con la API cuando haya red.

**Alta de vehículo y credencial**

1. El usuario se registra con correo institucional, boleta o número de empleado, foto suya y foto de su credencial escolar.
2. Captura el vehículo en M8 con foto; en motos, también foto de la placa. Se crea una solicitud.
3. Administración compara la credencial con los datos y aprueba en W2; el usuario recibe una notificación local.
4. En sitio, el administrador abre G7, lee el TID del tag (propio o de casetas) o el UID de la calcomanía NFC y lo liga al vehículo. Las motos sin calcomanía quedan solo con QR del dueño.
5. La credencial queda activa con vigencia al fin del semestre y entra a la lista local de las casetas en la siguiente sincronización.

**Entrada de auto**

1. El MC33xR en modo caseta lee el tag por DataWedge.
2. El motor valida y el guardia ve verde con la foto del auto; confirma de un vistazo que coincida.
3. Sin lectura, el conductor muestra su QR dinámico y se valida igual.

**Moto**

Hoy el control de motos se basa en fotografiar la credencial y la placa; el sistema hace esa captura una sola vez en el alta y la muestra en cada paso.

1. Entrada: el dueño muestra su QR dinámico o acerca su celular (HCE).
2. La caseta muestra la foto del titular y la de la placa registrada; el guardia compara con la persona y la moto que tiene enfrente.
3. Salida: misma credencial y misma verificación; si quien sale no es el titular ni un usuario autorizado del vehículo → alerta.

**Bici o scooter**

1. Entrada: basta la calcomanía NFC del vehículo, el QR o el HCE del dueño.
2. Salida: se piden ambas, la credencial del dueño y la NFC del vehículo, y deben pertenecer al mismo registro. Si no coinciden → alerta de posible robo.

**Visitante**

1. Un usuario solicita el pase en M12 y administración lo aprueba en W6.
2. La API firma el pase (JWT con EdDSA) y el usuario comparte la imagen del QR con su visitante; el visitante no necesita la app.
3. La caseta verifica la firma con la llave pública, sin red: válido para una entrada y una salida dentro de su ventana de horario; después queda inválido.

**Excepciones**

- Sin red: la caseta decide con la lista local y encola movimientos con UUID; si dos casetas registran el mismo vehículo sin red, la API ordena por hora y marca el conflicto como incidente.
- Lista desactualizada: si la última sincronización tiene más de 15 min, la caseta muestra un aviso, porque una revocación reciente aún no llega.
- Reloj desfasado: el TOTP depende de la hora; los dispositivos usan hora automática de red y la caseta acepta una ventana de tolerancia.
- Credencial perdida: el usuario la reporta o el admin la revoca; deja de ser válida en la siguiente sincronización.
- Registro manual (G4): siempre con motivo, y queda en la bitácora de auditoría.

## Modelo de datos

PostgreSQL es la fuente de verdad con 16 tablas; dos reglas críticas, anti-passback y una sola credencial activa por identificador, las garantiza la propia base con índices parciales.

**Por qué PostgreSQL y no MySQL:** los índices parciales (`UNIQUE ... WHERE`) hacen cumplir esas dos reglas aunque haya un error en la API; MySQL no los tiene y habría que simularlos. Además, `JSONB` guarda el antes y después de la auditoría, y `timestamptz` evita líos de zona horaria entre dispositivos.

**PostgreSQL (servidor)**

| Tabla | Campos clave | Restricciones |
| --- | --- | --- |
| `usuarios` | correo, hash\_password, nombre, boleta\_o\_empleado, rol, foto\_titular, foto\_credencial, estado, vigencia | correo y boleta únicos; rol como enum |
| `vehiculos` | tipo, placa o número de serie, marca, modelo, color, foto, foto\_placa, estado | placa única entre vehículos que no están de baja; solo letras, números y guiones |
| `vehiculo_usuarios` | vehiculo\_id, usuario\_id, es\_titular | llave compuesta; un titular por vehículo |
| `credenciales` | vehiculo\_id (obligatorio), usuario\_id (obligatorio en QR), tipo (tag\_propio, tag\_caseta, nfc, qr), identificador, semilla\_totp cifrada, estado, vigencia, consentimiento | único (tipo, identificador) WHERE estado = activa |
| `solicitudes` | usuario\_id, vehiculo\_id, tipo (alta, cambio, baja), datos propuestos en JSONB, estado, comentario, resuelta\_por | estado como enum |
| `pases` | solicitante\_id, visitante, placa, ventana\_inicio, ventana\_fin, estado, jti | jti único (id del token firmado) |
| `puertas` | nombre, tipos de vehículo que atiende | — |
| `zonas` | nombre, tipo de vehículo, cupo | cupo > 0 |
| `movimientos` | id (UUID del dispositivo), vehiculo\_id, credencial\_id o pase\_id, puerta\_id, sentido, hora\_dispositivo, hora\_servidor, fuente, dispositivo\_id, resultado, motivo | el UUID como llave evita duplicados al reintentar |
| `estancias` | vehiculo\_id o pase\_id (exactamente uno), entrada\_id, salida\_id, zona\_id | único (vehiculo\_id) y único (pase\_id) WHERE salida\_id IS NULL = anti-passback, también para visitantes |
| `incidentes` | folio (secuencia propia, se muestra como INC-0001), tipo, descripción, foto, latitud, longitud, estado, movimiento\_id | estado como enum |
| `dispositivos` | nombre, tipo, puerta\_id, hash del token, última sincronización, activo | revocable si se pierde el equipo |
| `sesiones` | usuario\_id, hash del refresh token, expira, revocada | para cerrar sesión de verdad |
| `restablecimientos` | usuario\_id, hash del token, expira, usado | uso único |
| `archivos` | ruta en el volumen, tipo MIME, tamaño, dueño | solo JPEG o PNG, máximo 2 MB |
| `auditoria` | actor\_id, acción, entidad, entidad\_id, antes y después en JSONB, fecha | solo inserción |

Las bajas son lógicas (cambio de estado), nunca borrado físico, para no romper el historial.

**SQLite en los dispositivos**

| Dónde | Tabla | Uso |
| --- | --- | --- |
| Caseta | `lista_acceso` | identificador, credencial, placa, fotos en caché, estado, vigencia y semilla; base cifrada con SQLCipher |
| Caseta | `movimientos_pendientes` | Cola offline con el UUID de cada movimiento |
| Caseta | `estado_dentro` | Anti-passback local mientras no hay red |
| Caseta | `config` | Puerta, sentido, llave pública para pases, hora de la última sincronización |
| Usuario | `mis_vehiculos`, `historial` | Consultar sin red; la semilla del QR va en almacenamiento seguro |

La ocupación de cada zona se calcula con las estancias abiertas, y un administrador puede cerrar una estancia a mano con motivo cuando una lectura fallida la deja abierta.

## Stack y estructura

Todo es Dart: la app Flutter (Android y web), el backend en Dart Frog y un paquete compartido con los modelos y el motor de validación, que así se escribe y se prueba una sola vez.

**Monorepo**

```
parkescom/
  app/                 # Flutter: app Android + panel web
  backend/             # Dart Frog: API REST
  shared/              # paquete Dart: modelos, motor de validación, TOTP, verificación de pases
  db/migrations/       # 001_init.sql, 002_..., aplicadas en orden al arrancar
  docker-compose.yml   # api, postgres
  nginx/parkescom.conf # proxy: /api → backend, / → panel web; TLS con Certbot
  .env.example         # nombres de variables, sin valores reales
```

**Backend**

| Necesidad | Paquete | Nota |
| --- | --- | --- |
| Servidor y rutas | `dart_frog` | Rutas por archivo y middleware de autenticación por rol |
| PostgreSQL | `postgres` | Consultas parametrizadas, transacciones para entrada y salida |
| Contraseñas | `bcrypt` | Hash con sal |
| Tokens | `dart_jsonwebtoken` | JWT de acceso (15 min) y renovación; pases firmados con EdDSA |
| Correo | `mailer` | Recuperación de contraseña por SMTP |
| TOTP y UUID | `otp`, `uuid` | Desde el paquete shared |

Se descartó Serverpod: trae autenticación y ORM para PostgreSQL, pero su generación de código y curva de aprendizaje no compensan con el plazo que tenemos.

**App Flutter**

| Necesidad | Paquete | Nota |
| --- | --- | --- |
| Estado y MVVM | `flutter_riverpod` | ViewModels como Notifiers |
| Navegación | `go_router` | Rutas por rol |
| HTTP | `dio` | Interceptor que renueva el JWT |
| Almacenamiento seguro | `flutter_secure_storage` | Tokens y semilla del QR |
| Persistencia local | `sqflite_sqlcipher` | SQLite cifrado; no se usa en web |
| Segundo plano | `workmanager` | Revisa cambios cada 15 min (mínimo de Android) y dispara notificaciones locales |
| Notificaciones | `flutter_local_notifications` | Solicitudes, pases y alertas |
| QR | `otp` + `qr_flutter` | Código de 30 s, verificable sin red |
| RFID y lector Zebra | `flutter_datawedge` | Perfil DataWedge con RFID Input (TID) e Intent Output |
| QR por cámara | `mobile_scanner` | Respaldo en ET401 y celulares |
| NFC lector | `nfc_manager` | Calcomanías NFC y lectura de HCE |
| NFC emulación | `nfc_host_card_emulation` | HCE solo en Android |
| Cámara y fotos | `image_picker`, `flutter_image_compress` | Fotos comprimidas antes de subir |
| Imágenes | `cached_network_image` | Fotos de titular y placa en caché para la caseta |
| GPS | `geolocator` | Ubicación opcional del incidente |
| Red | `connectivity_plus` | Dispara la sincronización |
| Gráficas | `fl_chart` | Dashboard por hora |

**Estructura de la app (MVVM por funcionalidad)**

```
app/lib/
  core/          # tema, router, cliente HTTP, errores
  data/
    repositories/
    sources/
      remote/    # API
      local/     # SQLite, secure storage
      hardware/  # DataWedge, NFC, HCE (solo Android)
  features/
    auth/  vehiculos/  solicitudes/  credencial/  historial/
    pases/  caseta/  incidentes/  admin/  perfil/
      # cada una: view/ + viewmodel/
  main.dart
```

**Sin código nativo propio:** permisos y servicio HCE en `AndroidManifest.xml`, el AID en `res/xml/apduservice.xml` y el perfil DataWedge configurado a mano en el MC33xR. Los paquetes de hardware y SQLite son solo Android, así que se cargan con importaciones condicionales y `kIsWeb` para que compile el panel web.

**Secretos:** URL de la base, llaves JWT, llave privada de pases y SMTP van en variables de entorno del VPS; el repositorio solo tiene `.env.example`.

## Plan de trabajo

La entrega es el 15 de noviembre: el hardware se prueba el 5 de octubre y se decide el 4 de noviembre, y la última semana queda solo para despliegue, pulido, documentación y ensayo. Con 6 semanas caben todos los P2; solo se recortan si el corte lo exige.

&#91;embedded content: plan de trabajo · 6 semanas, corte de hardware el 4 de noviembre\]

**Fase 1 — base (5 a 11 de octubre)**

- [ ] Prueba de viabilidad: perfil DataWedge con RFID + TID, lectura de QR, HCE celular → ET401, tag de casetas
- [ ] Monorepo en Git (app, backend, shared) y Docker Compose local con PostgreSQL
- [ ] Migración inicial con las 16 tablas, índices parciales y datos de prueba
- [ ] API: registro, login, JWT con renovación, recuperación por correo, middleware por rol, subida de fotos

**Fase 2 — app de usuario (12 a 18 de octubre)**

- [ ] Login, registro con foto del titular y de la credencial, perfil (M1–M4, M13)
- [ ] Vehículos y solicitudes con fotos (M6–M9) y QR dinámico (M5)
- [ ] Historial (M10) y notificaciones locales con workmanager

**Fase 3 — panel web (19 a 23 de octubre)**

- [ ] Solicitudes, usuarios, vehículos y credenciales (W2–W5)
- [ ] Movimientos, incidentes, configuración y auditoría (W7–W10)

**Fase 4 — caseta y motor (24 al 31 de octubre)**

- [ ] Motor de validación en el paquete shared, con pruebas unitarias
- [ ] Modo caseta con DataWedge: RFID y QR, con foto del titular, vehículo y placa (G1–G3)
- [ ] Enrolar credencial con el MC33xR (G7)
- [ ] Registro manual e incidentes con cámara y GPS (G4–G6)

**Fase 5 — offline y corte (1 a 4 de noviembre)**

- [ ] Sincronización: lista de acceso incremental, cola de movimientos con UUID, aviso de lista desactualizada
- [ ] Decisión de corte: lo que no funcione en hardware pasa a simulado

**Fase 6 — extras (5 a 9 de noviembre)**

- [ ] NFC de bicis y salida antirrobo; HCE si pasó la prueba
- [ ] Pases de visitante firmados (M11, M12, W6), vehículo compartido y dashboard (W1)

**Fase 7 — cierre (10 a 14 de noviembre)**

- [ ] Despliegue en el VPS: subdominio, Nginx con Certbot, variables de entorno, respaldo con pg\_dump
- [ ] Pulido responsivo, estados de carga y manejo global de errores
- [ ] Diagramas UML y documento técnico
- [ ] Ensayo del guion de demo dos veces con los equipos reales y contra el VPS

## Riesgos y planes B

Los tres riesgos técnicos más altos se prueban el día 1; ninguno tumba el proyecto porque el QR dinámico cubre todos los flujos.

| Riesgo | Probabilidad | Impacto | Plan B |
| --- | --- | --- | --- |
| DataWedge no entrega RFID en el MC33xR (hay reportes tras actualizaciones de DataWedge) | Media | Alto | Botón "simular lectura" con TIDs de prueba; RFID documentado como diseño |
| Los tags de casetas no responden o no son EPC Gen2 | Media | Medio | Tag propio de ESCOM para todos; casetas como opción futura |
| `nfc_host_card_emulation` falla con la versión actual de Flutter (tiene unos 3 años sin actualizarse) | Media | Medio | Solo QR dinámico + calcomanía NFC |
| La ET401 no trae NFC | Por confirmar | Medio | NFC en el MC33xR si su modelo lo trae; si no, QR con foto |
| El backend propio consume más tiempo del previsto | Alta | Alto | Sin refresh token (solo JWT de 8 h) y recuperación de contraseña por el admin en vez de correo |
| El VPS falla o no responde el día de la demo | Media | Alto | Docker Compose en la laptop con la misma configuración; el celular se conecta por la red local |
| La red de la escuela bloquea el VPS o falla en la demo | Media | Alto | Hotspot propio; demostrar el modo offline a propósito |
| Android rechaza HTTP sin cifrar durante el desarrollo | Alta | Bajo | Excepción de red solo en el build de depuración; HTTPS en la demo |
| Reloj desfasado entre celular y caseta rompe el TOTP | Baja | Medio | Hora automática de red y tolerancia de una ventana |
| Se acaba el tiempo | Alta | Alto | Recortar P2 en este orden: HCE, pases de visitante, vehículo compartido, dashboard, panel web secundario |
| Desfase del conteo por lecturas fallidas | Alta en uso real | Bajo en demo | Cierre manual de la estancia con motivo |

**Regla de corte:** el 4 de noviembre, lo que no funcione en el hardware pasa a simulado y se documenta como arquitectura objetivo. Las semanas siguientes no se usan para pelear con hardware.

## Entregables y rúbrica

Cada criterio de la rúbrica tiene evidencia concreta que se puede mostrar en la defensa.

| Criterio (peso) | Qué se muestra | Evidencia |
| --- | --- | --- |
| Cumplimiento funcional (40%) | Login por rol, CRUD de vehículos y solicitudes, lectura RFID/QR/NFC, notificaciones, modo offline | Demo en vivo con guion y datos de prueba |
| Arquitectura y código (30%) | MVVM por funcionalidad, motor de validación aislado con pruebas unitarias | Monorepo Git (app, backend, shared) con commits diarios, migraciones y README |
| UI/UX y RNF (20%) | Responsivo en celular, MC33xR, tablet y web; estados de carga; carga < 2 s | Mockups de Stitch en docs/design/, capturas en los 4 tamaños y medición con DevTools |
| Documentación y exposición (10%) | Requerimientos, diagramas UML, arquitectura y trabajo futuro | Documento técnico + presentación |

**Diagramas UML a entregar**

- [ ] Casos de uso con 3 actores: usuario, guardia, administrador
- [ ] Clases del modelo de datos
- [ ] Secuencia: entrada de auto por RFID
- [ ] Secuencia: alta de vehículo y enrolamiento de credencial
- [ ] Estados de la credencial: activa, perdida, revocada, vencida
- [ ] Actividad del motor de validación
- [ ] Despliegue: dispositivos, VPS (Nginx, API, PostgreSQL) y panel web

**Guion de demo (8 a 10 minutos)**

1. Usuario se registra con foto propia y de su credencial, y da de alta un auto y una moto.
2. Admin compara la credencial y aprueba en la web; llega la notificación al usuario.
3. Admin enrola el tag del auto con el MC33xR.
4. Caseta: lectura del tag en verde; segunda lectura de entrada en rojo por anti-passback.
5. Moto: QR del dueño y en pantalla la foto del titular y de la placa.
6. Tag revocado en la web, lectura en rojo con alerta.
7. Bici: salida con NFC y QR de otro dueño, alerta de posible robo.
8. Modo avión: lecturas en cola y sincronización al volver la red, sin duplicados.
9. Dashboard con entradas y salidas por hora.
