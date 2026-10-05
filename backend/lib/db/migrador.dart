import 'dart:io';

import 'package:backend/config/entorno.dart';
import 'package:postgres/postgres.dart';

/// Aplica las migraciones de `db/migrations` y los catálogos de `db/seeds`.
///
/// Las versiones aplicadas se registran en la tabla `schema_migrations`, así
/// que ejecutar [migrar] varias veces no repite ni duplica nada.
class Migrador {
  /// Crea un migrador sobre [_conexion] que lee los archivos de [raizDb]
  /// (la carpeta `db/` del monorepo).
  Migrador(this._conexion, {required this.raizDb});

  final Connection _conexion;

  /// Carpeta `db/`, que contiene `migrations/` y `seeds/`.
  final Directory raizDb;

  /// Busca la carpeta `db/` en la carpeta actual o en su padre, para que el
  /// comando funcione tanto desde `backend/` como desde la raíz.
  ///
  /// Lanza [ErrorDeConfiguracion] si no la encuentra.
  static Directory buscarRaizDb() {
    final actual = Directory.current;
    for (final base in [actual, actual.parent]) {
      final candidata = Directory('${base.path}/db');
      if (Directory('${candidata.path}/migrations').existsSync()) {
        return candidata;
      }
    }
    throw const ErrorDeConfiguracion(
      'No se encontró la carpeta db/migrations. '
      'Ejecuta el comando desde backend/ o desde la raíz del proyecto.',
    );
  }

  /// Aplica en orden las migraciones pendientes, cada una en su propia
  /// transacción, y devuelve las versiones que aplicó en esta corrida.
  Future<List<String>> migrar() async {
    await _conexion.execute(
      '''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version text PRIMARY KEY,
        aplicada_en timestamptz NOT NULL DEFAULT now()
      )''',
    );
    final filas = await _conexion.execute(
      'SELECT version FROM schema_migrations',
    );
    final aplicadas = {for (final fila in filas) fila[0]! as String};

    final nuevas = <String>[];
    for (final archivo in _archivosSql('migrations')) {
      final version = _version(archivo);
      if (aplicadas.contains(version)) continue;
      final sql = archivo.readAsStringSync();
      await _conexion.runTx((tx) async {
        // El modo simple permite varias sentencias en un mismo archivo.
        await tx.execute(sql, queryMode: QueryMode.simple);
        await tx.execute(
          Sql.named(
            'INSERT INTO schema_migrations (version) VALUES (@version)',
          ),
          parameters: {'version': version},
        );
      });
      nuevas.add(version);
    }
    return nuevas;
  }

  /// Aplica en orden todos los archivos de `db/seeds`, cada uno en su propia
  /// transacción, y devuelve sus nombres.
  ///
  /// Los archivos de catálogos deben ser idempotentes
  /// (`ON CONFLICT DO NOTHING`), porque se ejecutan en cada llamada.
  Future<List<String>> sembrar() async {
    final aplicados = <String>[];
    for (final archivo in _archivosSql('seeds')) {
      final sql = archivo.readAsStringSync();
      await _conexion.runTx(
        (tx) => tx.execute(sql, queryMode: QueryMode.simple),
      );
      aplicados.add(_version(archivo));
    }
    return aplicados;
  }

  List<File> _archivosSql(String carpeta) {
    final directorio = Directory('${raizDb.path}/$carpeta');
    if (!directorio.existsSync()) return const [];
    return directorio
        .listSync()
        .whereType<File>()
        .where((archivo) => archivo.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => _version(a).compareTo(_version(b)));
  }

  String _version(File archivo) {
    final nombre = archivo.uri.pathSegments.last;
    return nombre.substring(0, nombre.length - '.sql'.length);
  }
}
