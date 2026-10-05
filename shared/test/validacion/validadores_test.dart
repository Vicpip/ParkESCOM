import 'dart:convert';

import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('validarCorreo', () {
    const dominios = ['ipn.mx', 'alumno.ipn.mx'];
    String? validar(String correo) =>
        validarCorreo(correo, dominiosPermitidos: dominios);

    test('acepta un correo de un dominio permitido', () {
      expect(validar('ana.perez@alumno.ipn.mx'), isNull);
      expect(validar('profesor+clase@ipn.mx'), isNull);
    });

    test('no distingue mayúsculas ni espacios alrededor', () {
      expect(validar('  Ana.Perez@ALUMNO.IPN.MX '), isNull);
      expect(
        validarCorreo('ana@ipn.mx', dominiosPermitidos: [' IPN.MX ']),
        isNull,
      );
    });

    test('rechaza formatos inválidos', () {
      for (final correo in [
        '',
        'ana',
        'ana@',
        '@ipn.mx',
        'ana@ipn',
        'ana perez@ipn.mx',
        'ana@@ipn.mx',
        'ana@ipn..mx',
        '${'a' * 250}@ipn.mx',
      ]) {
        expect(
          validar(correo),
          CodigoValidacion.correoInvalido,
          reason: '"$correo"',
        );
      }
    });

    test('rechaza dominios fuera de la lista', () {
      expect(validar('ana@gmail.com'), CodigoValidacion.dominioNoPermitido);
      expect(
        validarCorreo('ana@ipn.mx', dominiosPermitidos: const []),
        CodigoValidacion.dominioNoPermitido,
      );
    });

    test('un subdominio o un sufijo parecido no cuenta como permitido', () {
      expect(
        validar('ana@otro.alumno.ipn.mx'),
        CodigoValidacion.dominioNoPermitido,
      );
      expect(validar('ana@falsoipn.mx'), CodigoValidacion.dominioNoPermitido);
      expect(
        validar('ana@ipn.mx.ejemplo.com'),
        CodigoValidacion.dominioNoPermitido,
      );
    });
  });

  test('normalizarCorreo quita espacios y pasa a minúsculas', () {
    expect(normalizarCorreo('  Ana@IPN.mx '), 'ana@ipn.mx');
  });

  group('validarBoleta', () {
    test('acepta exactamente 10 dígitos', () {
      expect(validarBoleta('2026630001'), isNull);
    });

    test('rechaza otras longitudes y caracteres que no son dígitos', () {
      for (final boleta in [
        '',
        '202663000',
        '20266300011',
        '2026A30001',
        ' 2026630001',
        '2026630001\n',
      ]) {
        expect(
          validarBoleta(boleta),
          CodigoValidacion.boletaInvalida,
          reason: '"$boleta"',
        );
      }
    });
  });

  group('validarNumeroEmpleado', () {
    test('acepta de 4 a 10 dígitos', () {
      expect(validarNumeroEmpleado('1234'), isNull);
      expect(validarNumeroEmpleado('1234567890'), isNull);
    });

    test('rechaza longitudes fuera de rango y caracteres no numéricos', () {
      for (final numero in ['', '123', '12345678901', '12a4', '12-34']) {
        expect(
          validarNumeroEmpleado(numero),
          CodigoValidacion.numeroEmpleadoInvalido,
          reason: '"$numero"',
        );
      }
    });
  });

  group('validarBoletaOEmpleado', () {
    test('acepta una boleta o un número de empleado', () {
      expect(validarBoletaOEmpleado('2026630001'), isNull);
      expect(validarBoletaOEmpleado('90001'), isNull);
    });

    test('rechaza lo que no es ninguno de los dos', () {
      expect(
        validarBoletaOEmpleado('123'),
        CodigoValidacion.boletaOEmpleadoInvalido,
      );
      expect(
        validarBoletaOEmpleado('PE-1234'),
        CodigoValidacion.boletaOEmpleadoInvalido,
      );
    });
  });

  group('validarPassword', () {
    test('acepta 8 caracteres con letra y número', () {
      expect(validarPassword('abcdefg1'), isNull);
      expect(validarPassword('Contraseña2026!'), isNull);
    });

    test('rechaza menos de 8 caracteres', () {
      expect(validarPassword('abc1234'), CodigoValidacion.passwordMuyCorta);
      expect(validarPassword(''), CodigoValidacion.passwordMuyCorta);
    });

    test('rechaza si falta una letra', () {
      expect(validarPassword('12345678'), CodigoValidacion.passwordSinLetra);
    });

    test('rechaza si falta un número', () {
      expect(validarPassword('abcdefgh'), CodigoValidacion.passwordSinNumero);
    });

    test('una letra acentuada cuenta como letra', () {
      expect(validarPassword('ñ1234567'), isNull);
    });

    test('acepta exactamente 72 bytes y rechaza 73', () {
      expect(validarPassword('a1${'x' * 70}'), isNull);
      expect(
        validarPassword('a1${'x' * 71}'),
        CodigoValidacion.passwordMuyLarga,
      );
    });

    test('el límite es de bytes en UTF-8, no de caracteres', () {
      // 40 caracteres: "a1" (2 bytes), 30 "ñ" (60 bytes) y 8 "é" (16 bytes).
      final conAcentos = 'a1${'ñ' * 30}${'é' * 8}';
      expect(conAcentos.length, lessThan(72));
      expect(utf8.encode(conAcentos).length, 78);
      expect(validarPassword(conAcentos), CodigoValidacion.passwordMuyLarga);

      // 20 caracteres visibles: "a1" y 18 emojis de 4 bytes cada uno.
      final conEmojis = 'a1${'🚗' * 18}';
      expect(conEmojis.runes.length, 20);
      expect(conEmojis.length, lessThan(72));
      expect(utf8.encode(conEmojis).length, 74);
      expect(validarPassword(conEmojis), CodigoValidacion.passwordMuyLarga);

      // Mezcla de acentos y emojis con menos de 72 caracteres.
      final mezcla = 'Contraseña1${'á' * 20}${'🔒' * 6}';
      expect(mezcla.length, lessThan(72));
      expect(utf8.encode(mezcla).length, greaterThan(72));
      expect(validarPassword(mezcla), CodigoValidacion.passwordMuyLarga);
    });

    test('acentos y emojis que caben en 72 bytes se aceptan', () {
      expect(validarPassword('Contraseña1🚗🔒'), isNull);
    });
  });

  group('validarNombre', () {
    test('acepta un nombre normal y uno de 120 caracteres', () {
      expect(validarNombre('María José Hernández'), isNull);
      expect(validarNombre('a' * 120), isNull);
    });

    test('rechaza vacío o solo espacios', () {
      expect(validarNombre(''), CodigoValidacion.nombreVacio);
      expect(validarNombre('   '), CodigoValidacion.nombreVacio);
    });

    test('rechaza más de 120 caracteres', () {
      expect(validarNombre('a' * 121), CodigoValidacion.nombreMuyLargo);
    });

    test('los espacios alrededor no cuentan para el límite', () {
      expect(validarNombre('  ${'a' * 120}  '), isNull);
    });
  });
}
