import 'dart:io';

import 'package:backend/archivos/almacen_archivos.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/http/error_api.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

/// Para qué se subió un archivo; corresponde al enum `proposito_archivo`.
enum PropositoArchivo {
  /// Foto del titular.
  perfil('perfil'),

  /// Foto de la credencial escolar o de empleado. Solo la ven su dueño y
  /// Administración.
  credencialEscolar('credencial_escolar'),

  /// Foto de un vehículo.
  vehiculo('vehiculo'),

  /// Foto de la placa de una moto.
  placa('placa'),

  /// Foto de un incidente.
  incidente('incidente');

  const PropositoArchivo(this.nombre);

  /// Valor en la base y en la API.
  final String nombre;

  /// Propósito con ese [nombre], o `null` si no existe.
  static PropositoArchivo? deNombre(Object? nombre) {
    for (final proposito in values) {
      if (proposito.nombre == nombre) return proposito;
    }
    return null;
  }
}

/// Contenido de un archivo listo para responderse.
typedef ArchivoLeido = ({List<int> bytes, String mime});

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Indica si [valor] tiene forma de UUID.
bool esUuid(String valor) => _uuid.hasMatch(valor);

/// Reglas de las fotos: validación del contenido, guardado y permisos de
/// lectura.
///
/// Sus métodos lanzan [ErrorApi] con el código que la API debe responder.
class ServicioArchivos {
  /// Crea el servicio sobre el [pool] de la base y el [almacen] en disco.
  ServicioArchivos({required PoolDb pool, required AlmacenArchivos almacen})
    : _pool = pool,
      _almacen = almacen;

  final PoolDb _pool;
  final AlmacenArchivos _almacen;

  static const _generador = Uuid();

  /// 413: el archivo pasa de 2 MB.
  static const muyGrande = ErrorApi(
    HttpStatus.requestEntityTooLarge,
    'ARCHIVO_MUY_GRANDE',
    'La foto pesa más de 2 MB. Elige una más ligera.',
  );

  static const _invalido = ErrorApi(
    HttpStatus.unsupportedMediaType,
    'ARCHIVO_INVALIDO',
    'El archivo debe ser una imagen JPEG o PNG.',
  );

  static const _noEncontrado = ErrorApi(
    HttpStatus.notFound,
    'ARCHIVO_NO_ENCONTRADO',
    'El archivo no existe.',
  );

  /// Guarda [bytes] como archivo de [duenoId] y devuelve su id.
  ///
  /// El tipo sale de los primeros bytes del contenido y el nombre en disco lo
  /// genera la API: nada de lo que el cliente diga sobre el archivo se usa.
  ///
  /// Errores: `ARCHIVO_MUY_GRANDE`, `ARCHIVO_INVALIDO`.
  Future<String> subir({
    required String duenoId,
    required PropositoArchivo proposito,
    required List<int> bytes,
  }) async {
    if (bytes.length > tamanoMaximoArchivo) throw muyGrande;
    final tipo = TipoImagen.detectar(bytes);
    if (tipo == null) throw _invalido;

    final id = _generador.v4();
    final ruta = AlmacenArchivos.rutaDe(id, tipo);
    await _almacen.guardar(ruta, bytes);
    try {
      await _pool.execute(
        Sql.named(
          'INSERT INTO archivos '
          '(id, ruta, tipo_mime, tamano_bytes, dueno_id, proposito) '
          'VALUES (@id:uuid, @ruta, @mime, @tamano, @dueno:uuid, '
          'CAST(@proposito:text AS proposito_archivo))',
        ),
        parameters: {
          'id': id,
          'ruta': ruta,
          'mime': tipo.mime,
          'tamano': bytes.length,
          'dueno': duenoId,
          'proposito': proposito.nombre,
        },
      );
    } on Object {
      // Sin renglón en la base el archivo quedaría huérfano en disco.
      await _almacen.borrar(ruta);
      rethrow;
    }
    return id;
  }

  /// Contenido del archivo [id] si [solicitante] puede verlo.
  ///
  /// Una foto de credencial escolar solo la ven su dueño y un admin; las
  /// demás, su dueño, un admin o un guardia.
  ///
  /// Errores: `ARCHIVO_NO_ENCONTRADO`, `SIN_PERMISO`.
  Future<ArchivoLeido> descargar({
    required String id,
    required UsuarioAutenticado solicitante,
  }) async {
    if (!esUuid(id)) throw _noEncontrado;
    final filas = await _pool.execute(
      Sql.named(
        'SELECT ruta, tipo_mime, dueno_id::text, proposito::text '
        'FROM archivos WHERE id = @id:uuid',
      ),
      parameters: {'id': id},
    );
    final fila = filas.firstOrNull;
    if (fila == null) throw _noEncontrado;

    final esDueno = fila[2] == solicitante.id;
    final esCredencial = fila[3] == PropositoArchivo.credencialEscolar.nombre;
    final puedeVer = switch (solicitante.rol) {
      Rol.admin => true,
      Rol.guardia => esDueno || !esCredencial,
      Rol.usuario => esDueno,
    };
    if (!puedeVer) throw const ErrorApi.sinPermiso();

    final List<int>? bytes;
    try {
      bytes = await _almacen.leer(fila[0]! as String);
    } on RutaInsegura {
      // Un renglón con una ruta que la API no generó no se sirve.
      throw _noEncontrado;
    }
    if (bytes == null) throw _noEncontrado;
    return (bytes: bytes, mime: fila[1]! as String);
  }
}
