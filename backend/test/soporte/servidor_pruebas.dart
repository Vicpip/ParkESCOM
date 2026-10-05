import 'dart:convert';
import 'dart:io';

import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/config/configuracion.dart';
import 'package:backend/correo/enviador_correo.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/db/migrador.dart';
import 'package:backend/dependencias.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

import '../../routes/archivos/[id].dart' as archivo;
import '../../routes/archivos/index.dart' as archivos;
import '../../routes/auth/cambiar-password/index.dart' as cambiar_password;
import '../../routes/auth/login.dart' as login;
import '../../routes/auth/logout.dart' as logout;
import '../../routes/auth/me.dart' as me;
import '../../routes/auth/olvide-password.dart' as olvide_password;
import '../../routes/auth/refresh.dart' as refresh;
import '../../routes/auth/registro.dart' as registro;
import '../../routes/auth/restablecer.dart' as restablecer;
import '../../routes/perfil/index.dart' as perfil;
import 'base_pruebas.dart';

/// Origen que las pruebas configuran como panel web.
const origenWebDePruebas = 'https://panel.pruebas.example';

/// Contraseña de las cuentas que crea [ServidorPruebas.crearCuenta].
const passwordDePruebas = 'Prueba-2026';

/// Respuesta HTTP ya leída: código, cabeceras, cuerpo JSON (o `null` si no
/// lo es) y cuerpo en bytes.
typedef Respuesta = ({
  int estado,
  HttpHeaders cabeceras,
  Object? json,
  List<int> bytes,
});

/// Cuenta creada por [ServidorPruebas.crearCuenta], con sesión abierta.
typedef Cuenta = ({String id, String correo, String token, String refresh});

/// [EnviadorCorreo] que no envía nada: guarda los correos para revisarlos.
class EnviadorFalso implements EnviadorCorreo {
  /// Correos "enviados", en orden.
  final correos = <CorreoSaliente>[];

  static final _enlace = RegExp(r'https?://\S+');

  /// Enlace que trae el último correo enviado a [destinatario], o `null` si
  /// no se le envió ninguno.
  String? enlacePara(String destinatario) {
    for (final correo in correos.reversed) {
      if (correo.destinatario == destinatario) {
        return _enlace.firstMatch(correo.texto)?.group(0);
      }
    }
    return null;
  }

  @override
  Future<void> enviar(CorreoSaliente correo) async => correos.add(correo);
}

/// API real (rutas de `routes/` y middleware raíz) escuchando en un puerto
/// libre de localhost, sobre la base de pruebas recién migrada.
class ServidorPruebas {
  ServidorPruebas._(
    this.dependencias,
    this._servidor,
    this.correo,
    this.carpetaUploads,
  );

