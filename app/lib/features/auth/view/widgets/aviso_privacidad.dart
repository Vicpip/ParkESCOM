import 'package:flutter/material.dart';

import '../../../../core/theme/medidas.dart';

const _secciones = [
  (
    'Qué datos guardamos',
    'Tu nombre, tu correo institucional, tu boleta o número de empleado, tu '
        'foto y la foto de tu credencial escolar o de empleado. También los '
        'datos y las fotos de los vehículos que registres y tus entradas y '
        'salidas.',
  ),
  (
    'Para qué los usamos',
    'Para identificarte a ti y a tus vehículos en la Puerta A y la Puerta B '
        'y llevar el registro de accesos.',
  ),
  (
    'Quién puede verlos',
    'Administración revisa tus datos para activar tu cuenta. La foto de tu '
        'credencial solo la ve Administración. El personal de las puertas ve '
        'tu foto y la de tu vehículo al validar un acceso.',
  ),
  (
    'Cómo corregirlos o darte de baja',
    'Contacta a Administración. Al darte de baja, tus credenciales dejan de '
        'funcionar y tu historial se conserva.',
  ),
];

/// Muestra el aviso de privacidad del registro.
Future<void> mostrarAvisoPrivacidad(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: const Text('Aviso de privacidad'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ParkESCOM es un proyecto académico de control de acceso '
            'vehicular para ESCOM.',
          ),
          for (final (titulo, texto) in _secciones) ...[
            const SizedBox(height: Medidas.espacioMd),
            Text(titulo, style: tema.textTheme.titleSmall),
            const SizedBox(height: Medidas.espacioXs),
            Text(texto),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  },
);
