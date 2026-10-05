import 'package:flutter/material.dart';

import 'bitacora.dart';
import 'pestana_datawedge.dart';
import 'pestana_nfc.dart';
import 'pestana_registro.dart';
import 'pestana_teclado.dart';

void main() {
  runApp(const AppPrueba());
}

class AppPrueba extends StatelessWidget {
  const AppPrueba({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba de hardware',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF006699)),
      home: const Inicio(),
    );
  }
}

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  final _bitacora = Bitacora();
  int _indice = 0;

  @override
  void dispose() {
    _bitacora.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // IndexedStack mantiene vivas las cuatro pestañas: las lecturas por
        // intent se siguen registrando aunque se esté viendo otra.
        child: IndexedStack(
          index: _indice,
          children: [
            PestanaTeclado(bitacora: _bitacora, activa: _indice == 0),
            PestanaDataWedge(bitacora: _bitacora),
            PestanaNfc(bitacora: _bitacora, activa: _indice == 2),
            PestanaRegistro(bitacora: _bitacora),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.keyboard), label: 'Teclado'),
          NavigationDestination(icon: Icon(Icons.sensors), label: 'DataWedge'),
          NavigationDestination(icon: Icon(Icons.nfc), label: 'NFC'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Registro'),
        ],
      ),
    );
  }
}
