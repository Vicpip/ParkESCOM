import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errores/codigos_error.dart';
import '../../../core/errores/excepcion_api.dart';
import '../../modelos/foto.dart';

/// Tamaño máximo de una foto que acepta la API.
const tamanoMaximoFoto = 2 * 1024 * 1024;

/// Lado al que se reduce una foto antes de subirla.
const _ladoMaximo = 1600;

/// Calidades JPEG que se prueban, de mayor a menor, hasta bajar de 2 MB.
const _calidades = [80, 65, 50, 35];

/// Comprime [bytes] a JPEG con la calidad dada (0 a 100).
typedef Compresor = Future<Uint8List> Function(Uint8List bytes, int calidad);

/// Toma una foto con la cámara o la galería y la deja lista para subir.
abstract interface class SelectorFotos {
  /// Devuelve `null` si el usuario canceló. Lanza [ExcepcionApi] con
  /// `FOTO_NO_DISPONIBLE` si no se pudo abrir el origen y con
  /// `ARCHIVO_MUY_GRANDE` si la foto no baja de 2 MB.
  Future<Foto?> elegir(OrigenFoto origen);
}

/// Baja [original] de 2 MB probando calidades cada vez menores.
///
/// Si [comprimir] falla (formato que el dispositivo no sabe leer), se usa el
/// original cuando ya cabe; la API decide después si es una foto válida.
Future<Uint8List> comprimirBajoElLimite(
  Uint8List original,
  Compresor comprimir, {
  int limite = tamanoMaximoFoto,
}) async {
  for (final calidad in _calidades) {
    final Uint8List comprimida;
    try {
      comprimida = await comprimir(original, calidad);
    } on Object {
      break;
    }
    if (comprimida.isNotEmpty && comprimida.length <= limite) {
      return comprimida;
    }
  }
  if (original.length <= limite) return original;
  throw const ExcepcionApi(CodigoError.archivoMuyGrande);
}

/// [SelectorFotos] con `image_picker` y `flutter_image_compress`.
class SelectorFotosDispositivo implements SelectorFotos {
  SelectorFotosDispositivo([ImagePicker? selector])
    : _selector = selector ?? ImagePicker();

  final ImagePicker _selector;

  @override
  Future<Foto?> elegir(OrigenFoto origen) async {
    final Uint8List original;
    try {
      final archivo = await _selector.pickImage(
        source: switch (origen) {
          OrigenFoto.camara => ImageSource.camera,
          OrigenFoto.galeria => ImageSource.gallery,
        },
        maxWidth: _ladoMaximo.toDouble(),
        maxHeight: _ladoMaximo.toDouble(),
      );
      if (archivo == null) return null;
      original = await archivo.readAsBytes();
    } on Object {
      throw const ExcepcionApi(CodigoError.fotoNoDisponible);
    }
    return Foto(await comprimirBajoElLimite(original, _comprimir));
  }

  static Future<Uint8List> _comprimir(Uint8List bytes, int calidad) =>
      FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _ladoMaximo,
        minHeight: _ladoMaximo,
        quality: calidad,
      );
}
