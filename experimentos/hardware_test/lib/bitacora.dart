import 'package:flutter/foundation.dart';

/// Hora local con milisegundos: `13:15:02.417`.
String formatoHora(DateTime t) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final ms = t.millisecond.toString().padLeft(3, '0');
  return '${dos(t.hour)}:${dos(t.minute)}:${dos(t.second)}.$ms';
}

/// Bytes en hexadecimal, en mayúsculas y sin separadores.
String aHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

/// Bitácora cronológica de todo lo que pasa en las pestañas.
class Bitacora extends ChangeNotifier {
  final List<String> _lineas = [];

  List<String> get lineas => List.unmodifiable(_lineas);

  void agregar(String origen, String texto) {
    _lineas.add('${formatoHora(DateTime.now())} [$origen] $texto');
    notifyListeners();
  }

  void limpiar() {
    _lineas.clear();
    notifyListeners();
  }

  String comoTexto() => _lineas.join('\n');
}

/// Una lectura ya contada: el valor crudo y sus estadísticas.
class Lectura {
  Lectura({
    required this.hora,
    required this.crudo,
    required this.repeticiones,
    this.msDesdeAnterior,
    this.detalle,
  });

  final DateTime hora;
  final String crudo;

  /// Veces que se ha visto este mismo valor, contando esta.
  final int repeticiones;

  /// Milisegundos desde la lectura anterior del mismo valor; `null` si es la primera.
  final int? msDesdeAnterior;

  /// Volcado adicional (campos del resultado del plugin).
  final String? detalle;

  String get resumen =>
      '[$crudo] long=${crudo.length} '
      'ms_desde_anterior=${msDesdeAnterior ?? '-'} rep=$repeticiones';
}

/// Cuenta repeticiones por valor y el tiempo entre lecturas del mismo valor.
class Estadisticas {
  final Map<String, int> _conteo = {};
  final Map<String, DateTime> _ultima = {};

  Map<String, int> get conteo => Map.unmodifiable(_conteo);

  Lectura registrar(String crudo, {String? detalle}) {
    final ahora = DateTime.now();
    final anterior = _ultima[crudo];
    _ultima[crudo] = ahora;
    final repeticiones = _conteo.update(crudo, (n) => n + 1, ifAbsent: () => 1);
    return Lectura(
      hora: ahora,
      crudo: crudo,
      repeticiones: repeticiones,
      msDesdeAnterior: anterior == null
          ? null
          : ahora.difference(anterior).inMilliseconds,
      detalle: detalle,
    );
  }

  void limpiar() {
    _conteo.clear();
    _ultima.clear();
  }
}
