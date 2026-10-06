import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bitacora.dart';
import 'lista_lecturas.dart';

/// Bitácora cronológica de las otras tres pestañas.
class PestanaRegistro extends StatelessWidget {
  const PestanaRegistro({super.key, required this.bitacora});

  final Bitacora bitacora;

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: bitacora.comoTexto()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copiadas ${bitacora.lineas.length} líneas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bitacora,
      builder: (context, _) {
        final lineas = bitacora.lineas;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: lineas.isEmpty ? null : () => _copiar(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar todo'),
                  ),
                  OutlinedButton(
                    onPressed: lineas.isEmpty ? null : bitacora.limpiar,
                    child: const Text('Limpiar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: bitacora.marcar,
                    icon: const Icon(Icons.flag),
                    label: const Text('Marca'),
                  ),
                  Text('${lineas.length} líneas'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: lineas.isEmpty
                  ? const Center(child: Text('Bitácora vacía.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: lineas.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(lineas[i], style: estiloMono),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
