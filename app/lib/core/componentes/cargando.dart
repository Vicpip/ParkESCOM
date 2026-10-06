import 'package:flutter/material.dart';

import '../theme/medidas.dart';

/// Spinner centrado, con un texto opcional debajo.
class Cargando extends StatelessWidget {
  const Cargando({super.key, this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mensaje = this.mensaje;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(semanticsLabel: mensaje ?? 'Cargando'),
          if (mensaje != null) ...[
            const SizedBox(height: Medidas.espacioMd),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spinner pequeño para el interior de un botón que está enviando.
class ProgresoBoton extends StatelessWidget {
  const ProgresoBoton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: Medidas.progresoBoton,
      child: CircularProgressIndicator(
        strokeWidth: Medidas.bordeFoco,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        semanticsLabel: 'Enviando',
      ),
    );
  }
}
