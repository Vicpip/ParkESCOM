import 'package:shared/shared.dart';
import 'package:test/test.dart';

/// Datos válidos de un auto, con los campos de [cambios] sustituidos (un
/// valor `null` quita el campo).
DatosVehiculo _datos([Map<String, Object?> cambios = const {}]) =>
    DatosVehiculo.fromJson({
      'tipo': 'auto',
      'placa': 'ABC-123-D',
      'marca': 'Nissan',
      'modelo': 'Versa 2020',
      'color': 'Gris',
      'foto_id': 'foto-vehiculo',
      ...cambios,
    });

void main() {
  group('normalizarPlaca', () {
    test('pasa a mayúsculas y quita todos los espacios', () {
      expect(normalizarPlaca(' abc 123\td '), 'ABC123D');
      expect(normalizarPlaca('a1b-2c3'), 'A1B-2C3');
      expect(normalizarPlaca('   '), '');
    });
  });

  group('DatosVehiculo normaliza', () {
    test('textos sin espacios alrededor y placa en mayúsculas', () {
      final datos = _datos({
        'tipo': ' auto ',
        'placa': ' abc 123 d ',
        'numero_serie': '  3N1CN7AD5LK123456 ',
        'marca': '  Nissan ',
        'modelo': ' Versa 2020  ',
        'color': ' Gris ',
      });

      expect(datos.tipo, 'auto');
      expect(datos.tipoVehiculo, TipoVehiculo.auto);
      expect(datos.placa, 'ABC123D');
      expect(datos.numeroSerie, '3N1CN7AD5LK123456');
      expect(datos.marca, 'Nissan');
      expect(datos.modelo, 'Versa 2020');
      expect(datos.color, 'Gris');
      expect(datos.validar(), isEmpty);
    });

    test('los opcionales vacíos quedan en null', () {
      final datos = _datos({
        'placa': '   ',
        'numero_serie': '',
        'foto_id': ' ',
        'foto_placa_id': '',
      });

      expect(datos.placa, isNull);
      expect(datos.numeroSerie, isNull);
      expect(datos.fotoId, isNull);
      expect(datos.fotoPlacaId, isNull);
    });

    test('un campo que no es texto cuenta como vacío', () {
      final datos = DatosVehiculo.fromJson(const {
        'tipo': 7,
        'placa': ['ABC'],
        'marca': true,
        'modelo': null,
        'foto_id': 42,
      });

      expect(datos.validar(), {
        'tipo': CodigoValidacion.tipoVehiculoInvalido,
        'marca': CodigoValidacion.marcaVacia,
        'modelo': CodigoValidacion.modeloVacio,
        'color': CodigoValidacion.colorVacio,
        'foto_id': CodigoValidacion.fotoVehiculoRequerida,
      });
    });

    test('toJson y fromJson son inversos', () {
      final json = _datos({
        'tipo': 'moto',
        'numero_serie': 'XYZ',
        'foto_placa_id': 'foto-placa',
      }).toJson();

      expect(json, {
        'tipo': 'moto',
        'placa': 'ABC-123-D',
        'numero_serie': 'XYZ',
        'marca': 'Nissan',
        'modelo': 'Versa 2020',
        'color': 'Gris',
        'foto_id': 'foto-vehiculo',
        'foto_placa_id': 'foto-placa',
      });
      expect(DatosVehiculo.fromJson(json).toJson(), json);
    });
  });

  group('tipo', () {
    test('acepta auto, moto, bici y scooter', () {
      for (final tipo in ['auto', 'bici', 'scooter']) {
        expect(_datos({'tipo': tipo}).validar(), isEmpty, reason: tipo);
      }
      expect(
        _datos({'tipo': 'moto', 'foto_placa_id': 'foto-placa'}).validar(),
        isEmpty,
      );
    });

    test('rechaza cualquier otro valor', () {
      for (final tipo in ['', 'camion', 'AUTO', 'Moto']) {
        expect(_datos({'tipo': tipo}).validar(), {
          'tipo': CodigoValidacion.tipoVehiculoInvalido,
        }, reason: '"$tipo"');
      }
    });

    test('con un tipo inválido no se exige placa ni foto de placa', () {
      final errores = _datos({'tipo': 'camion', 'placa': null}).validar();

      expect(errores, {'tipo': CodigoValidacion.tipoVehiculoInvalido});
    });
  });

  group('placa', () {
    test('es obligatoria en auto y moto', () {
      expect(_datos({'placa': null}).validar(), {
        'placa': CodigoValidacion.placaRequerida,
      });
      expect(
        _datos({
          'tipo': 'moto',
          'placa': '  ',
          'foto_placa_id': 'foto-placa',
        }).validar(),
        {'placa': CodigoValidacion.placaRequerida},
      );
    });

    test('es opcional en bici y scooter', () {
      for (final tipo in ['bici', 'scooter']) {
        expect(
          _datos({'tipo': tipo, 'placa': null}).validar(),
          isEmpty,
          reason: tipo,
        );
      }
    });

    test('solo letras, números y guiones', () {
      for (final placa in ['ABC123', 'a1b-2c3', '123', 'A-B-C', ' ab 12 ']) {
        expect(_datos({'placa': placa}).validar(), isEmpty, reason: placa);
      }
      for (final placa in ['ABC_123', 'ABC.123', 'ÑAN-123', 'ABC/123', '*']) {
        expect(_datos({'placa': placa}).validar(), {
          'placa': CodigoValidacion.placaInvalida,
        }, reason: placa);
      }
    });

    test('si viene en una bici, también se revisa su formato', () {
      expect(_datos({'tipo': 'bici', 'placa': 'B#1'}).validar(), {
        'placa': CodigoValidacion.placaInvalida,
      });
    });

    test('máximo 15 caracteres', () {
      expect(_datos({'placa': 'A' * 15}).validar(), isEmpty);
      expect(_datos({'placa': 'A' * 16}).validar(), {
        'placa': CodigoValidacion.placaInvalida,
      });
    });
  });

  group('marca, modelo y color', () {
    const codigos = {
      'marca': (CodigoValidacion.marcaVacia, CodigoValidacion.marcaMuyLarga),
      'modelo': (CodigoValidacion.modeloVacio, CodigoValidacion.modeloMuyLargo),
      'color': (CodigoValidacion.colorVacio, CodigoValidacion.colorMuyLargo),
    };

    test('no pueden ir vacíos ni solo con espacios', () {
      for (final MapEntry(key: campo, value: (vacio, _)) in codigos.entries) {
        for (final valor in ['', '   ', null]) {
          expect(_datos({campo: valor}).validar(), {
            campo: vacio,
          }, reason: '$campo = "$valor"');
        }
      }
    });

    test('máximo 60 caracteres', () {
      for (final MapEntry(key: campo, value: (_, largo)) in codigos.entries) {
        expect(_datos({campo: 'á' * 60}).validar(), isEmpty, reason: campo);
        expect(_datos({campo: 'a' * 61}).validar(), {
          campo: largo,
        }, reason: campo);
      }
    });
  });

  group('número de serie', () {
    test('es opcional', () {
      expect(_datos({'numero_serie': null}).validar(), isEmpty);
      expect(_datos({'numero_serie': 'ABC123'}).validar(), isEmpty);
    });

    test('máximo 60 caracteres', () {
      expect(_datos({'numero_serie': 'a' * 60}).validar(), isEmpty);
      expect(_datos({'numero_serie': 'a' * 61}).validar(), {
        'numero_serie': CodigoValidacion.numeroSerieMuyLargo,
      });
    });
  });

  group('fotos', () {
    test('la del vehículo es obligatoria en todos los tipos', () {
      for (final tipo in ['auto', 'bici', 'scooter']) {
        expect(_datos({'tipo': tipo, 'foto_id': null}).validar(), {
          'foto_id': CodigoValidacion.fotoVehiculoRequerida,
        }, reason: tipo);
      }
    });

    test('la de la placa es obligatoria solo en moto', () {
      expect(_datos({'tipo': 'moto'}).validar(), {
        'foto_placa_id': CodigoValidacion.fotoPlacaRequerida,
      });
      for (final tipo in ['auto', 'bici', 'scooter']) {
        expect(_datos({'tipo': tipo}).validar(), isEmpty, reason: tipo);
      }
    });

    test('una moto sin ninguna foto reporta las dos', () {
      expect(_datos({'tipo': 'moto', 'foto_id': null}).validar(), {
        'foto_id': CodigoValidacion.fotoVehiculoRequerida,
        'foto_placa_id': CodigoValidacion.fotoPlacaRequerida,
      });
    });
  });

  test('reporta todos los campos con error a la vez', () {
    final errores = DatosVehiculo.fromJson(const {
      'tipo': 'auto',
      'placa': 'abc 123!',
      'numero_serie': 'x',
      'marca': '',
      'modelo': 'Versa',
      'color': '  ',
    }).validar();

    expect(errores, {
      'placa': CodigoValidacion.placaInvalida,
      'marca': CodigoValidacion.marcaVacia,
      'color': CodigoValidacion.colorVacio,
      'foto_id': CodigoValidacion.fotoVehiculoRequerida,
    });
  });
}
