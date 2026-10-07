import 'dart:io';

import 'package:backend/archivos/servicio_archivos.dart';
import 'package:backend/auditoria/auditoria.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/vehiculos/servicio_vehiculos.dart';
import 'package:postgres/postgres.dart';
import 'package:shared/shared.dart';

/// Longitud máxima del comentario con el que Administración resuelve una
/// solicitud.
const longitudMaximaComentario = 500;

/// Reglas de las solicitudes de alta, cambio y baja de vehículo: las crea el
/// usuario y las resuelve Administración.
///
/// Sus métodos lanzan [ErrorApi] con el código que la API debe responder.
class ServicioSolicitudes {
  /// Crea el servicio sobre el [pool] de la base.
  ServicioSolicitudes({required PoolDb pool}) : _pool = pool;

  final PoolDb _pool;

  /// 404: la solicitud no existe o es de otro usuario (no se distingue).
  static const noEncontrada = ErrorApi(
    HttpStatus.notFound,
    'SOLICITUD_NO_ENCONTRADA',
    'La solicitud no existe.',
  );

  static const _placaYaRegistrada = ErrorApi(
    HttpStatus.conflict,
    'PLACA_YA_REGISTRADA',
    'Ya hay un vehículo registrado con esa placa.',
  );

  static const _pendienteExistente = ErrorApi(
    HttpStatus.conflict,
    'SOLICITUD_PENDIENTE_EXISTENTE',
    'Este vehículo ya tiene una solicitud en revisión. Espera a que '
        'Administración la resuelva.',
  );

  static const _soloTitular = ErrorApi(
    HttpStatus.forbidden,
    'SOLO_TITULAR',
    'Solo el titular del vehículo puede solicitar cambios o su baja.',
  );

  static const _yaResuelta = ErrorApi(
    HttpStatus.conflict,
    'SOLICITUD_YA_RESUELTA',
    'Esta solicitud ya fue resuelta.',
  );

  /// Código de campo: la foto ya es de otro vehículo vigente.
  static const fotoYaAsignada = 'FOTO_YA_ASIGNADA';

  /// SQLSTATE de violación de unicidad.
  static const _violacionDeUnicidad = '23505';

  /// Columnas que lee [_solicitud], en ese orden.
  static const _columnas =
      'id::text, usuario_id::text, vehiculo_id::text, tipo::text, '
      'estado::text, datos_propuestos, comentario, creado_en, resuelta_en';

  /// Campo de foto de un vehículo → propósito que debe tener el archivo.
  static const _propositos = {
    'foto_id': PropositoArchivo.vehiculo,
    'foto_placa_id': PropositoArchivo.placa,
  };

  /// Crea una solicitud de [usuarioId] a partir del cuerpo [json]: `tipo`
  /// (`alta`, `cambio` o `baja`), `vehiculo_id` (cambio y baja) y `datos`
  /// (alta y cambio).
  ///
  /// - **alta:** crea el vehículo en estado pendiente con el usuario como
  ///   titular.
  /// - **cambio:** solo guarda los datos propuestos; el vehículo no cambia
  ///   hasta que se apruebe. El tipo de vehículo no se puede cambiar.
  /// - **baja:** solo la solicitud.
  ///
  /// Errores: `NO_AUTENTICADO` (cuenta de baja), `VALIDACION`,
  /// `VEHICULO_NO_ENCONTRADO`, `SOLO_TITULAR`, `PLACA_YA_REGISTRADA`,
  /// `SOLICITUD_PENDIENTE_EXISTENTE`.
  Future<Solicitud> crear(String usuarioId, Map<String, dynamic> json) async {
    final tipo = TipoSolicitud.deNombre(json['tipo']);
    if (tipo == null) {
      throw const ErrorApi.validacion({'tipo': 'TIPO_SOLICITUD_INVALIDO'});
    }

    DatosVehiculo? datos;
    if (tipo != TipoSolicitud.baja) {
      final crudos = json['datos'];
      if (crudos is! Map<String, dynamic>) {
        throw const ErrorApi.validacion({'datos': 'DATOS_REQUERIDOS'});
      }
      datos = DatosVehiculo.fromJson(crudos);
    }

    String? vehiculoId;
    if (tipo != TipoSolicitud.alta) {
      final id = json['vehiculo_id'];
      if (id == null) {
        throw const ErrorApi.validacion({'vehiculo_id': 'VEHICULO_REQUERIDO'});
      }
      if (id is! String || !esUuid(id)) throw ServicioVehiculos.noEncontrado;
      vehiculoId = id;
    }

    try {
      return await _pool.runTx((tx) async {
        await _exigirCuentaVigente(tx, usuarioId);
        return switch (tipo) {
          TipoSolicitud.alta => _crearAlta(tx, usuarioId, datos!),
          TipoSolicitud.cambio => _crearCambio(
            tx,
            usuarioId,
            vehiculoId!,
            datos!,
          ),
          TipoSolicitud.baja => _crearBaja(tx, usuarioId, vehiculoId!),
        };
      });
    } on ServerException catch (error) {
      throw _porUnicidad(error) ?? error;
    }
  }

