import 'dart:io';

import 'package:backend/auth/limitador_intentos.dart';
import 'package:backend/auth/passwords.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/config/configuracion.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/http/error_api.dart';
import 'package:postgres/postgres.dart';
import 'package:shared/shared.dart';

/// Resultado de registrarse, iniciar sesión, renovar o cambiar la contraseña:
/// el par de tokens y los datos básicos del usuario.
class SesionIniciada {
  /// Crea el resultado con sus tokens y su [usuario].
  const SesionIniciada({
    required this.accessToken,
    required this.refreshToken,
    required this.usuario,
  });

  /// JWT de acceso (15 min).
  final String accessToken;

  /// Refresh token opaco (30 días, de un solo uso).
  final String refreshToken;

  /// Datos básicos del usuario, sin hash.
  final Usuario usuario;

  /// Representación que devuelve la API.
  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expira_en': vigenciaAcceso.inSeconds,
    'usuario': usuario.toJson(),
  };
}

/// Reglas de autenticación: registro, inicio de sesión, renovación y cierre
/// de sesión, y cambio de contraseña.
///
/// Sus métodos lanzan [ErrorApi] con el código que la API debe responder.
class ServicioAuth {
  /// Crea el servicio sobre el [pool] de la base.
  ServicioAuth({
    required PoolDb pool,
    required Configuracion config,
    required ServicioTokens tokens,
    LimitadorIntentos? limitador,
  }) : _pool = pool,
       _config = config,
       _tokens = tokens,
       _limitador = limitador ?? LimitadorIntentos();

  final PoolDb _pool;
  final Configuracion _config;
  final ServicioTokens _tokens;
  final LimitadorIntentos _limitador;

  /// Hash de una contraseña cualquiera, para gastar el mismo tiempo de bcrypt
  /// cuando el correo no existe y no delatarlo por la demora.
  late final Future<String> _hashSenuelo = hashearPassword(
    generarRefreshToken(),
    costo: _config.costoBcrypt,
  );

  static const _columnas =
      'id::text, nombre, correo, boleta_o_empleado, rol::text, estado::text';

  static const _credencialesInvalidas = ErrorApi(
    HttpStatus.unauthorized,
    'CREDENCIALES_INVALIDAS',
    'Correo o contraseña incorrectos.',
  );

  static const _refreshInvalido = ErrorApi(
    HttpStatus.unauthorized,
    'REFRESH_INVALIDO',
    'Tu sesión venció. Inicia sesión de nuevo.',
  );

  /// Crea una cuenta con rol `usuario` y estado `pendiente`, y le abre sesión.
  ///
  /// Errores: `VALIDACION`, `DOMINIO_NO_PERMITIDO`, `CORREO_YA_REGISTRADO`,
  /// `BOLETA_YA_REGISTRADA`.
  Future<SesionIniciada> registrar({
    required String nombre,
    required String correo,
    required String boletaOEmpleado,
    required String password,
  }) async {
    final correoNormalizado = normalizarCorreo(correo);
    final boleta = boletaOEmpleado.trim();
    final errorCorreo = validarCorreo(
      correoNormalizado,
      dominiosPermitidos: _config.dominiosPermitidos,
    );
    final campos = {
      'nombre': ?validarNombre(nombre),
      'correo': ?errorCorreo,
      'boleta_o_empleado': ?validarBoletaOEmpleado(boleta),
      'password': ?validarPassword(password),
    };
    if (campos.length == 1 &&
        errorCorreo == CodigoValidacion.dominioNoPermitido) {
      throw const ErrorApi(
        HttpStatus.unprocessableEntity,
        CodigoValidacion.dominioNoPermitido,
        'Usa tu correo institucional para registrarte.',
      );
    }
    if (campos.isNotEmpty) throw ErrorApi.validacion(campos);

    final hash = await hashearPassword(password, costo: _config.costoBcrypt);
    try {
      return await _pool.runTx((tx) async {
        final filas = await tx.execute(
          Sql.named(
            'INSERT INTO usuarios '
            '(correo, hash_password, nombre, boleta_o_empleado, rol, estado) '
            "VALUES (@correo, @hash, @nombre, @boleta, 'usuario', 'pendiente') "
            'RETURNING $_columnas',
          ),
          parameters: {
            'correo': correoNormalizado,
            'hash': hash,
            'nombre': nombre.trim(),
            'boleta': boleta,
          },
        );
        return _abrirSesion(tx, _usuarioDe(filas.single));
      });
    } on ServerException catch (error) {
      if (error.code != _violacionDeUnicidad) rethrow;
      throw switch (error.constraintName) {
        'usuarios_correo_unico' => const ErrorApi(
          HttpStatus.conflict,
          'CORREO_YA_REGISTRADO',
          'Ya existe una cuenta con ese correo.',
        ),
        'usuarios_boleta_o_empleado_unico' => const ErrorApi(
          HttpStatus.conflict,
          'BOLETA_YA_REGISTRADA',
          'Ya existe una cuenta con esa boleta o número de empleado.',
        ),
        _ => error,
      };
    }
  }

