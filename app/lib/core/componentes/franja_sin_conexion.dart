import 'package:flutter/material.dart';

import '../theme/colores.dart';
import '../theme/medidas.dart';

/// Franja que avisa que la pantalla muestra datos guardados en el
/// dispositivo. Quien la usa decide cuándo mostrarla.
class FranjaSinConexion extends StatelessWidget {
  const FranjaSinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = ColoresEstado.de(context);
    return Material(
      color: colores.contenedorAdvertencia,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Medidas.espacioMd,
          vertical: Medidas.espacioSm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off,
              size: Medidas.iconoMd,
              color: colores.sobreContenedorAdvertencia,
            ),
            const SizedBox(width: Medidas.espacioSm),
            Expanded(
              child: Text(
                'Sin conexión · datos guardados',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colores.sobreContenedorAdvertencia,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