  /// Solicitudes de [usuarioId], de la más reciente a la más antigua; con
  /// [estado], solo las de ese estado.
  ///
  /// Errores: `VALIDACION` (`estado`: `ESTADO_SOLICITUD_INVALIDO`).
  Future<List<Solicitud>> listar(String usuarioId, {String? estado}) async {
    final parametros = <String, Object?>{'usuario': usuarioId};
    var filtro = '';
    if (estado != null && estado.isNotEmpty) {
      final estadoSolicitud = EstadoSolicitud.deNombre(estado);
      if (estadoSolicitud == null) {
        throw const ErrorApi.validacion({
          'estado': 'ESTADO_SOLICITUD_INVALIDO',
        });
      }
      filtro = ' AND estado = CAST(@estado:text AS estado_solicitud)';
      parametros['estado'] = estadoSolicitud.nombre;
    }
    final filas = await _pool.execute(
      Sql.named(
        'SELECT $_columnas FROM solicitudes '
        'WHERE usuario_id = @usuario:uuid$filtro '
        'ORDER BY creado_en DESC, id',
      ),
      parameters: parametros,
    );
    return filas.map(_solicitud).toList();
  }

  /// La solicitud [id], si es de [usuarioId].
  ///
  /// Errores: `SOLICITUD_NO_ENCONTRADA`.
  Future<Solicitud> obtener(String usuarioId, String id) async {
    if (!esUuid(id)) throw noEncontrada;
    final filas = await _pool.execute(
      Sql.named(
        'SELECT $_columnas FROM solicitudes '
        'WHERE id = @id:uuid AND usuario_id = @usuario:uuid',
      ),
      parameters: {'id': id, 'usuario': usuarioId},
    );
    final fila = filas.firstOrNull;
    if (fila == null) throw noEncontrada;
    return _solicitud(fila);
  }

