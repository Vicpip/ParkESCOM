import 'package:flutter/material.dart';

import 'bitacora.dart';

const estiloMono = TextStyle(fontFamily: 'monospace', fontSize: 13);

/// Contadores por valor y lista de lecturas (la más reciente arriba).
/// La comparten las pestañas de teclado y de flutter_datawedge.
class ListaLecturas extends StatelessWidget {
  const ListaLecturas({
    super.key,
    required this.lecturas,
    required this.conteo,
  });

  final List<Lectura> lecturas;
  final Map<String, int> conteo;

  @override
  Widget build(BuildContext context) {
    if (lecturas.isEmpty) {
      return const Center(child: Text('Sin lecturas todavía.'));
    }
    final recientes = lecturas.reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text(
          'Repeticiones por valor (${conteo.length} distintos)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final e in conteo.entries)
          Text('${e.value} × [${e.key}]', style: estiloMono),
        const Divider(),
        for (final l in recientes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('[${l.crudo}]', style: estiloMono),
                  Text(
                    'longitud ${l.crudo.length} · ${formatoHora(l.hora)} · '
                    '${l.msDesdeAnterior == null ? 'primera vez' : '${l.msDesdeAnterior} ms desde la anterior'}'
                    ' · repetición ${l.repeticiones}',
                  ),
                  if (l.detalle != null)
                    SelectableText(l.detalle!, style: estiloMono),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
