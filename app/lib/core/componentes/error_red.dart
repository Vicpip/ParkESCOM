import 'package:flutter/material.dart';

import '../errores/excepcion_api.dart';
import 'estado_vacio.dart';

/// Estado de error de una pantalla con datos remotos, con "Reintentar".
class ErrorRed extends StatelessWidget {
  const ErrorRed({super.key, this.error, this.alReintentar});

  /// Error que se muestra. Si no es de red se usa su propio mensaje.
  final ExcepcionApi? error;

  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final error = this.error;
    final esDeRed = error == null || error.esDeRed;
    return EstadoMensaje(
      icono: esDeRed ? Icons.cloud_off_outlined : Icons.error_outline,
      titulo: esDeRed
          ? 'No pudimos conectar con el servidor'
          : 'Algo salió mal',
      descripcion: esDeRed
          ? 'Revisa tu conexión a internet e intenta de nuevo.'
          : error.mensaje(),
      colorIcono: esquema.error,
      colorCirculo: esquema.errorContainer,
      accion: alReintentar == null
          ? null
          : FilledButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
    );
  }
}