  /// Administración ([adminId]) resuelve la solicitud [id] con el cuerpo
  /// [json]: `decision` (`aprobar` o `rechazar`) y `comentario` (obligatorio
  /// al rechazar).
  ///
  /// - **alta aprobada:** el vehículo pasa a activo y, si el solicitante
  ///   estaba pendiente, su cuenta también.
  /// - **alta rechazada:** el vehículo pasa a baja.
  /// - **cambio aprobado:** los datos propuestos se aplican al vehículo.
  /// - **baja aprobada:** el vehículo pasa a baja, se desactivan sus usuarios
  ///   autorizados y se revocan sus credenciales activas.
  /// - **cambio o baja rechazados:** solo cambian el estado y el comentario.
  ///
  /// Es una sola transacción, con su renglón en `auditoria`.
  ///
  /// Errores: `VALIDACION`, `SOLICITUD_NO_ENCONTRADA`,
  /// `SOLICITUD_YA_RESUELTA`, `PLACA_YA_REGISTRADA` (un cambio cuya placa ya
  /// tomó otro vehículo).
  Future<Solicitud> resolver(
    String adminId,
    String id,
    Map<String, dynamic> json,
  ) async {
    final aprobar = switch (json['decision']) {
      'aprobar' => true,
      'rechazar' => false,
      _ => throw const ErrorApi.validacion({'decision': 'DECISION_INVALIDA'}),
    };
    final crudo = json['comentario'];
    final texto = crudo is String ? crudo.trim() : '';
    final comentario = texto.isEmpty ? null : texto;
    if (!aprobar && comentario == null) {
      throw const ErrorApi.validacion({'comentario': 'COMENTARIO_REQUERIDO'});
    }
    if (texto.runes.length > longitudMaximaComentario) {
      throw const ErrorApi.validacion({'comentario': 'COMENTARIO_MUY_LARGO'});
    }
    if (!esUuid(id)) throw noEncontrada;

    try {
      return await _pool.runTx((tx) async {
        final filas = await tx.execute(
          Sql.named(
            'SELECT $_columnas FROM solicitudes WHERE id = @id:uuid FOR UPDATE',
          ),
          parameters: {'id': id},
        );
        final fila = filas.firstOrNull;
        if (fila == null) throw noEncontrada;
        final solicitud = _solicitud(fila);
        if (solicitud.estado != EstadoSolicitud.pendiente) throw _yaResuelta;

        final antes = await _estadoParaAuditoria(tx, id);
        final vehiculo = {'vehiculo': solicitud.vehiculoId};
        final aprobada = (solicitud.tipo, aprobar);

        if (aprobada == (TipoSolicitud.alta, true)) {
          await tx.execute(
            Sql.named(
              "UPDATE vehiculos SET estado = 'activo' "
              "WHERE id = @vehiculo:uuid AND estado = 'pendiente'",
            ),
            parameters: vehiculo,
          );
          // Con el primer vehículo aprobado, la cuenta queda revisada.
          await tx.execute(
            Sql.named(
              "UPDATE usuarios SET estado = 'activo' "
              "WHERE id = @usuario:uuid AND estado = 'pendiente'",
            ),
            parameters: {'usuario': solicitud.usuarioId},
          );
        } else if (aprobada == (TipoSolicitud.alta, false)) {
          await _darDeBaja(tx, vehiculo);
        } else if (aprobada == (TipoSolicitud.cambio, true)) {
          final datos = solicitud.datosPropuestos!;
          await tx.execute(
            Sql.named(
              'UPDATE vehiculos SET placa = @placa:text, '
              'numero_serie = @numeroSerie:text, marca = @marca, '
              'modelo = @modelo, color = @color, foto_id = @foto:uuid, '
              'foto_placa_id = @fotoPlaca:uuid WHERE id = @vehiculo:uuid',
            ),
            parameters: {...vehiculo, ..._parametrosDe(datos)},
          );
        } else if (aprobada == (TipoSolicitud.baja, true)) {
          await _darDeBaja(tx, vehiculo);
          await tx.execute(
            Sql.named(
              'UPDATE vehiculo_usuarios SET activo = false '
              'WHERE vehiculo_id = @vehiculo:uuid AND activo',
            ),
            parameters: vehiculo,
          );
          await tx.execute(
            Sql.named(
              "UPDATE credenciales SET estado = 'revocada' "
              "WHERE vehiculo_id = @vehiculo:uuid AND estado = 'activa'",
            ),
            parameters: vehiculo,
          );
        }

        final resueltas = await tx.execute(
          Sql.named(
            'UPDATE solicitudes SET '
            'estado = CAST(@estado:text AS estado_solicitud), '
            'comentario = @comentario:text, resuelta_por = @admin:uuid, '
            'resuelta_en = now() WHERE id = @id:uuid RETURNING $_columnas',
          ),
          parameters: {
            'id': id,
            'estado':
                (aprobar ? EstadoSolicitud.aprobada : EstadoSolicitud.rechazada)
                    .nombre,
            'comentario': comentario,
            'admin': adminId,
          },
        );

        await registrarAuditoria(
          tx,
          actorId: adminId,
          accion: aprobar ? 'solicitud.aprobar' : 'solicitud.rechazar',
          entidad: 'solicitudes',
          entidadId: id,
          antes: antes,
          despues: await _estadoParaAuditoria(tx, id),
        );
        return _solicitud(resueltas.single);
      });
    } on ServerException catch (error) {
      throw _porUnicidad(error) ?? error;
    }
  }

