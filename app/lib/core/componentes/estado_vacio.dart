import 'package:flutter/material.dart';

import '../theme/medidas.dart';

/// Ícono dentro de un círculo, título, descripción y un botón opcional. Es
/// la base del estado vacío y del de error.
class EstadoMensaje extends StatelessWidget {
  const EstadoMensaje({
    super.key,
    required this.icono,
    required this.titulo,
    required this.colorIcono,
    required this.colorCirculo,
    this.descripcion,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? descripcion;
  final Color colorIcono;
  final Color colorCirculo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final descripcion = this.descripcion;
    final accion = this.accion;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Medidas.espacioLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Medidas.anchoFormulario),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Medidas.circuloEstado,
                height: Medidas.circuloEstado,
                decoration: BoxDecoration(
                  color: colorCirculo,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: Medidas.iconoLg, color: colorIcono),
              ),
              const SizedBox(height: Medidas.espacioMd),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge,
              ),
              if (descripcion != null) ...[
                const SizedBox(height: Medidas.espacioSm),
                Text(
                  descripcion,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyLarge?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (accion != null) ...[
                const SizedBox(height: Medidas.espacioLg),
                accion,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío: todavía no hay datos o la búsqueda no encontró nada.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.descripcion,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? descripcion;

  /// Botón opcional, por ejemplo "Agregar vehículo".
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return EstadoMensaje(
      icono: icono,
      titulo: titulo,
      descripcion: descripcion,
      colorIcono: esquema.primary,
      colorCirculo: esquema.primaryContainer,
      accion: accion,
    );
  }
}
