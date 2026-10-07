import 'dart:io';

import 'package:backend/archivos/servicio_archivos.dart';
import 'package:backend/auditoria/auditoria.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/http/error_api.dart';
import 'package:postgres/postgres.dart';
import 'package:shared/shared.dart';

/// Reglas de las credenciales desde el lado del usuario.
///
/// Sus métodos lanzan [ErrorApi] con el código que la API debe responder.
class ServicioCredenciales {
  /// Crea el servicio sobre el [pool] de la base.
  ServicioCredenciales({required PoolDb pool}) : _pool = pool;

  final PoolDb _pool;

  static const _noEncontrada = ErrorApi(
    HttpStatus.notFound,
    'CREDENCIAL_NO_ENCONTRADA',
    'La credencial no existe.',
  );

  static const _soloTitular = ErrorApi(
    HttpStatus.forbidden,
    'SOLO_TITULAR',
    'Solo el titular del vehículo puede reportar esta credencial.',
  );

  static const _noActiva = ErrorApi(
    HttpStatus.conflict,
    'CREDENCIAL_NO_ACTIVA',
    'Esta credencial ya no está activa.',
  );

  /// Pasa la credencial [id] de activa a perdida. Puede hacerlo el titular
  /// del vehículo o, si es un QR, el usuario al que pertenece. Deja un
  /// renglón en `auditoria`.
  ///
  /// Las casetas dejan de aceptarla en su siguiente sincronización.
  ///
  /// Errores: `CREDENCIAL_NO_ENCONTRADA` (no existe o es de un vehículo
  /// ajeno), `SOLO_TITULAR`, `CREDENCIAL_NO_ACTIVA`.
  Future<CredencialResumen> reportarPerdida(
    String usuarioId,
    String id,
  ) async {
    if (!esUuid(id)) throw _noEncontrada;
    return _pool.runTx((tx) async {
      final filas = await tx.execute(
        Sql.named(
          'SELECT c.estado::text, c.tipo::text, c.usuario_id::text, '
          'vu.es_titular FROM credenciales c '
          'LEFT JOIN vehiculo_usuarios vu ON vu.vehiculo_id = c.vehiculo_id '
          'AND vu.usuario_id = @usuario:uuid AND vu.activo '
          'WHERE c.id = @id:uuid FOR UPDATE OF c',
        ),
        parameters: {'id': id, 'usuario': usuarioId},
      );
      final fila = filas.firstOrNull;
      if (fila == null) throw _noEncontrada;

      final esTitular = fila[3] as bool?;
      final esSuQr =
          fila[1] == TipoCredencial.qr.nombre && fila[2] == usuarioId;
      if (!(esTitular ?? false) && !esSuQr) {
        // Quien no tiene nada que ver con el vehículo no se entera de que la
        // credencial existe; un usuario autorizado sí la ve, pero no es suya.
        throw esTitular == null ? _noEncontrada : _soloTitular;
      }
      final estado = fila[0]! as String;
      if (estado != EstadoCredencial.activa.nombre) throw _noActiva;

      final cambiadas = await tx.execute(
        Sql.named(
          "UPDATE credenciales SET estado = 'perdida' WHERE id = @id:uuid "
          'RETURNING id::text, tipo::text, estado::text, identificador, '
          'vigencia',
        ),
        parameters: {'id': id},
      );
      final cambiada = cambiadas.single;
      await registrarAuditoria(
        tx,
        actorId: usuarioId,
        accion: 'credencial.reportar_perdida',
        entidad: 'credenciales',
        entidadId: id,
        antes: {'estado': estado},
        despues: {'estado': EstadoCredencial.perdida.nombre},
      );
      return CredencialResumen(
        id: cambiada[0]! as String,
        tipo: TipoCredencial.deNombre(cambiada[1])!,
        estado: EstadoCredencial.deNombre(cambiada[2])!,
        terminacion: CredencialResumen.terminacionDe(cambiada[3]! as String),
        vigencia: cambiada[4] as DateTime?,
      );
    });
  }
}