  Future<Solicitud> _crearAlta(
    Session tx,
    String usuarioId,
    DatosVehiculo datos,
  ) async {
    await _validar(tx, usuarioId, datos);
    final vehiculos = await tx.execute(
      Sql.named(
        'INSERT INTO vehiculos (tipo, placa, numero_serie, marca, modelo, '
        'color, foto_id, foto_placa_id, estado) VALUES '
        '(CAST(@tipo:text AS tipo_vehiculo), @placa:text, @numeroSerie:text, '
        "@marca, @modelo, @color, @foto:uuid, @fotoPlaca:uuid, 'pendiente') "
        'RETURNING id::text',
      ),
      parameters: {'tipo': datos.tipo, ..._parametrosDe(datos)},
    );
    final vehiculoId = vehiculos.single[0]! as String;
    await tx.execute(
      Sql.named(
        'INSERT INTO vehiculo_usuarios (vehiculo_id, usuario_id, es_titular) '
        'VALUES (@vehiculo:uuid, @usuario:uuid, true)',
      ),
      parameters: {'vehiculo': vehiculoId, 'usuario': usuarioId},
    );
    return _insertar(tx, usuarioId, vehiculoId, TipoSolicitud.alta, datos);
  }

  Future<Solicitud> _crearCambio(
    Session tx,
    String usuarioId,
    String vehiculoId,
    DatosVehiculo datos,
  ) async {
    final tipoActual = await _exigirTitularSinPendiente(
      tx,
      usuarioId,
      vehiculoId,
    );
    await _validar(
      tx,
      usuarioId,
      datos,
      vehiculoId: vehiculoId,
      tipoActual: tipoActual,
    );

    // El vehículo todavía no cambia, pero se avisa desde ahora si la placa
    // nueva ya es de otro; el índice único lo vuelve a revisar al aprobar.
    final placa = datos.placa;
    if (placa != null) {
      final ocupada = await tx.execute(
        Sql.named(
          'SELECT 1 FROM vehiculos WHERE placa = @placa '
          "AND estado <> 'baja' AND id <> @vehiculo:uuid",
        ),
        parameters: {'placa': placa, 'vehiculo': vehiculoId},
      );
      if (ocupada.isNotEmpty) throw _placaYaRegistrada;
    }
    return _insertar(tx, usuarioId, vehiculoId, TipoSolicitud.cambio, datos);
  }

  Future<Solicitud> _crearBaja(
    Session tx,
    String usuarioId,
    String vehiculoId,
  ) async {
    await _exigirTitularSinPendiente(tx, usuarioId, vehiculoId);
    return _insertar(tx, usuarioId, vehiculoId, TipoSolicitud.baja, null);
  }

  Future<Solicitud> _insertar(
    Session tx,
    String usuarioId,
    String vehiculoId,
    TipoSolicitud tipo,
    DatosVehiculo? datos,
  ) async {
    final filas = await tx.execute(
      Sql.named(
        'INSERT INTO solicitudes '
        '(usuario_id, vehiculo_id, tipo, datos_propuestos) VALUES '
        '(@usuario:uuid, @vehiculo:uuid, CAST(@tipo:text AS tipo_solicitud), '
        '@datos:jsonb) RETURNING $_columnas',
      ),
      parameters: {
        'usuario': usuarioId,
        'vehiculo': vehiculoId,
        'tipo': tipo.nombre,
        'datos': datos?.toJson(),
      },
    );
    return _solicitud(filas.single);
  }

