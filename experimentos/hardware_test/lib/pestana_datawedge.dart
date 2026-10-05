import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';

import 'bitacora.dart';
import 'lista_lecturas.dart';

/// Lecturas por Intent Output con flutter_datawedge. No crea ni modifica
/// perfiles: el perfil se configura a mano en el equipo.
class PestanaDataWedge extends StatefulWidget {
  const PestanaDataWedge({super.key, required this.bitacora});

  final Bitacora bitacora;

  @override
  State<PestanaDataWedge> createState() => _PestanaDataWedgeState();
}

class _PestanaDataWedgeState extends State<PestanaDataWedge> {
  // SOFT_RFID_TRIGGER no está en la API pública del paquete (su enum
  // DatawedgeApiTargets no lo trae y _sendDataWedgeCommand es privado). El lado
  // nativo sí reenvía cualquier comando de texto por este canal y método, que
  // son los que el propio paquete usa por dentro (ver README).
  static const _canalInterno = MethodChannel('channels/command');
  static const _metodoInterno = 'sendDataWedgeCommandStringParameter';
  static const _softRfidTrigger = 'com.symbol.datawedge.api.SOFT_RFID_TRIGGER';

  final _estadisticas = Estadisticas();
  final List<Lectura> _lecturas = [];
  final List<StreamSubscription<Object?>> _suscripciones = [];

  FlutterDataWedge? _dw;
  String _estado = 'Iniciando…';
  String _ultimoEvento = '-';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    for (final s in _suscripciones) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      final dw = FlutterDataWedge();
      _suscripciones
        ..add(dw.onScanResult.listen(_alLeer, onError: _alFallar))
        ..add(dw.onScannerEvent.listen(_alRecibirEvento, onError: _alFallar))
        ..add(dw.onScannerStatus.listen(_alCambiarEstado, onError: _alFallar));
      // initialize() solo pide a DataWedge las notificaciones de estado del
      // lector (REGISTER_FOR_NOTIFICATION); no toca perfiles.
      await dw.initialize();
      _dw = dw;
      _anotarEstado('Escuchando (initialize() terminó sin error)');
    } catch (e) {
      _anotarEstado('No se pudo iniciar: $e');
    }
  }

  void _anotarEstado(String texto) {
    widget.bitacora.agregar('DW', texto);
    if (mounted) setState(() => _estado = texto);
  }

  void _alFallar(Object error) => _anotarEstado('Error del stream: $error');

  void _alLeer(ScanResult r) {
    final detalle = [
      'toString: $r',
      'toJson: ${jsonEncode(r.toJson())}',
      'data: [${r.data}] (${r.data.length})',
      'labelType: [${r.labelType}]',
      'source: [${r.source}]',
    ].join('\n');
    final lectura = _estadisticas.registrar(r.data, detalle: detalle);
    widget.bitacora.agregar(
      'DW lectura',
      '${lectura.resumen} source=[${r.source}] labelType=[${r.labelType}]',
    );
    setState(() => _lecturas.add(lectura));
  }

  void _alRecibirEvento(ActionResult e) {
    widget.bitacora.agregar('DW resultado', e.toString());
    setState(() => _ultimoEvento = e.toString());
  }

  void _alCambiarEstado(ScannerStatus s) {
    widget.bitacora.agregar('DW estado', s.toString());
    setState(() => _ultimoEvento = s.toString());
  }

  Future<void> _softRfid(String parametro) async {
    try {
      await _canalInterno.invokeMethod<void>(
        _metodoInterno,
        jsonEncode({
          'command': _softRfidTrigger,
          'parameter': parametro,
          'commandIdentifier':
              'rfid_${parametro}_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );
      widget.bitacora.agregar('DW comando', 'SOFT_RFID_TRIGGER $parametro');
    } catch (e) {
      _anotarEstado('SOFT_RFID_TRIGGER $parametro falló: $e');
    }
  }

  Future<void> _softScan(bool activar) async {
    final resultado = await _dw?.scannerControl(activar);
    widget.bitacora.agregar(
      'DW comando',
      'SOFT_SCAN_TRIGGER ${activar ? 'START' : 'STOP'} → $resultado',
    );
  }

  Future<void> _perfilActivo() async {
    final resultado = await _dw?.requestActiveProfile();
    widget.bitacora.agregar('DW comando', 'GET_ACTIVE_PROFILE → $resultado');
  }

  @override
  Widget build(BuildContext context) {
    final listo = _dw != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_estado),
              Text('Último evento: $_ultimoEvento', style: estiloMono),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: listo ? () => _softRfid('START_SCANNING') : null,
                    child: const Text('RFID START'),
                  ),
                  FilledButton(
                    onPressed: listo ? () => _softRfid('STOP_SCANNING') : null,
                    child: const Text('RFID STOP'),
                  ),
                  OutlinedButton(
                    onPressed: listo ? () => _softScan(true) : null,
                    child: const Text('Código START'),
                  ),
                  OutlinedButton(
                    onPressed: listo ? () => _softScan(false) : null,
                    child: const Text('Código STOP'),
                  ),
                  OutlinedButton(
                    onPressed: listo ? _perfilActivo : null,
                    child: const Text('Perfil activo'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _lecturas.clear();
                      _estadisticas.limpiar();
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
