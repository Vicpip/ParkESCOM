import 'package:flutter/material.dart';

import 'bitacora.dart';
import 'lista_lecturas.dart';

/// Plan B sin plugin: DataWedge escribe la lectura como teclado (Keystroke
/// Output) en un campo de texto oculto y cada Enter cierra una lectura.
class PestanaTeclado extends StatefulWidget {
  const PestanaTeclado({
    super.key,
    required this.bitacora,
    required this.activa,
  });

  final Bitacora bitacora;

  /// El campo solo retiene el foco mientras su pestaña está a la vista.
  final bool activa;

  @override
  State<PestanaTeclado> createState() => _PestanaTecladoState();
}

class _PestanaTecladoState extends State<PestanaTeclado> {
  final _controlador = TextEditingController();
  final _foco = FocusNode();
  final _estadisticas = Estadisticas();
  final List<Lectura> _lecturas = [];

  @override
  void initState() {
    super.initState();
    _foco.addListener(_alCambiarFoco);
    _controlador.addListener(() => setState(() {}));
    _pedirFoco();
  }

  @override
  void didUpdateWidget(PestanaTeclado anterior) {
    super.didUpdateWidget(anterior);
    if (widget.activa == anterior.activa) return;
    if (widget.activa) {
      _pedirFoco();
    } else {
      _foco.unfocus();
    }
  }

  @override
  void dispose() {
    _foco.dispose();
    _controlador.dispose();
    super.dispose();
  }

  void _alCambiarFoco() {
    if (!_foco.hasFocus) _pedirFoco();
    if (mounted) setState(() {});
  }

  void _pedirFoco() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.activa && !_foco.hasFocus) _foco.requestFocus();
    });
  }

  /// El valor se registra tal cual llegó, sin recortar espacios.
  void _registrar(String crudo, {required bool conEnter}) {
    final lectura = _estadisticas.registrar(crudo);
    widget.bitacora.agregar(
      conEnter ? 'TECLADO' : 'TECLADO sin Enter',
      lectura.resumen,
    );
    setState(() => _lecturas.add(lectura));
    _controlador.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bufer = _controlador.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Campo oculto: sin teclado en pantalla y con el foco siempre puesto.
        SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _controlador,
              focusNode: _foco,
              autofocus: true,
              keyboardType: TextInputType.none,
              autocorrect: false,
              enableSuggestions: false,
              // Con onEditingComplete propio el campo no suelta el foco.
              onEditingComplete: () {},
              onSubmitted: (valor) => _registrar(valor, conEnter: true),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _foco.hasFocus ? Icons.keyboard : Icons.keyboard_hide,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _foco.hasFocus
                          ? 'Campo con foco: esperando lecturas'
                          : 'Campo SIN foco',
                    ),
                  ),
                ],
              ),
              Text(
                'Búfer sin Enter: [$bufer] (${bufer.length})',
                style: estiloMono,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: bufer.isEmpty
                        ? null
                        : () => _registrar(bufer, conEnter: false),
                    child: const Text('Registrar búfer'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _lecturas.clear();
                      _estadisticas.limpiar();
                      _controlador.clear();
                    }),
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListaLecturas(
            lecturas: _lecturas,
            conteo: _estadisticas.conteo,
          ),
        ),
      ],
    );
  }
}