  /// Solo las cuentas pendientes y activas crean solicitudes. El estado sale
  /// de la base, no del token, que puede ser de una cuenta ya dada de baja.
  Future<void> _exigirCuentaVigente(Session tx, String usuarioId) async {
    final filas = await tx.execute(
      Sql.named('SELECT estado::text FROM usuarios WHERE id = @id:uuid'),
      parameters: {'id': usuarioId},
    );
    final estado = filas.firstOrNull?[0] as String?;
    if (estado == null || estado == EstadoRegistro.baja.nombre) {
      throw const ErrorApi.noAutenticado();
    }
  }

  /// Bloquea el vehículo y comprueba que [usuarioId] sea su titular y que no
  /// tenga ya una solicitud pendiente. Devuelve el tipo del vehículo.
  Future<String> _exigirTitularSinPendiente(
    Session tx,
    String usuarioId,
    String vehiculoId,
  ) async {
    final filas = await tx.execute(
      Sql.named(
        'SELECT v.tipo::text, vu.es_titular FROM vehiculos v '
        'JOIN vehiculo_usuarios vu ON vu.vehiculo_id = v.id '
        'WHERE v.id = @vehiculo:uuid AND vu.usuario_id = @usuario:uuid '
        "AND vu.activo AND v.estado <> 'baja' FOR UPDATE OF v",
      ),
      parameters: {'vehiculo': vehiculoId, 'usuario': usuarioId},
    );
    final fila = filas.firstOrNull;
    if (fila == null) throw ServicioVehiculos.noEncontrado;
    if (!(fila[1]! as bool)) throw _soloTitular;

    final pendientes = await tx.execute(
      Sql.named(
        'SELECT 1 FROM solicitudes '
        "WHERE vehiculo_id = @vehiculo:uuid AND estado = 'pendiente'",
      ),
      parameters: {'vehiculo': vehiculoId},
    );
    if (pendientes.isNotEmpty) throw _pendienteExistente;
    return fila[0]! as String;
  }

  /// Lanza `VALIDACION` si los [datos] o sus fotos no sirven.
  ///
  /// Cada foto debe ser un archivo del usuario con el propósito de su campo
  /// (`FOTO_INVALIDA`) y no estar ya en otro vehículo vigente
  /// (`FOTO_YA_ASIGNADA`). En un cambio, [tipoActual] es el tipo del
  /// vehículo, que no se puede cambiar (`TIPO_NO_MODIFICABLE`).
  Future<void> _validar(
    Session tx,
    String usuarioId,
    DatosVehiculo datos, {
    String? vehiculoId,
    String? tipoActual,
  }) async {
    final errores = datos.validar();
    if (tipoActual != null &&
        datos.tipoVehiculo != null &&
        datos.tipo != tipoActual) {
      errores['tipo'] = 'TIPO_NO_MODIFICABLE';
    }

    final fotos = {
      'foto_id': datos.fotoId,
      'foto_placa_id': datos.fotoPlacaId,
    };
    for (final MapEntry(key: campo, value: foto) in fotos.entries) {
      if (foto == null) continue;
      final propia = await esFotoPropia(
        tx,
        usuarioId: usuarioId,
        foto: foto,
        proposito: _propositos[campo]!,
      );
      if (!propia) {
        errores[campo] = codigoFotoInvalida;
        continue;
      }
      // Las fotos de un vehículo dado de baja (por ejemplo, un alta
      // rechazada) se pueden volver a usar.
      final asignada = await tx.execute(
        Sql.named(
          'SELECT 1 FROM vehiculos '
          'WHERE (foto_id = @foto:uuid OR foto_placa_id = @foto:uuid) '
          "AND estado <> 'baja' "
          'AND (@vehiculo:uuid IS NULL OR id <> @vehiculo:uuid) LIMIT 1',
        ),
        parameters: {'foto': foto, 'vehiculo': vehiculoId},
      );
      if (asignada.isNotEmpty) errores[campo] = fotoYaAsignada;
    }
    if (errores.isNotEmpty) throw ErrorApi.validacion(errores);
  }

