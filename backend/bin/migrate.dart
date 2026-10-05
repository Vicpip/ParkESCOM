import 'dart:io';

import 'package:backend/config/entorno.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/db/migrador.dart';
import 'package:postgres/postgres.dart';

/// Aplica las migraciones pendientes de `db/migrations`.
///
/// Uso (desde `backend/`):
///
///     dart run bin/migrate.dart          # solo migraciones
///     dart run bin/migrate.dart --seed   # migraciones y catálogos de db/seeds
Future<void> main(List<String> args) async {
  final desconocidos = args.where((arg) => arg != '--seed').toList();
  if (desconocidos.isNotEmpty) {
    stderr.writeln(
      'Argumento no reconocido: ${desconocidos.join(' ')}. Uso: '
      'dart run bin/migrate.dart [--seed]',
    );
    exitCode = 64;
    return;
  }

  final String url;
  final Directory raizDb;
  try {
    url = exigirEntorno('DATABASE_URL');
    raizDb = Migrador.buscarRaizDb();
  } on ErrorDeConfiguracion catch (error) {
    stderr.writeln(error.mensaje);
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
    final migrador = Migrador(conexion, raizDb: raizDb);

    final nuevas = await migrador.migrar();
    if (nuevas.isEmpty) {
      stdout.writeln('Migraciones: nada pendiente.');
    } else {
      for (final version in nuevas) {
        stdout.writeln('Migración aplicada: $version');
      }
    }

    if (args.contains('--seed')) {
      for (final nombre in await migrador.sembrar()) {
        stdout.writeln('Catálogo aplicado (idempotente): $nombre');
      }
    }
  } finally {
    await conexion.close();
  }
}
