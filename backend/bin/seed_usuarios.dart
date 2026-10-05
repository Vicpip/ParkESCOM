import 'dart:io';

import 'package:backend/auth/usuarios_demo.dart';
import 'package:backend/config/entorno.dart';
import 'package:backend/db/conexion.dart';
import 'package:postgres/postgres.dart';
import 'package:shared/shared.dart';

/// Crea las cuentas de demostración (un admin, un guardia y dos usuarios) con
/// la contraseña de `SEED_PASSWORD`. Es idempotente.
///
/// Uso (desde `backend/`):
///
///     dart run bin/seed_usuarios.dart
Future<void> main() async {
  final String url;
  final String password;
  try {
    url = exigirEntorno('DATABASE_URL');
    password = exigirEntorno('SEED_PASSWORD');
  } on ErrorDeConfiguracion catch (error) {
    stderr.writeln(error.mensaje);
    exitCode = 1;
    return;
  }
  if (validarPassword(password) != null) {
    stderr.writeln(
      'SEED_PASSWORD no cumple la política de contraseñas: mínimo '
      '$longitudMinimaPassword caracteres, con al menos una letra y un número.',
    );
    exitCode = 1;
    return;
  }

  final Connection conexion;
  try {
    conexion = await abrirConexion(url);
  } on Exception catch (error) {
    final destino = Uri.parse(url);
    stderr.writeln(
      'No se pudo conectar a PostgreSQL en ${destino.host}:${destino.port}'
      '${destino.path}. Revisa que la base esté levantada '
      '(docker compose up -d db) y que DATABASE_URL apunte a ella.\n'
      'Detalle: $error',
    );
    exitCode = 1;
    return;
  }

  try {
    final creados = await sembrarUsuariosDemo(conexion, password: password);
    for (final demo in usuariosDemo) {
      final estado = creados.contains(demo.correo) ? 'creado' : 'ya existía';
      stdout.writeln('${demo.correo} (${demo.rol}): $estado');
    }
  } on ServerException catch (error) {
    stderr.writeln(
      'No se pudieron crear los usuarios de demostración. ¿Ya aplicaste las '
      'migraciones (dart run bin/migrate.dart)?\nDetalle: ${error.message}',
    );
    exitCode = 1;
  } finally {
    await conexion.close();
  }
}
