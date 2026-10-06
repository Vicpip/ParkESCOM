import 'package:flutter/material.dart';

import '../../../../core/theme/medidas.dart';

/// Logotipo y nombre de la app para las pantallas de acceso.
class MarcaParkEscom extends StatelessWidget {
  const MarcaParkEscom({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Medidas.logotipo,
          height: Medidas.logotipo,
          decoration: BoxDecoration(
            color: esquema.primary,
            borderRadius: BorderRadius.circular(Medidas.radioGrande),
          ),
          child: Icon(
            Icons.directions_car,
            size: Medidas.iconoLg,
            color: esquema.onPrimary,
          ),
        ),
        const SizedBox(height: Medidas.espacioMd),
        Text(
          'ParkESCOM',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineMedium?.copyWith(
            color: esquema.secondary,
          ),
        ),
        const SizedBox(height: Medidas.espacioXs),
        Text(
          'Control de acceso vehicular · ESCOM IPN',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyLarge?.copyWith(
            color: esquema.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