  Future<void> _darDeBaja(Session tx, Map<String, Object?> vehiculo) =>
      tx.execute(
        Sql.named(
          "UPDATE vehiculos SET estado = 'baja' WHERE id = @vehiculo:uuid",
        ),
        parameters: vehiculo,
      );

  /// Lo que una resolución puede tocar, para el antes y el después de la
  /// auditoría: la solicitud, su vehículo, el estado del solicitante, los
  /// usuarios autorizados y las credenciales activas.
  Future<Map<String, Object?>> _estadoParaAuditoria(
    Session tx,
    String solicitudId,
  ) async {
    final filas = await tx.execute(
      Sql.named('''
        SELECT jsonb_build_object(
          'solicitud', jsonb_build_object(
            'tipo', s.tipo, 'estado', s.estado, 'comentario', s.comentario,
            'resuelta_por', s.resuelta_por, 'resuelta_en', s.resuelta_en),
          'vehiculo', (
            SELECT jsonb_build_object(
              'id', v.id, 'estado', v.estado, 'tipo', v.tipo,
              'placa', v.placa, 'numero_serie', v.numero_serie,
              'marca', v.marca, 'modelo', v.modelo, 'color', v.color,
              'foto_id', v.foto_id, 'foto_placa_id', v.foto_placa_id)
            FROM vehiculos v WHERE v.id = s.vehiculo_id),
          'solicitante', (
            SELECT jsonb_build_object('id', u.id, 'estado', u.estado)
            FROM usuarios u WHERE u.id = s.usuario_id),
          'usuarios_autorizados', (
            SELECT coalesce(jsonb_agg(vu.usuario_id ORDER BY vu.usuario_id),
                            '[]'::jsonb)
            FROM vehiculo_usuarios vu
            WHERE vu.vehiculo_id = s.vehiculo_id AND vu.activo),
          'credenciales_activas', (
            SELECT coalesce(jsonb_agg(c.id ORDER BY c.id), '[]'::jsonb)
            FROM credenciales c
            WHERE c.vehiculo_id = s.vehiculo_id AND c.estado = 'activa'))
        FROM solicitudes s WHERE s.id = @id:uuid'''),
      parameters: {'id': solicitudId},
    );
    return filas.single[0]! as Map<String, dynamic>;
  }

  static Map<String, Object?> _parametrosDe(DatosVehiculo datos) => {
    'placa': datos.placa,
    'numeroSerie': datos.numeroSerie,
    'marca': datos.marca,
    'modelo': datos.modelo,
    'color': datos.color,
    'foto': datos.fotoId,
    'fotoPlaca': datos.fotoPlacaId,
  };

  static ErrorApi? _porUnicidad(ServerException error) {
    if (error.code != _violacionDeUnicidad) return null;
    return switch (error.constraintName) {
      'vehiculos_placa_unica' => _placaYaRegistrada,
      'solicitudes_una_pendiente' => _pendienteExistente,
      _ => null,
    };
  }

  static Solicitud _solicitud(ResultRow fila) {
    final datos = fila[5];
    return Solicitud(
      id: fila[0]! as String,
      usuarioId: fila[1]! as String,
      vehiculoId: fila[2] as String?,
      tipo: TipoSolicitud.deNombre(fila[3])!,
      estado: EstadoSolicitud.deNombre(fila[4])!,
      datosPropuestos: datos is Map<String, dynamic>
          ? DatosVehiculo.fromJson(datos)
          : null,
      comentario: fila[6] as String?,
      creadoEn: fila[7]! as DateTime,
      resueltaEn: fila[8] as DateTime?,
    );
  }
}
