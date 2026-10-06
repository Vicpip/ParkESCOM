import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/medidas.dart';

class _Destino {
  const _Destino(this.etiqueta, this.icono, this.iconoActivo);

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
}

const _destinos = [
  _Destino('Inicio', Icons.home_outlined, Icons.home),
  _Destino('Vehículos', Icons.directions_car_outlined, Icons.directions_car),
  _Destino('Historial', Icons.history, Icons.history),
  _Destino('Perfil', Icons.person_outline, Icons.person),
];

/// Navegación del usuario: barra inferior en celular y riel lateral en
/// tablet y web, con los mismos destinos.
class ShellUsuario extends StatelessWidget {
  const ShellUsuario({super.key, required this.navegacion});

  final StatefulNavigationShell navegacion;

  void _ir(int indice) => navegacion.goBranch(
    indice,
    // Tocar la pestaña activa regresa a su primera pantalla.
    initialLocation: indice == navegacion.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho >= Medidas.anchoTablet) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: navegacion.currentIndex,
                onDestinationSelected: _ir,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destino in _destinos)
                    NavigationRailDestination(
                      icon: Icon(destino.icono),
                      selectedIcon: Icon(destino.iconoActivo),
                      label: Text(destino.etiqueta),
                    ),
                ],
              ),
              const VerticalDivider(),
              Expanded(child: navegacion),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: navegacion,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: Medidas.bordeFino,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navegacion.currentIndex,
          onDestinationSelected: _ir,
          destinations: [
            for (final destino in _destinos)
              NavigationDestination(
                icon: Icon(destino.icono),
                selectedIcon: Icon(destino.iconoActivo),
                label: destino.etiqueta,
              ),
          ],
        ),
      ),
    );
  }
}