  /// Inicia sesión con correo y contraseña. Entran las cuentas `pendiente` y
  /// `activo`; una cuenta de `baja` recibe el mismo error que una contraseña
  /// incorrecta.
  ///
  /// Errores: `CREDENCIALES_INVALIDAS`, `DEMASIADOS_INTENTOS`.
  Future<SesionIniciada> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    final correoNormalizado = normalizarCorreo(correo);
    if (_limitador.estaBloqueado(correoNormalizado)) {
      throw const ErrorApi(
        HttpStatus.tooManyRequests,
        'DEMASIADOS_INTENTOS',
        'Demasiados intentos fallidos. Espera unos minutos e intenta de '
            'nuevo.',
      );
    }

    final filas = await _pool.execute(
      Sql.named(
        'SELECT $_columnas, hash_password FROM usuarios WHERE correo = @correo',
      ),
      parameters: {'correo': correoNormalizado},
    );
    final fila = filas.firstOrNull;
    final hash = fila == null ? await _hashSenuelo : fila[6]! as String;
    final coincide = await verificarPassword(password, hash);
    final usuario = fila == null ? null : _usuarioDe(fila);
    if (usuario == null || !coincide || usuario.estado == 'baja') {
      _limitador.registrarFallo(correoNormalizado);
      throw _credencialesInvalidas;
    }

