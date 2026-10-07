import 'package:postgres/postgres.dart';

/// Agrega un renglón a `auditoria`: quién ([actorId]) hizo qué ([accion])
/// sobre qué renglón ([entidad] es la tabla y [entidadId] su id), con el
/// estado [antes] y [despues] del cambio.
///
/// Se llama dentro de la misma transacción que el cambio, para que no exista
/// uno sin el otro.
Future<void> registrarAuditoria(
  Session tx, {
  required String actorId,
  required String accion,
  required String entidad,
  required String entidadId,
  Map<String, Object?>? antes,
  Map<String, Object?>? despues,
}) => tx.execute(
  Sql.named(
    'INSERT INTO auditoria '
    '(actor_id, accion, entidad, entidad_id, antes, despues) VALUES '
    '(@actor:uuid, @accion, @entidad, @entidadId:uuid, @antes:jsonb, '
    '@despues:jsonb)',
  ),
  parameters: {
    'actor': actorId,
    'accion': accion,
    'entidad': entidad,
    'entidadId': entidadId,
    'antes': antes,
    'despues': despues,
  },
);
