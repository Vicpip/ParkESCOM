import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/config/configuracion.dart';
import 'package:backend/config/entorno.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/middleware/cors.dart';
import 'package:backend/middleware/errores.dart';
import 'package:dart_frog/dart_frog.dart';

/// Objetos que viven lo que vive el servidor y que las rutas reciben por el
/// contexto de Dart Frog.
class Dependencias {
  /// Arma las dependencias sobre un [pool] y una [config] dados (pruebas).
  Dependencias({required this.pool, required this.config})
    : tokens = ServicioTokens(config.jwtAccessSecret) {
    auth = ServicioAuth(pool: pool, config: config, tokens: tokens);
  }

  /// Arma las dependencias de la API real a partir del entorno.
  ///
  /// Lanza [ErrorDeConfiguracion] si falta alguna variable.
  factory Dependencias.desdeEntorno() => Dependencias(
    pool: abrirPool(exigirEntorno('DATABASE_URL')),
    config: Configuracion.desdeEntorno(),
  );

  /// Pool de conexiones a PostgreSQL.
  final PoolDb pool;

  /// Configuración leída del entorno.
  final Configuracion config;

  /// Emisor y verificador de JWT de acceso.
  final ServicioTokens tokens;

  /// Reglas de autenticación.
  late final ServicioAuth auth;
}

Dependencias? _deProduccion;

/// Dependencias de la API real; se crean una sola vez por proceso.
Dependencias dependenciasDeProduccion() =>
    _deProduccion ??= Dependencias.desdeEntorno();

/// Middleware de la raíz de la API. De afuera hacia adentro: CORS, errores e
/// inyección de [PoolDb], [Configuracion], [ServicioTokens] y [ServicioAuth].
Middleware middlewareRaiz(Dependencias dependencias) =>
    (handler) => handler
        .use(provider<PoolDb>((_) => dependencias.pool))
        .use(provider<Configuracion>((_) => dependencias.config))
        .use(provider<ServicioTokens>((_) => dependencias.tokens))
        .use(provider<ServicioAuth>((_) => dependencias.auth))
        .use(errores())
        .use(cors(dependencias.config.origenWeb));
