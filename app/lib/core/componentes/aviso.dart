import 'package:flutter/material.dart';

import '../theme/colores.dart';
import '../theme/medidas.dart';

/// Qué comunica un [Aviso]. Cada tipo tiene su ícono además de su color.
enum TipoAviso { informacion, exito, advertencia, error }

/// Recuadro con ícono, título opcional y mensaje, dentro de una pantalla.
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.tipo,
    required this.mensaje,
    this.titulo,
    this.accion,
  });

  final TipoAviso tipo;
  final String mensaje;
  final String? titulo;

  /// Botón opcional debajo del mensaje.
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final estados = ColoresEstado.de(context);
    final (icono, fondo, texto, acento) = switch (tipo) {
      TipoAviso.informacion => (
        Icons.info_outline,
        esquema.primaryContainer,
        esquema.onPrimaryContainer,
        esquema.primary,
      ),
      TipoAviso.exito => (
        Icons.check_circle_outline,
        estados.contenedorExito,
        estados.sobreContenedorExito,
        estados.exito,
      ),
      TipoAviso.advertencia => (
        Icons.schedule,
        estados.contenedorAdvertencia,
        estados.sobreContenedorAdvertencia,
        estados.advertencia,
      ),
      TipoAviso.error => (
        Icons.error_outline,
        esquema.errorContainer,
        esquema.onErrorContainer,
        esquema.error,
      ),
    };
    final titulo = this.titulo;
    final accion = this.accion;
    return Semantics(
      container: true,
      liveRegion: tipo == TipoAviso.error,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Medidas.espacioMd),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(Medidas.radio),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: acento, size: Medidas.iconoMd),
            const SizedBox(width: Medidas.espacioSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titulo != null) ...[
                    Text(
                      titulo,
                      style: tema.textTheme.titleSmall?.copyWith(color: texto),
                    ),
                    const SizedBox(height: Medidas.espacioXs),
                  ],
                  Text(
                    mensaje,
                    style: tema.textTheme.bodyLarge?.copyWith(color: texto),
                  ),
                  if (accion != null) ...[
                    const SizedBox(height: Medidas.espacioSm),
                    accion,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
