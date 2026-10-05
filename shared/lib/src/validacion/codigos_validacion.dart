/// Códigos de error que devuelven los validadores de `validadores.dart`.
///
/// Son identificadores estables, no textos: la app traduce cada código a un
/// mensaje para el usuario y la API los regresa tal cual en el error
/// `VALIDACION`.
abstract final class CodigoValidacion {
  /// El correo está vacío o no tiene forma de `nombre@dominio`.
  static const correoInvalido = 'CORREO_INVALIDO';

  /// El correo está bien escrito, pero su dominio no está permitido.
  static const dominioNoPermitido = 'DOMINIO_NO_PERMITIDO';

  /// La boleta no tiene exactamente 10 dígitos.
  static const boletaInvalida = 'BOLETA_INVALIDA';

  /// El número de empleado no tiene solo dígitos, de 4 a 10.
  static const numeroEmpleadoInvalido = 'NUMERO_EMPLEADO_INVALIDO';

  /// El valor no es ni una boleta ni un número de empleado válido.
  static const boletaOEmpleadoInvalido = 'BOLETA_O_EMPLEADO_INVALIDO';

  /// La contraseña tiene menos de 8 caracteres.
  static const passwordMuyCorta = 'PASSWORD_MUY_CORTA';

  /// La contraseña ocupa más de 72 bytes en UTF-8 (el límite de bcrypt).
  static const passwordMuyLarga = 'PASSWORD_MUY_LARGA';

  /// La contraseña no tiene ninguna letra.
  static const passwordSinLetra = 'PASSWORD_SIN_LETRA';

  /// La contraseña no tiene ningún número.
  static const passwordSinNumero = 'PASSWORD_SIN_NUMERO';

  /// El nombre está vacío o solo tiene espacios.
  static const nombreVacio = 'NOMBRE_VACIO';

  /// El nombre pasa de 120 caracteres.
  static const nombreMuyLargo = 'NOMBRE_MUY_LARGO';
}
