import 'package:backend/archivos/almacen_archivos.dart';
import 'package:backend/archivos/servicio_archivos.dart';
import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/config/configuracion.dart';
import 'package:backend/config/entorno.dart';
import 'package:backend/correo/enviador_correo.dart';
import 'package:backend/credenciales/servicio_credenciales.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/middleware/cors.dart';
import 'package:backend/middleware/errores.dart';
import 'package:backend/middleware/ruta_no_encontrada.dart';
import 'package:backend/perfil/servicio_perfil.dart';
import 'package:backend/solicitudes/servicio_solicitudes.dart';
import 'package:backend/vehiculos/servicio_vehiculos.dart';
import 'package:dart_frog/dart_frog.dart';

/// Objetos que viven lo que vive el servidor y que las rutas reciben por el
/// contexto de Dart Frog.
class Dependencias {
  /// Arma las dependencias sobre un [pool], una [config] y un enviador de
  /// [correo] dados (pruebas).
  Dependencias({
    required this.pool,
    required this.config,
    required this.correo,
  }) : tokens = ServicioTokens(config.jwtAccessSecret),
       archivos = ServicioArchivos(
         pool: pool,
         almacen: AlmacenArchivos(config.uploadsDir),
       ),
       perfil = ServicioPerfil(pool: pool),
       vehiculos = ServicioVehiculos(pool: pool),
       solicitudes = ServicioSolicitudes(pool: pool),
       credenciales = ServicioCredenciales(pool: pool) {
    auth = ServicioAuth(
      pool: pool,
      config: config,
      tokens: tokens,
      correo: correo,
    );
  }

  /// Arma las dependencias de la API real a partir del entorno.
  ///
  /// Lanza [ErrorDeConfiguracion] si falta alguna variable; en producción,
  /// también si falta `SMTP_HOST`.
  factory Dependencias.desdeEntorno() {
    final config = Configuracion.desdeEntorno();
    return Dependencias(
      pool: abrirPool(exigirEntorno('DATABASE_URL')),
      config: config,
      correo: enviadorCorreoDesdeEntorno(config.entorno),
    );
  }

  /// Pool de conexiones a PostgreSQL.
  final PoolDb pool;

  /// Configuración leída del entorno.
  final Configuracion config;

  /// Emisor y verificador de JWT de acceso.
  final ServicioTokens tokens;

  /// Salida de los correos (SMTP, consola en desarrollo o falso en pruebas).
  final EnviadorCorreo correo;

  /// Reglas de autenticación.
  late final ServicioAuth auth;

  /// Reglas de las fotos subidas.
  final ServicioArchivos archivos;

  /// Reglas del perfil propio.
  final ServicioPerfil perfil;

  /// Consulta de los vehículos de un usuario.
  final ServicioVehiculos vehiculos;

  /// Reglas de las solicitudes de alta, cambio y baja de vehículo.
  final ServicioSolicitudes solicitudes;

  /// Reglas de las credenciales desde el lado del usuario.
  final ServicioCredenciales credenciales;
}

Dependencias? _deProduccion;

/// Dependencias de la API real; se crean una sola vez por proceso.
Dependencias dependenciasDeProduccion() =>
    _deProduccion ??= Dependencias.desdeEntorno();

/// Middleware de la raíz de la API. De afuera hacia adentro: CORS, errores,
/// 404 uniforme e inyección de [PoolDb], [Configuracion], [ServicioTokens],
/// [ServicioAuth], [ServicioArchivos], [ServicioPerfil], [ServicioVehiculos],
/// [ServicioSolicitudes] y [ServicioCredenciales].
Middleware middlewareRaiz(Dependencias dependencias) =>
    (handler) => handler
        .use(provider<PoolDb>((_) => dependencias.pool))
        .use(provider<Configuracion>((_) => dependencias.config))
        .use(provider<ServicioTokens>((_) => dependencias.tokens))
        .use(provider<ServicioAuth>((_) => dependencias.auth))
        .use(provider<ServicioArchivos>((_) => dependencias.archivos))
        .use(provider<ServicioPerfil>((_) => dependencias.perfil))
        .use(provider<ServicioVehiculos>((_) => dependencias.vehiculos))
        .use(provider<ServicioSolicitudes>((_) => dependencias.solicitudes))
        .use(provider<ServicioCredenciales>((_) => dependencias.credenciales))
        .use(rutaNoEncontrada())
        .use(errores())
        .use(cors(dependencias.config.origenWeb));
