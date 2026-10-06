import 'package:flutter/material.dart';

import '../theme/medidas.dart';

/// Contenedor de un formulario: desplazable, con márgenes de 16 px y ancho
/// máximo para que no se estire en tablet ni en web.
class LienzoFormulario extends StatelessWidget {
  const LienzoFormulario({super.key, required this.hijos});

  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Medidas.espacioMd),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Medidas.anchoFormulario,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: hijos,
            ),
          ),
        ),
      ),
    );
  }
}
