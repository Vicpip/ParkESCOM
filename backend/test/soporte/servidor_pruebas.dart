import 'dart:convert';
import 'dart:io';

import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/config/configuracion.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/db/migrador.dart';
import 'package:backend/dependencias.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:dart_frog/dart_frog.dart';

import '../../routes/auth/cambiar-password/index.dart' as cambiar_password;
import '../../routes/auth/login.dart' as login;
import '../../routes/auth/logout.dart' as logout;
import '../../routes/auth/me.dart' as me;
import '../../routes/auth/refresh.dart' as refresh;
import '../../routes/auth/registro.dart' as registro;
import 'base_pruebas.dart';

/// Origen que las pruebas configuran como panel web.
const origenWebDePruebas = 'https://panel.pruebas.example';

/// Respuesta HTTP ya leída: código, cabeceras y cuerpo JSON (o `null`).
typedef Respuesta = ({int estado, HttpHeaders cabeceras, Object? json});

/// API real (rutas de `routes/` y middleware raíz) escuchando en un puerto
/// libre de localhost, sobre la base de pruebas recién migrada.
class ServidorPruebas {
  ServidorPruebas._(this.dependencias, this._servidor);

  /// Recrea la base de pruebas, aplica las migraciones y levanta la API.
  static Future<ServidorPruebas> levantar() async {
    final url = await recrearBaseDePruebas();
    final conexion = await abrirConexion(url);
    try {
      await Migrador(conexion, raizDb: Migrador.buscarRaizDb()).migrar();
    } finally {
      await conexion.close();
    }

    final dependencias = Dependencias(
      pool: abrirPool(url),
      config: Configuracion(
        // Secreto aleatorio por corrida: las pruebas no usan el del entorno.
        jwtAccessSecret: generarRefreshToken(),
        origenWeb: origenWebDePruebas,
        dominiosPermitidos: {'ipn.mx', 'alumno.ipn.mx'},
        // El costo mínimo de bcrypt, para que las pruebas no tarden.
        costoBcrypt: 4,
      ),
    );
    final rutas = Router()
      ..all('/auth/registro', registro.onRequest)
      ..all('/auth/login', login.onRequest)
      ..all('/auth/refresh', refresh.onRequest)
      ..all('/auth/logout', logout.onRequest)
      ..all('/auth/me', me.onRequest)
      ..all('/auth/cambiar-password', cambiar_password.onRequest)
      // Rutas que solo existen en las pruebas.
      ..all(
        '/pruebas/solo-admin',
        (RequestContext context) => protegida(
          context,
          (_) => Response.json(body: {'ok': true}),
          roles: {Rol.admin},
        ),
      )
      ..all(
        '/pruebas/falla',
        (RequestContext context) => throw StateError('falla de prueba'),
      );
    final servidor = await serve(
      middlewareRaiz(dependencias)(rutas.call),
      InternetAddress.loopbackIPv4,
      0,
    );
    return ServidorPruebas._(dependencias, servidor);
  }

  /// Dependencias con las que corre la API (pool, configuración, servicios).
  final Dependencias dependencias;

  final HttpServer _servidor;
  final _cliente = HttpClient();

  /// Pool sobre la base de pruebas, para preparar y revisar datos.
  PoolDb get pool => dependencias.pool;

  /// Hace una petición a la API. [cuerpo] se manda como JSON y [token] como
  /// `Authorization: Bearer`.
  Future<Respuesta> pedir(
    String metodo,
    String ruta, {
    Object? cuerpo,
    String? token,
    Map<String, String> cabeceras = const {},
  }) async {
    final peticion = await _cliente.open(
      metodo,
      _servidor.address.host,
      _servidor.port,
      ruta,
    );
    cabeceras.forEach(peticion.headers.set);
    if (token != null) {
      peticion.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (cuerpo != null) {
      peticion.headers.contentType = ContentType.json;
      peticion.write(cuerpo is String ? cuerpo : jsonEncode(cuerpo));
    }
    final respuesta = await peticion.close();
    final texto = await utf8.decodeStream(respuesta);
    Object? json;
    try {
      json = texto.isEmpty ? null : jsonDecode(texto);
    } on FormatException {
      json = null;
    }
    return (
      estado: respuesta.statusCode,
      cabeceras: respuesta.headers,
      json: json,
    );
  }

  /// `POST` con cuerpo JSON.
  Future<Respuesta> post(String ruta, {Object? cuerpo, String? token}) => pedir(
    'POST',
    ruta,
    cuerpo: cuerpo ?? const <String, Object?>{},
    token: token,
  );

  /// `GET`.
  Future<Respuesta> get(String ruta, {String? token}) =>
      pedir('GET', ruta, token: token);

  /// Detiene la API y cierra el pool.
  Future<void> cerrar() async {
    _cliente.close(force: true);
    await _servidor.close(force: true);
    await pool.close();
  }
}
