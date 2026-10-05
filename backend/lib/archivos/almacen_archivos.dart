import 'dart:io';

/// Tamaño máximo de una foto: 2 MB (el mismo límite que el CHECK de
/// `archivos.tamano_bytes`).
const tamanoMaximoArchivo = 2 * 1024 * 1024;

/// Tipo de imagen reconocido por los primeros bytes del contenido.
enum TipoImagen {
  /// JPEG (`FF D8 FF`).
  jpeg('image/jpeg', 'jpg'),

  /// PNG (`89 50 4E 47 0D 0A 1A 0A`).
  png('image/png', 'png');

  const TipoImagen(this.mime, this.extension);

  /// Tipo MIME real del contenido.
  final String mime;

  /// Extensión con la que se guarda en disco.
  final String extension;

  static const _firmaJpeg = [0xFF, 0xD8, 0xFF];
  static const _firmaPng = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  /// Reconoce el tipo por la firma con la que empiezan los [bytes], o `null`
  /// si no es JPEG ni PNG. El nombre del archivo y el `Content-Type` que
  /// mande el cliente no cuentan.
  static TipoImagen? detectar(List<int> bytes) {
    if (_empiezaCon(bytes, _firmaJpeg)) return jpeg;
    if (_empiezaCon(bytes, _firmaPng)) return png;
    return null;
  }

  static bool _empiezaCon(List<int> bytes, List<int> firma) {
    if (bytes.length < firma.length) return false;
    for (var i = 0; i < firma.length; i++) {
      if (bytes[i] != firma[i]) return false;
    }
    return true;
  }
}

/// Una ruta de archivo que no tiene la forma que genera la API y que por lo
/// tanto podría apuntar fuera de la carpeta de fotos.
class RutaInsegura implements Exception {
  /// Crea el error. No guarda la ruta: puede venir del cliente.
  const RutaInsegura();

  @override
  String toString() => 'RutaInsegura';
}

/// Carpeta de las fotos subidas (`UPLOADS_DIR`).
///
/// Todos los archivos viven directamente en la carpeta, con un nombre que
/// genera la API (`<uuid>.jpg` o `<uuid>.png`). [resolver] rechaza cualquier
/// otra forma, así que ninguna ruta puede salir de la carpeta aunque el valor
/// venga del cliente o de un renglón alterado de la base.
class AlmacenArchivos {
  /// Crea el almacén sobre la carpeta [raiz] (se crea al guardar si falta).
  AlmacenArchivos(String raiz) : _raiz = Directory(raiz).absolute;

  final Directory _raiz;

  static final _nombreGenerado = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png)$',
  );

  /// Ruta relativa con la que se guarda el archivo [id] de tipo [tipo].
  static String rutaDe(String id, TipoImagen tipo) => '$id.${tipo.extension}';

  /// Archivo en disco de la ruta relativa [ruta].
  ///
  /// Lanza [RutaInsegura] si [ruta] no es exactamente un nombre generado por
  /// [rutaDe]: con separadores, `..`, unidad de disco, ruta absoluta, bytes
  /// nulos o cualquier otro carácter.
  File resolver(String ruta) {
    if (!_nombreGenerado.hasMatch(ruta)) throw const RutaInsegura();
    return File('${_raiz.path}${Platform.pathSeparator}$ruta');
  }

  /// Escribe [bytes] en [ruta].
  Future<void> guardar(String ruta, List<int> bytes) async {
    final archivo = resolver(ruta);
    await _raiz.create(recursive: true);
    await archivo.writeAsBytes(bytes, flush: true);
  }

  /// Contenido de [ruta], o `null` si el archivo ya no está en disco.
  Future<List<int>?> leer(String ruta) async {
    final archivo = resolver(ruta);
    if (!archivo.existsSync()) return null;
    return archivo.readAsBytes();
  }

  /// Borra [ruta] si existe.
  Future<void> borrar(String ruta) async {
    final archivo = resolver(ruta);
    if (archivo.existsSync()) await archivo.delete();
  }
}