  /// Recrea la base de pruebas, aplica las migraciones y levanta la API.
  static Future<ServidorPruebas> levantar() async {
    final url = await recrearBaseDePruebas();
    final conexion = await abrirConexion(url);
    try {
      await Migrador(conexion, raizDb: Migrador.buscarRaizDb()).migrar();
    } finally {
      await conexion.close();
    }

    // Cada corrida sube sus fotos a una carpeta temporal propia; dentro va
    // `uploads` para poder revisar que nada se escribe en la carpeta padre.
    final temporal = await Directory.systemTemp.createTemp('parkescom_');
    final carpetaUploads = Directory(
      '${temporal.path}${Platform.pathSeparator}uploads',
    );
    final correo = EnviadorFalso();
    final dependencias = Dependencias(
      pool: abrirPool(url),
      correo: correo,
      config: Configuracion(
        // Secreto aleatorio por corrida: las pruebas no usan el del entorno.
        jwtAccessSecret: generarRefreshToken(),
        urlWeb: origenWebDePruebas,
        dominiosPermitidos: {'ipn.mx', 'alumno.ipn.mx'},
        uploadsDir: carpetaUploads.path,
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
      ..all('/auth/olvide-password', olvide_password.onRequest)
      ..all('/auth/restablecer', restablecer.onRequest)
      ..all('/archivos', archivos.onRequest)
      ..all('/archivos/<id>', archivo.onRequest)
      ..all('/perfil', perfil.onRequest)
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
    return ServidorPruebas._(dependencias, servidor, correo, carpetaUploads);
  }

  /// Correos que la API "envió" durante la corrida.
  final EnviadorFalso correo;

  /// Carpeta temporal donde esta corrida guarda las fotos (`UPLOADS_DIR`).
  final Directory carpetaUploads;

  var _cuentas = 0;

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
    if (cuerpo is List<int>) {
      // Cuerpo binario ya armado: el Content-Type viene en [cabeceras].
      peticion
        ..contentLength = cuerpo.length
        ..add(cuerpo);
    } else if (cuerpo != null) {
      peticion.headers.contentType = ContentType.json;
      peticion.write(cuerpo is String ? cuerpo : jsonEncode(cuerpo));
    }
    final respuesta = await peticion.close();
    final bytes = await respuesta.fold<List<int>>(
      [],
      (todos, trozo) => todos..addAll(trozo),
    );
    Object? json;
    try {
      json = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    } on FormatException {
      json = null;
    }
    return (
      estado: respuesta.statusCode,
      cabeceras: respuesta.headers,
      json: json,
      bytes: bytes,
    );
  }

  /// `PATCH` con cuerpo JSON.
  Future<Respuesta> patch(String ruta, {Object? cuerpo, String? token}) =>
      pedir(
        'PATCH',
        ruta,
        cuerpo: cuerpo ?? const <String, Object?>{},
        token: token,
      );

  /// `POST /archivos` con un formulario `multipart/form-data` armado a mano.
  ///
  /// [nombre] y [tipoDeclarado] son lo que el cliente dice del archivo; la
  /// API debe ignorarlos. Con [propositoPrimero] el campo `proposito` va
  /// antes del archivo en vez de después.
  Future<Respuesta> subir(
    List<int> contenido, {
    String? proposito = 'perfil',
    String? token,
    String nombre = 'foto.png',
    String tipoDeclarado = 'image/png',
    bool propositoPrimero = false,
  }) {
    const limite = '----parkescom-pruebas-7f3a9c';
    final campoProposito = proposito == null
        ? <int>[]
        : utf8.encode(
            '--$limite\r\n'
            'Content-Disposition: form-data; name="proposito"\r\n\r\n'
            '$proposito\r\n',
          );
    final campoArchivo = [
      ...utf8.encode(
        '--$limite\r\n'
        'Content-Disposition: form-data; name="archivo"; '
        'filename="$nombre"\r\n'
        'Content-Type: $tipoDeclarado\r\n\r\n',
      ),
      ...contenido,
      ...utf8.encode('\r\n'),
    ];
    return pedir(
      'POST',
      '/archivos',
      token: token,
      cabeceras: {
        HttpHeaders.contentTypeHeader: 'multipart/form-data; boundary=$limite',
      },
      cuerpo: [
        if (propositoPrimero) ...campoProposito,
        ...campoArchivo,
        if (!propositoPrimero) ...campoProposito,
        ...utf8.encode('--$limite--\r\n'),
      ],
    );
  }

  /// Registra una cuenta nueva con [passwordDePruebas], le pone [rol] y
  /// [estado] directo en la base y le abre sesión (el token ya trae el rol).
  Future<Cuenta> crearCuenta({
    Rol rol = Rol.usuario,
    String estado = 'activo',
  }) async {
    _cuentas++;
    final correo = 'cuenta$_cuentas@alumno.ipn.mx';
    final registro = await post(
      '/auth/registro',
      cuerpo: {
        'nombre': 'Cuenta de Prueba $_cuentas',
        'correo': correo,
        'boleta_o_empleado': '${2027000000 + _cuentas}',
        'password': passwordDePruebas,
      },
    );
    if (registro.estado != HttpStatus.created) {
      throw StateError('No se pudo registrar $correo: ${registro.json}');
    }
    await pool.execute(
      Sql.named(
        'UPDATE usuarios SET rol = CAST(@rol:text AS rol_usuario), '
        'estado = CAST(@estado:text AS estado_registro) '
        'WHERE correo = @correo',
      ),
      parameters: {'rol': rol.name, 'estado': estado, 'correo': correo},
    );
    final sesion = await post(
      '/auth/login',
      cuerpo: {'correo': correo, 'password': passwordDePruebas},
    );
    final json = sesion.json! as Map<String, dynamic>;
    return (
      id: (json['usuario'] as Map<String, dynamic>)['id'] as String,
      correo: correo,
      token: json['access_token'] as String,
      refresh: json['refresh_token'] as String,
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
    final temporal = carpetaUploads.parent;
    if (temporal.existsSync()) await temporal.delete(recursive: true);
  }
}
