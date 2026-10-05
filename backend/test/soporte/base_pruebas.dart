import 'package:backend/config/entorno.dart';
import 'package:backend/db/conexion.dart';
import 'package:test/test.dart';

/// Borra y vuelve a crear la base de `DATABASE_URL_TEST` para empezar desde
/// cero, y devuelve su URL. La base queda vacía, sin migraciones.
///
/// Se niega a correr si esa base es la misma que la de `DATABASE_URL`.
Future<String> recrearBaseDePruebas() async {
  final urlPruebas = exigirEntorno('DATABASE_URL_TEST');
  final uri = Uri.parse(urlPruebas);
  final base = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(base)) {
    fail('DATABASE_URL_TEST debe terminar en un nombre de base simple.');
  }
  final urlPrincipal = leerEntorno('DATABASE_URL');
  if (urlPrincipal != null &&
      Uri.parse(urlPrincipal).pathSegments.firstOrNull == base) {
    fail(
      'DATABASE_URL_TEST apunta a la misma base que DATABASE_URL; '
      'las pruebas la borrarían.',
    );
  }

  final admin = await abrirConexion(
    uri.replace(path: '/postgres').toString(),
  );
  try {
    await admin.execute('DROP DATABASE IF EXISTS "$base" WITH (FORCE)');
    await admin.execute('CREATE DATABASE "$base"');
  } finally {
    await admin.close();
  }
  return urlPruebas;
}
