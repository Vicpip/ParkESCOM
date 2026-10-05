import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'bitacora.dart';
import 'lista_lecturas.dart';

/// Lectura de calcomanías NFC con nfc_manager (modo lector de Android).
class PestanaNfc extends StatefulWidget {
  const PestanaNfc({super.key, required this.bitacora, required this.activa});

  final Bitacora bitacora;

  /// Al salir de la pestaña la sesión de lectura se cierra.
  final bool activa;

  @override
  State<PestanaNfc> createState() => _PestanaNfcState();
}

class _PestanaNfcState extends State<PestanaNfc> {
  final _estadisticas = Estadisticas();
  final List<Lectura> _lecturas = [];
  StreamSubscription<NfcAdapterStateAndroid>? _cambiosDeEstado;

  String _disponibilidad = 'Sin revisar';
  bool _habilitado = false;
  bool _sesionAbierta = false;

  @override
  void initState() {
    super.initState();
    try {
      _cambiosDeEstado = NfcManagerAndroid.instance.onStateChanged.listen((e) {
        widget.bitacora.agregar('NFC', 'Adaptador: ${e.name}');
        _revisar();
      });
    } catch (e) {
      widget.bitacora.agregar('NFC', 'Sin avisos del adaptador: $e');
    }
    _revisar();
  }

  @override
  void didUpdateWidget(PestanaNfc anterior) {
    super.didUpdateWidget(anterior);
    if (!widget.activa && anterior.activa && _sesionAbierta) _cerrarSesion();
  }

  @override
  void dispose() {
    _cambiosDeEstado?.cancel();
    if (_sesionAbierta) NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _revisar() async {
    String texto;
    var habilitado = false;
    try {
      final d = await NfcManager.instance.checkAvailability();
      habilitado = d == NfcAvailability.enabled;
      texto = switch (d) {
        NfcAvailability.enabled => 'Disponible y habilitado',
        NfcAvailability.disabled => 'Disponible pero apagado en Ajustes',
        NfcAvailability.unsupported => 'Este equipo no tiene NFC',
      };
    } catch (e) {
      texto = 'No se pudo consultar: $e';
    }
    widget.bitacora.agregar('NFC', 'Disponibilidad: $texto');
    if (!mounted) return;
    setState(() {
      _disponibilidad = texto;
      _habilitado = habilitado;
    });
  }

  Future<void> _abrirSesion() async {
    try {
      await NfcManager.instance.startSession(
        pollingOptions: NfcPollingOption.values.toSet(),
        onDiscovered: _alDescubrir,
      );
      widget.bitacora.agregar('NFC', 'Sesión de lectura abierta');
      if (mounted) setState(() => _sesionAbierta = true);
    } catch (e) {
      widget.bitacora.agregar('NFC', 'No se pudo abrir la sesión: $e');
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      await NfcManager.instance.stopSession();
      widget.bitacora.agregar('NFC', 'Sesión de lectura cerrada');
    } catch (e) {
      widget.bitacora.agregar('NFC', 'Error al cerrar la sesión: $e');
    }
    if (mounted) setState(() => _sesionAbierta = false);
  }

  void _alDescubrir(NfcTag tag) {
    try {
      final android = NfcTagAndroid.from(tag);
      if (android == null) {
        widget.bitacora.agregar('NFC', 'Etiqueta sin datos de Android');
        return;
      }
      final uid = aHex(android.id);
      final lineas = <String>[
        'UID: $uid (${android.id.length} bytes)',
        'Tecnologías:',
        for (final t in android.techList) '  $t',
      ];
      final nfcA = NfcAAndroid.from(tag);
      if (nfcA != null) {
        lineas.add('NfcA: ATQA=${aHex(nfcA.atqa)} SAK=${nfcA.sak}');
      }
      lineas.addAll(_describirNdef(NdefAndroid.from(tag)));

      final lectura = _estadisticas.registrar(uid, detalle: lineas.join('\n'));
      widget.bitacora.agregar(
        'NFC lectura',
        '${lectura.resumen}\n${lineas.join('\n')}',
      );
      if (mounted) setState(() => _lecturas.add(lectura));
    } catch (e) {
      widget.bitacora.agregar('NFC', 'Error al interpretar la etiqueta: $e');
    }
  }

  List<String> _describirNdef(NdefAndroid? ndef) {
    if (ndef == null) return ['NDEF: la etiqueta no es NDEF'];
    final mensaje = ndef.cachedNdefMessage;
    return [
      'NDEF: tipo=${ndef.type} capacidad=${ndef.maxSize} '
          'escribible=${ndef.isWritable}',
      if (mensaje == null || mensaje.records.isEmpty)
        'NDEF: sin mensaje'
      else
        for (final (i, r) in mensaje.records.indexed) ...[
          '  registro $i: formato=${r.typeNameFormat.name} '
              'tipo=[${utf8.decode(r.type, allowMalformed: true)}]',
          '    contenido hex: ${aHex(r.payload)}',
          '    contenido texto: [${utf8.decode(r.payload, allowMalformed: true)}]',
        ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_habilitado ? Icons.nfc : Icons.block, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('NFC: $_disponibilidad')),
                ],
              ),
              Text(
                _sesionAbierta
                    ? 'Sesión abierta: acerca la calcomanía'
                    : 'Sesión cerrada',
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _sesionAbierta
                        ? _cerrarSesion
                        : (_habilitado ? _abrirSesion : null),
                    child: Text(
                      _sesionAbierta ? 'Cerrar sesión' : 'Abrir sesión',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _revisar,
                    child: const Text('Revisar NFC'),
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
