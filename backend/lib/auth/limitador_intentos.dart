/// Cuenta los inicios de sesión fallidos por correo dentro de una ventana de
/// tiempo.
///
/// Vive en memoria: el conteo se pierde al reiniciar la API y no se comparte
/// entre instancias. Alcanza porque el despliegue es de una sola instancia.
class LimitadorIntentos {
  /// Crea un limitador que bloquea al llegar a [maximo] fallos en [ventana].
  /// [ahora] permite controlar el reloj en las pruebas.
  LimitadorIntentos({
    this.maximo = 5,
    this.ventana = const Duration(minutes: 15),
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  /// Fallos permitidos dentro de la ventana.
  final int maximo;

  /// Tiempo durante el cual cuenta un fallo.
  final Duration ventana;

  final DateTime Function() _ahora;
  final _fallos = <String, List<DateTime>>{};

  /// Indica si [clave] ya acumuló [maximo] fallos dentro de la ventana.
  bool estaBloqueado(String clave) => _vigentes(clave).length >= maximo;

  /// Anota un intento fallido para [clave].
  void registrarFallo(String clave) {
    _descartarVencidos();
    _fallos.putIfAbsent(clave, () => []).add(_ahora());
  }

  /// Olvida los fallos de [clave] (inicio de sesión correcto).
  void limpiar(String clave) => _fallos.remove(clave);

  List<DateTime> _vigentes(String clave) {
    final limite = _ahora().subtract(ventana);
    final fallos = _fallos[clave];
    if (fallos == null) return const [];
    fallos.removeWhere((momento) => !momento.isAfter(limite));
    if (fallos.isEmpty) _fallos.remove(clave);
    return fallos;
  }

  /// Evita que el mapa crezca sin límite con correos que ya no reintentan.
  void _descartarVencidos() {
    for (final clave in _fallos.keys.toList()) {
      _vigentes(clave);
    }
  }
}
