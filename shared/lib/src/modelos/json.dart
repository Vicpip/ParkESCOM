/// Devuelve [valor] si viene y es del tipo esperado; si no, lanza un
/// [FormatException] que nombra el [campo] que falló.
T exigirCampo<T extends Object>(Object? valor, String campo) {
  if (valor is T) return valor;
  throw FormatException('Campo "$campo" ausente o con un valor inesperado');
}

/// Lee una fecha ISO 8601 opcional.
DateTime? fechaDeJson(Object? valor) =>
    valor is String ? DateTime.parse(valor) : null;

/// Escribe una fecha como ISO 8601 en UTC, o `null` si no hay.
String? fechaAJson(DateTime? fecha) => fecha?.toUtc().toIso8601String();
