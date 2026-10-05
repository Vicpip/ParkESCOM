import 'package:backend/auth/limitador_intentos.dart';
import 'package:test/test.dart';

void main() {
  late DateTime ahora;
  late LimitadorIntentos limitador;

  setUp(() {
    ahora = DateTime.utc(2026, 10, 5, 12);
    limitador = LimitadorIntentos(ahora: () => ahora);
  });

  void fallar(String clave, int veces) {
    for (var i = 0; i < veces; i++) {
      limitador.registrarFallo(clave);
    }
  }

  test('bloquea al quinto fallo, no antes', () {
    fallar('a@ipn.mx', 4);
    expect(limitador.estaBloqueado('a@ipn.mx'), isFalse);

    fallar('a@ipn.mx', 1);
    expect(limitador.estaBloqueado('a@ipn.mx'), isTrue);
  });

  test('cada correo lleva su propio conteo', () {
    fallar('a@ipn.mx', 5);

    expect(limitador.estaBloqueado('b@ipn.mx'), isFalse);
  });

  test('los fallos dejan de contar a los 15 minutos', () {
    fallar('a@ipn.mx', 5);

    ahora = ahora.add(const Duration(minutes: 14, seconds: 59));
    expect(limitador.estaBloqueado('a@ipn.mx'), isTrue);

    ahora = ahora.add(const Duration(seconds: 1));
    expect(limitador.estaBloqueado('a@ipn.mx'), isFalse);
  });

  test('la ventana es deslizante: solo cuentan los fallos recientes', () {
    fallar('a@ipn.mx', 3);
    ahora = ahora.add(const Duration(minutes: 10));
    fallar('a@ipn.mx', 2);
    expect(limitador.estaBloqueado('a@ipn.mx'), isTrue);

    // Vencen los tres primeros; quedan dos.
    ahora = ahora.add(const Duration(minutes: 6));
    expect(limitador.estaBloqueado('a@ipn.mx'), isFalse);
  });

  test('limpiar olvida los fallos', () {
    fallar('a@ipn.mx', 5);
    limitador.limpiar('a@ipn.mx');

    expect(limitador.estaBloqueado('a@ipn.mx'), isFalse);
  });
}
