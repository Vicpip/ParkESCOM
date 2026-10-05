import 'dart:io';

import 'package:backend/archivos/servicio_archivos.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/http/error_api.dart';
import 'package:postgres/postgres.dart';
import 'package:shared/shared.dart';

/// Reglas del perfil propio: nombre, foto del titular y foto de la credencial.
///
/// Sus métodos lanzan [ErrorApi] con el código que la API debe responder.
class ServicioPerfil {
  /// Crea el servicio sobre el [pool] de la base.
  ServicioPerfil({required PoolDb pool}) : _pool = pool;

  final PoolDb _pool;

  /// Código de campo: la foto no existe, es de otro usuario o se subió con
  /// otro propósito. Es uno solo para no revelar archivos ajenos.
  static const fotoInvalida = 'FOTO_INVALIDA';

  /// 409: la cuenta ya está activa y el usuario no puede cambiar su perfil.
  static const perfilBloqueado = ErrorApi(
    HttpStatus.conflict,
    'PERFIL_BLOQUEADO',
    'Para cambiar tus datos o fotos, contacta a Administración',
  );

  /// Campo de foto del perfil → propósito que debe tener el archivo.
  static const _fotos = {
    'foto_titular_id': PropositoArchivo.perfil,
    'foto_credencial_id': PropositoArchivo.credencialEscolar,
  };

  /// Aplica al usuario [id] los campos presentes en [cambios] (`nombre`,
  /// `foto_titular_id`, `foto_credencial_id`); los ausentes no se tocan y una
  /// foto en `null` se quita.
  ///
  /// Solo mientras la cuenta está `pendiente`: una vez activada, el nombre y
  /// las fotos ya los revisó Administración y solo un admin los cambia.
  ///
  /// Errores: `NO_AUTENTICADO` si la cuenta ya no existe o está de baja,
  /// `PERFIL_BLOQUEADO` si ya está activa y `VALIDACION` (con `NOMBRE_*` o
  /// `FOTO_INVALIDA` por campo).
  Future<Usuario> actualizar(String id, Map<String, dynamic> cambios) {
    return _pool.runTx((tx) async {
      // El estado sale de la base, no del token, y el renglón queda bloqueado
      // para que una activación simultánea no se cuele entre leer y escribir.
      final estados = await tx.execute(
        Sql.named(
          'SELECT estado::text FROM usuarios WHERE id = @id:uuid FOR UPDATE',
        ),
        parameters: {'id': id},
      );
      final estado = estados.firstOrNull?[0] as String?;
      if (estado == null || estado == 'baja') {
        throw const ErrorApi.noAutenticado();
      }
      if (estado != 'pendiente') throw perfilBloqueado;

      final errores = <String, String>{};
      final asignaciones = <String>[];
      final parametros = <String, Object?>{'id': id};

      if (cambios.containsKey('nombre')) {
        final nombre = cambios['nombre'];
        final error = nombre is String
            ? validarNombre(nombre)
            : CodigoValidacion.nombreVacio;
        if (error != null) {
          errores['nombre'] = error;
        } else {
          asignaciones.add('nombre = @nombre');
          parametros['nombre'] = (nombre! as String).trim();
        }
      }

      for (final MapEntry(key: campo, value: proposito) in _fotos.entries) {
        if (!cambios.containsKey(campo)) continue;
        final Object? foto = cambios[campo];
        if (foto != null && !await _esFotoPropia(tx, id, foto, proposito)) {
          errores[campo] = fotoInvalida;
          continue;
        }
        // El nombre de la columna sale de `_fotos`, no del cliente.
        asignaciones.add('$campo = @$campo:uuid');
        parametros[campo] = foto;
      }

      if (errores.isNotEmpty) throw ErrorApi.validacion(errores);

      final sql = asignaciones.isEmpty
          ? 'SELECT ${Usuario.columnas} FROM usuarios '
                "WHERE id = @id:uuid AND estado <> 'baja'"
          : 'UPDATE usuarios SET ${asignaciones.join(', ')} '
                "WHERE id = @id:uuid AND estado <> 'baja' "
                'RETURNING ${Usuario.columnas}';
      final filas = await tx.execute(Sql.named(sql), parameters: parametros);
      final fila = filas.firstOrNull;
      if (fila == null) throw const ErrorApi.noAutenticado();
      return Usuario.deFila(fila);
    });
  }

  Future<bool> _esFotoPropia(
    Session db,
    String usuarioId,
    Object foto,
    PropositoArchivo proposito,
  ) async {
    if (foto is! String || !esUuid(foto)) return false;
    final filas = await db.execute(
      Sql.named(
        'SELECT 1 FROM archivos WHERE id = @foto:uuid '
        'AND dueno_id = @usuario:uuid '
        'AND proposito = CAST(@proposito:text AS proposito_archivo)',
      ),
      parameters: {
        'foto': foto,
        'usuario': usuarioId,
        'proposito': proposito.nombre,
      },
    );
    return filas.isNotEmpty;
  }
}
