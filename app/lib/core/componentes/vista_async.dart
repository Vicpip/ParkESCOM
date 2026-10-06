import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errores/codigos_error.dart';
import '../errores/excepcion_api.dart';
import 'cargando.dart';
import 'error_red.dart';

/// Muestra un [AsyncValue] en sus cuatro estados: carga, error, vacío y
/// datos. Toda pantalla con datos remotos pasa por aquí.
class VistaAsync<T> extends StatelessWidget {
  const VistaAsync({
    super.key,
    required this.valor,
    required this.datos,
    this.alReintentar,
    this.cargando,
    this.vacio,
    this.estaVacio,
  });

  final AsyncValue<T> valor;

  /// Construye la pantalla cuando ya hay datos.
  final Widget Function(T datos) datos;

  /// Acción del botón "Reintentar" del estado de error.
  final VoidCallback? alReintentar;

  /// Qué mostrar mientras carga; por omisión, un spinner. Las listas pasan
  /// aquí su skeleton.
  final Widget? cargando;

  /// Qué mostrar cuando [estaVacio] dice que no hay nada.
  final Widget? vacio;

  final bool Function(T datos)? estaVacio;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      skipLoadingOnReload: true,
      loading: () => cargando ?? const Cargando(),
      error: (error, _) => ErrorRed(
        error: error is ExcepcionApi
            ? error
            : const ExcepcionApi(CodigoError.respuestaInesperada),
        alReintentar: alReintentar,
      ),
      data: (valor) {
        final vacio = this.vacio;
        if (vacio != null && (estaVacio?.call(valor) ?? false)) return vacio;
        return datos(valor);
      },
    );
  }
}
