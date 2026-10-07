import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

import 'servidor_pruebas.dart';

/// PNG real de 1×1 px.
final pngDePruebas = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Id con forma de UUID que no existe en la base.
const idInexistente = '00000000-0000-4000-8000-000000000000';

var _placas = 0;

/// Placa distinta en cada llamada.
String placaNueva() => 'PRB-${++_placas}';

/// Cuerpo JSON de [respuesta] como objeto.
Map<String, dynamic> objeto(Respuesta respuesta) =>
    respuesta.json! as Map<String, dynamic>;

/// El objeto `error` de [respuesta].
Map<String, dynamic> errorDe(Respuesta respuesta) =>
    objeto(respuesta)['error'] as Map<String, dynamic>;

/// El objeto `solicitud` de [respuesta].
Map<String, dynamic> solicitudDe(Respuesta respuesta) =>
    objeto(respuesta)['solicitud'] as Map<String, dynamic>;

/// Vehículo dado de alta por [VehiculosDePruebas.darDeAlta].
typedef Alta = ({String solicitudId, String vehiculoId, String? placa});

/// Atajos para preparar vehículos, solicitudes y credenciales.
extension VehiculosDePruebas on ServidorPruebas {
  /// Sube una foto de [cuenta] con ese [proposito] y devuelve su id.
  Future<String> subirFoto(Cuenta cuenta, String proposito) async {
    final respuesta = await subir(
      pngDePruebas,
      proposito: proposito,
      token: cuenta.token,
    );
    if (respuesta.estado != HttpStatus.created) {
      throw StateError('No se pudo subir la foto: ${respuesta.json}');
    }
    return objeto(respuesta)['id'] as String;
  }

  /// Datos válidos de un vehículo de [cuenta], con sus fotos recién subidas
  /// (la de la placa solo en motos) y los campos de [cambios] sustituidos.
  Future<Map<String, Object?>> datosVehiculo(
    Cuenta cuenta, {
    String tipo = 'auto',
    Map<String, Object?> cambios = const {},
  }) async => {
    'tipo': tipo,
    'placa': placaNueva(),
    'numero_serie': null,
    'marca': 'Nissan',
    'modelo': 'Versa 2020',
    'color': 'Gris',
    'foto_id': await subirFoto(cuenta, 'vehiculo'),
    'foto_placa_id': tipo == 'moto' ? await subirFoto(cuenta, 'placa') : null,
    ...cambios,
  };

  /// `POST /solicitudes` como [cuenta].
  Future<Respuesta> solicitar(Cuenta cuenta, Map<String, Object?> cuerpo) =>
      post('/solicitudes', cuerpo: cuerpo, token: cuenta.token);

  /// `POST /solicitudes/{id}/resolver` como [cuenta].
  Future<Respuesta> resolver(
    Cuenta cuenta,
    String solicitudId,
    String decision, {
    String? comentario,
  }) => post(
    '/solicitudes/$solicitudId/resolver',
    cuerpo: {'decision': decision, 'comentario': ?comentario},
    token: cuenta.token,
  );

  /// Crea una solicitud de alta de [cuenta] y, si se pasa [aprobadaPor], ese
  /// admin la aprueba.
  Future<Alta> darDeAlta(
    Cuenta cuenta, {
    String tipo = 'auto',
    Map<String, Object?> cambios = const {},
    Cuenta? aprobadaPor,
  }) async {
    final datos = await datosVehiculo(cuenta, tipo: tipo, cambios: cambios);
    final respuesta = await solicitar(cuenta, {'tipo': 'alta', 'datos': datos});
    if (respuesta.estado != HttpStatus.created) {
      throw StateError('No se pudo crear el alta: ${respuesta.json}');
    }
    final solicitud = solicitudDe(respuesta);
    final id = solicitud['id'] as String;
    if (aprobadaPor != null) {
      final resuelta = await resolver(aprobadaPor, id, 'aprobar');
      if (resuelta.estado != HttpStatus.ok) {
        throw StateError('No se pudo aprobar el alta: ${resuelta.json}');
      }
    }
    return (
      solicitudId: id,
      vehiculoId: solicitud['vehiculo_id'] as String,
      placa: datos['placa'] as String?,
    );
  }

  /// Autoriza a [usuarioId] sobre el vehículo, sin ser titular (el vehículo
  /// compartido todavía no tiene ruta).
  Future<void> autorizar(String vehiculoId, String usuarioId) => pool.execute(
    Sql.named(
      'INSERT INTO vehiculo_usuarios (vehiculo_id, usuario_id) '
      'VALUES (@vehiculo:uuid, @usuario:uuid)',
    ),
    parameters: {'vehiculo': vehiculoId, 'usuario': usuarioId},
  );

  /// Inserta una credencial directo en la base (emitirlas es de fases
  /// posteriores) y devuelve su id.
  Future<String> crearCredencial(
    String vehiculoId, {
    required String identificador,
    String tipo = 'tag_propio',
    String estado = 'activa',
    String? usuarioId,
    String? semilla,
  }) async {
    final filas = await pool.execute(
      Sql.named(
        'INSERT INTO credenciales (vehiculo_id, usuario_id, tipo, '
        'identificador, estado, semilla_totp_cifrada) VALUES '
        '(@vehiculo:uuid, @usuario:uuid, CAST(@tipo:text AS tipo_credencial), '
        '@identificador, CAST(@estado:text AS estado_credencial), '
        '@semilla:text) RETURNING id::text',
      ),
      parameters: {
        'vehiculo': vehiculoId,
        'usuario': usuarioId,
        'tipo': tipo,
        'identificador': identificador,
        'estado': estado,
        'semilla': semilla,
      },
    );
    return filas.single[0]! as String;
  }

  /// Valor de [columna] del renglón [id] de [tabla], como texto.
  Future<String?> leer(String tabla, String columna, String id) async {
    final filas = await pool.execute(
      Sql.named('SELECT $columna::text FROM $tabla WHERE id = @id:uuid'),
      parameters: {'id': id},
    );
    return filas.single[0] as String?;
  }

  /// Renglones de `auditoria` sobre [entidadId], del más antiguo al más
  /// reciente: actor, acción, entidad, antes y después.
  Future<
    List<
      ({
        String? actor,
        String accion,
        String entidad,
        Map<String, dynamic>? antes,
        Map<String, dynamic>? despues,
      })
    >
  >
  auditoriaDe(String entidadId) async {
    final filas = await pool.execute(
      Sql.named(
        'SELECT actor_id::text, accion, entidad, antes, despues '
        'FROM auditoria WHERE entidad_id = @id:uuid ORDER BY fecha, id',
      ),
      parameters: {'id': entidadId},
    );
    return [
      for (final fila in filas)
        (
          actor: fila[0] as String?,
          accion: fila[1]! as String,
          entidad: fila[2]! as String,
          antes: fila[3] as Map<String, dynamic>?,
          despues: fila[4] as Map<String, dynamic>?,
        ),
    ];
  }
}
