import 'package:flutter/foundation.dart';

/// Manejo global de errores no controlados: la app no se cierra y en consola
/// solo queda el tipo de la excepción, nunca su mensaje (puede traer datos
/// del usuario).
void instalarManejoGlobalDeErrores() {
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalles) {
    if (kDebugMode) {
      anterior?.call(detalles);
    } else {
      debugPrint('Error no controlado: ${detalles.exception.runtimeType}');
    }
  };
  PlatformDispatcher.instance.onError = (error, traza) {
    debugPrint('Error no controlado: ${error.runtimeType}');
    if (kDebugMode) debugPrintStack(stackTrace: traza);
    return true;
  };
}
