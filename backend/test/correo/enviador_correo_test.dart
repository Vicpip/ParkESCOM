import 'package:backend/config/configuracion.dart';
import 'package:backend/config/entorno.dart';
import 'package:backend/correo/enviador_correo.dart';
import 'package:test/test.dart';

void main() {
  group('crearEnviadorCorreo', () {
    test('desarrollo sin SMTP_HOST → imprime en consola', () {
      expect(
        crearEnviadorCorreo(entorno: Entorno.desarrollo),
        isA<EnviadorConsola>(),
      );
    });

    test('producción sin SMTP_HOST → la API no arranca', () {
      expect(
        () => crearEnviadorCorreo(entorno: Entorno.produccion),
        throwsA(
          isA<ErrorDeConfiguracion>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('SMTP_HOST'),
          ),
        ),
      );
    });

    test('con SMTP_HOST se usa SMTP en los dos entornos', () {
      for (final entorno in Entorno.values) {
        expect(
          crearEnviadorCorreo(
            entorno: entorno,
            host: 'smtp.example.com',
            remitente: 'no-responder@example.com',
          ),
          isA<EnviadorSmtp>(),
        );
      }
    });

    test('con SMTP_HOST exige SMTP_FROM y un puerto numérico', () {
      expect(
        () => crearEnviadorCorreo(
          entorno: Entorno.produccion,
          host: 'smtp.example.com',
        ),
        throwsA(isA<ErrorDeConfiguracion>()),
      );
      expect(
        () => crearEnviadorCorreo(
          entorno: Entorno.produccion,
          host: 'smtp.example.com',
          remitente: 'no-responder@example.com',
          puerto: 'abc',
        ),
        throwsA(isA<ErrorDeConfiguracion>()),
      );
    });
  });

  group('Entorno.deNombre', () {
    test('sin variable se asume producción', () {
      expect(Entorno.deNombre(null), Entorno.produccion);
    });

    test('reconoce los dos valores y rechaza cualquier otro', () {
      expect(Entorno.deNombre('desarrollo'), Entorno.desarrollo);
      expect(Entorno.deNombre(' Produccion '), Entorno.produccion);
      expect(
        () => Entorno.deNombre('pruebas'),
        throwsA(isA<ErrorDeConfiguracion>()),
      );
    });
  });

  group('EnviadorConsola', () {
    test('escribe destinatario, asunto y enlace', () async {
      final lineas = <String>[];
      await EnviadorConsola(escribir: lineas.add).enviar(
        const CorreoSaliente.restablecimiento(
          destinatario: 'alguien@alumno.ipn.mx',
          enlace: 'https://panel.example/restablecer?token=abc',
        ),
      );

      expect(lineas.single, contains('alguien@alumno.ipn.mx'));
      expect(lineas.single, contains('Restablece tu contraseña de ParkESCOM'));
      expect(
        lineas.single,
        contains('https://panel.example/restablecer?token=abc'),
      );
    });
  });
}