    _limitador.limpiar(correoNormalizado);
    return _abrirSesion(_pool, usuario);
  }

  /// Cambia un refresh token vigente por un par de tokens nuevo. El token
  /// recibido queda revocado: no sirve una segunda vez.
  ///
  /// Error: `REFRESH_INVALIDO`.
  Future<SesionIniciada> renovar(String refreshToken) {
    return _pool.runTx((tx) async {
      // El UPDATE revoca y comprueba en un solo paso: dos peticiones
      // simultáneas con el mismo token no pueden ganar las dos.
      final sesiones = await tx.execute(
        Sql.named(
          'UPDATE sesiones SET revocada = true '
          'WHERE hash_refresh_token = @hash AND NOT revocada '
          'AND expira_en > now() RETURNING usuario_id::text',
        ),
        parameters: {'hash': hashRefreshToken(refreshToken)},
      );
      if (sesiones.isEmpty) throw _refreshInvalido;
      final usuario = await _buscarVigente(tx, sesiones.single[0]! as String);
      if (usuario == null) throw _refreshInvalido;
      return _abrirSesion(tx, usuario);
    });
  }

  /// Revoca la sesión de [refreshToken]. No falla si el token no existe o ya
  /// estaba revocado.
  Future<void> cerrarSesion(String refreshToken) => _pool.execute(
    Sql.named(
      'UPDATE sesiones SET revocada = true '
      'WHERE hash_refresh_token = @hash AND NOT revocada',
    ),
    parameters: {'hash': hashRefreshToken(refreshToken)},
  );

  /// Datos del usuario [id].
  ///
  /// Lanza [ErrorApi.noAutenticado] si ya no existe o está de baja.
  Future<Usuario> obtenerUsuario(String id) async {
    final usuario = await _buscarVigente(_pool, id);
    if (usuario == null) throw const ErrorApi.noAutenticado();
    return usuario;
  }

  /// Cambia la contraseña del usuario [id], revoca todas sus sesiones y abre
  /// una nueva para el dispositivo que hizo el cambio.
  ///
  /// Errores: `PASSWORD_ACTUAL_INCORRECTA`, `VALIDACION`.
  Future<SesionIniciada> cambiarPassword({
    required String id,
    required String actual,
    required String nueva,
  }) async {
    final filas = await _pool.execute(
      Sql.named(
        'SELECT $_columnas, hash_password FROM usuarios '
        "WHERE id = @id:uuid AND estado <> 'baja'",
      ),
      parameters: {'id': id},
    );
    final fila = filas.firstOrNull;
    if (fila == null) throw const ErrorApi.noAutenticado();
    if (!await verificarPassword(actual, fila[6]! as String)) {
      throw const ErrorApi(
        HttpStatus.badRequest,
        'PASSWORD_ACTUAL_INCORRECTA',
        'La contraseña actual no es correcta.',
      );
    }
    final errorNueva = validarPassword(nueva);
    if (errorNueva != null) {
      throw ErrorApi.validacion({'password_nueva': errorNueva});
    }

    final hash = await hashearPassword(nueva, costo: _config.costoBcrypt);
    return _pool.runTx((tx) async {
      await tx.execute(
        Sql.named(
          'UPDATE usuarios SET hash_password = @hash WHERE id = @id:uuid',
        ),
        parameters: {'hash': hash, 'id': id},
      );
      await tx.execute(
        Sql.named(
          'UPDATE sesiones SET revocada = true '
          'WHERE usuario_id = @id:uuid AND NOT revocada',
        ),
        parameters: {'id': id},
      );
      return _abrirSesion(tx, _usuarioDe(fila));
    });
  }

  /// Guarda una sesión nueva (solo el hash del refresh token, con vigencia de
  /// 30 días) y firma el token de acceso.
  Future<SesionIniciada> _abrirSesion(Session db, Usuario usuario) async {
    final refreshToken = generarRefreshToken();
    await db.execute(
      Sql.named(
        'INSERT INTO sesiones (usuario_id, hash_refresh_token, expira_en) '
        "VALUES (@usuario:uuid, @hash, now() + interval '30 days')",
      ),
      parameters: {
        'usuario': usuario.id,
        'hash': hashRefreshToken(refreshToken),
      },
    );
    return SesionIniciada(
      accessToken: _tokens.emitirAcceso(
        usuarioId: usuario.id,
        rol: usuario.rol,
      ),
      refreshToken: refreshToken,
      usuario: usuario,
    );
  }

  Future<Usuario?> _buscarVigente(Session db, String id) async {
    final filas = await db.execute(
      Sql.named(
        'SELECT $_columnas FROM usuarios '
        "WHERE id = @id:uuid AND estado <> 'baja'",
      ),
      parameters: {'id': id},
    );
    final fila = filas.firstOrNull;
    return fila == null ? null : _usuarioDe(fila);
  }

  Usuario _usuarioDe(ResultRow fila) => Usuario(
    id: fila[0]! as String,
    nombre: fila[1]! as String,
    correo: fila[2]! as String,
    boletaOEmpleado: fila[3]! as String,
    rol: Rol.deNombre(fila[4])!,
    estado: fila[5]! as String,
  );
}

/// SQLSTATE de violación de unicidad.
const _violacionDeUnicidad = '23505';
