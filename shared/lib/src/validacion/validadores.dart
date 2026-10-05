import 'codigos_validacion.dart';

/// Longitud mínima de una contraseña.
const longitudMinimaPassword = 8;

/// Longitud máxima de un nombre.
const longitudMaximaNombre = 120;

final _formatoCorreo = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
);
final _boleta = RegExp(r'^[0-9]{10}$');
final _numeroEmpleado = RegExp(r'^[0-9]{4,10}$');
final _letra = RegExp(r'\p{L}', unicode: true);
final _numero = RegExp('[0-9]');

/// Deja el correo como se guarda y se compara: sin espacios alrededor y en
/// minúsculas.
String normalizarCorreo(String correo) => correo.trim().toLowerCase();

/// Valida el formato de [correo] y que su dominio esté en
/// [dominiosPermitidos] (coincidencia exacta, sin distinguir mayúsculas; un
/// subdominio no entra por estar permitido su dominio padre).
///
/// Devuelve `null` si es válido, [CodigoValidacion.correoInvalido] si el
/// formato es incorrecto o [CodigoValidacion.dominioNoPermitido] si el dominio
/// no está en la lista.
String? validarCorreo(
  String correo, {
  required Iterable<String> dominiosPermitidos,
}) {
  final normalizado = normalizarCorreo(correo);
  if (normalizado.length > 254 || !_formatoCorreo.hasMatch(normalizado)) {
    return CodigoValidacion.correoInvalido;
  }
  final dominio = normalizado.substring(normalizado.lastIndexOf('@') + 1);
  final permitido = dominiosPermitidos.any(
    (candidato) => candidato.trim().toLowerCase() == dominio,
  );
  return permitido ? null : CodigoValidacion.dominioNoPermitido;
}

/// Valida una boleta: exactamente 10 dígitos.
///
/// Devuelve `null` o [CodigoValidacion.boletaInvalida].
String? validarBoleta(String boleta) =>
    _boleta.hasMatch(boleta) ? null : CodigoValidacion.boletaInvalida;

/// Valida un número de empleado: solo dígitos, de 4 a 10.
///
/// Devuelve `null` o [CodigoValidacion.numeroEmpleadoInvalido].
String? validarNumeroEmpleado(String numero) => _numeroEmpleado.hasMatch(numero)
    ? null
    : CodigoValidacion.numeroEmpleadoInvalido;

/// Valida el campo único del registro, que acepta una boleta o un número de
/// empleado.
///
/// Devuelve `null` o [CodigoValidacion.boletaOEmpleadoInvalido].
String? validarBoletaOEmpleado(String valor) =>
    validarBoleta(valor) == null || validarNumeroEmpleado(valor) == null
    ? null
    : CodigoValidacion.boletaOEmpleadoInvalido;

/// Valida una contraseña: mínimo 8 caracteres, al menos una letra y un número.
///
/// Devuelve `null`, [CodigoValidacion.passwordMuyCorta],
/// [CodigoValidacion.passwordSinLetra] o [CodigoValidacion.passwordSinNumero].
String? validarPassword(String password) {
  if (password.runes.length < longitudMinimaPassword) {
    return CodigoValidacion.passwordMuyCorta;
  }
  if (!_letra.hasMatch(password)) return CodigoValidacion.passwordSinLetra;
  if (!_numero.hasMatch(password)) return CodigoValidacion.passwordSinNumero;
  return null;
}

/// Valida un nombre: no vacío (sin contar espacios alrededor) y de máximo 120
/// caracteres.
///
/// Devuelve `null`, [CodigoValidacion.nombreVacio] o
/// [CodigoValidacion.nombreMuyLargo].
String? validarNombre(String nombre) {
  final limpio = nombre.trim();
  if (limpio.isEmpty) return CodigoValidacion.nombreVacio;
  if (limpio.runes.length > longitudMaximaNombre) {
    return CodigoValidacion.nombreMuyLargo;
  }
  return null;
}
