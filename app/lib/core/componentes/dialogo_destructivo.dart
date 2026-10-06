import 'package:flutter/material.dart';

import '../theme/medidas.dart';
import '../theme/tema.dart';

/// Pide confirmación antes de una acción destructiva. Devuelve `true` solo
/// si el usuario confirmó.
Future<bool> mostrarDialogoDestructivo(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoConfirmar,
  String textoCancelar = 'Cancelar',
  IconData icono = Icons.delete_outline,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) {
      final esquema = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(icono, color: esquema.error, size: Medidas.iconoLg),
        title: Text(titulo),
        content: Text(mensaje),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(textoCancelar),
          ),
          FilledButton(
            style: estiloBotonDestructivo(),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(textoConfirmar),
          ),
        ],
      );
    },
  );
  return confirmado ?? false;
}
