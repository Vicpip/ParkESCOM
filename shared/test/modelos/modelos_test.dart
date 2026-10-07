import 'dart:convert';

import 'package:shared/shared.dart';
import 'package:test/test.dart';

/// Pasa [json] por texto, como llega de la API.
Map<String, dynamic> _comoLlega(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

const _credencial = {
  'id': '11111111-1111-4111-8111-111111111111',
  'tipo': 'tag_propio',
  'estado': 'activa',
  'terminacion': 'C8B7',
  'vigencia': '2027-01-31T06:00:00.000Z',
};

const _resumen = {
  'id': '22222222-2222-4222-8222-222222222222',
  'tipo': 'moto',
  'placa': 'A1B2C',
  'marca': 'Italika',
  'modelo': 'FT150',
  'color': 'Rojo',
  'estado': 'activo',
  'foto_id': '33333333-3333-4333-8333-333333333333',
  'es_titular': true,
};

const _detalle = {
  ..._resumen,
  'numero_serie': null,
  'foto_placa_id': '44444444-4444-4444-8444-444444444444',
  'credenciales': [_credencial],
  'usuarios_autorizados': [
    {'nombre': 'Ana Pérez', 'es_titular': true},
    {'nombre': 'Luis Gómez', 'es_titular': false},
  ],
  'solicitud_pendiente': false,
};

const _solicitud = {
  'id': '55555555-5555-4555-8555-555555555555',
  'usuario_id': '66666666-6666-4666-8666-666666666666',
  'vehiculo_id': '22222222-2222-4222-8222-222222222222',
  'tipo': 'cambio',
  'estado': 'rechazada',
  'datos_propuestos': {
    'tipo': 'moto',
    'placa': 'A1B2C',
    'numero_serie': null,
    'marca': 'Italika',
    'modelo': 'FT150',
    'color': 'Negro',
    'foto_id': '33333333-3333-4333-8333-333333333333',
    'foto_placa_id': '44444444-4444-4444-8444-444444444444',
  },
  'comentario': 'La foto no corresponde al vehículo.',
  'creado_en': '2026-10-07T18:30:00.000Z',
  'resuelta_en': '2026-10-08T15:00:00.000Z',
};

void main() {
  group('enumeraciones', () {
    test('deNombre reconoce cada valor por su nombre en la API', () {
      for (final tipo in TipoVehiculo.values) {
        expect(TipoVehiculo.deNombre(tipo.nombre), tipo);
      }
      for (final estado in EstadoRegistro.values) {
        expect(EstadoRegistro.deNombre(estado.nombre), estado);
      }
      for (final tipo in TipoSolicitud.values) {
        expect(TipoSolicitud.deNombre(tipo.nombre), tipo);
      }
      for (final estado in EstadoSolicitud.values) {
        expect(EstadoSolicitud.deNombre(estado.nombre), estado);
      }
      for (final tipo in TipoCredencial.values) {
        expect(TipoCredencial.deNombre(tipo.nombre), tipo);
      }
      for (final estado in EstadoCredencial.values) {
        expect(EstadoCredencial.deNombre(estado.nombre), estado);
      }
    });

    test('los nombres son los de los enums de la base', () {
      expect(TipoVehiculo.values.map((v) => v.nombre), [
        'auto',
        'moto',
        'bici',
        'scooter',
      ]);
      expect(TipoCredencial.values.map((v) => v.nombre), [
        'tag_propio',
        'tag_caseta',
        'nfc',
        'qr',
      ]);
      expect(EstadoCredencial.values.map((v) => v.nombre), [
        'activa',
        'perdida',
        'revocada',
        'vencida',
      ]);
    });

    test('deNombre devuelve null con un valor desconocido', () {
      expect(TipoVehiculo.deNombre('camion'), isNull);
      expect(TipoVehiculo.deNombre(null), isNull);
      expect(TipoCredencial.deNombre('tagPropio'), isNull);
      expect(EstadoSolicitud.deNombre(3), isNull);
    });

    test('placa y foto de placa según el tipo', () {
      expect(TipoVehiculo.values.where((t) => t.exigePlaca), [
        TipoVehiculo.auto,
        TipoVehiculo.moto,
      ]);
      expect(TipoVehiculo.values.where((t) => t.exigeFotoPlaca), [
        TipoVehiculo.moto,
      ]);
    });
  });

  group('CredencialResumen', () {
    test('fromJson y toJson son inversos', () {
      final credencial = CredencialResumen.fromJson(_comoLlega(_credencial));

      expect(credencial.tipo, TipoCredencial.tagPropio);
      expect(credencial.estado, EstadoCredencial.activa);
      expect(credencial.terminacion, 'C8B7');
      expect(credencial.vigencia, DateTime.utc(2027, 1, 31, 6));
      expect(credencial.toJson(), _credencial);
    });

    test('la vigencia es opcional', () {
      final credencial = CredencialResumen.fromJson(
        _comoLlega({..._credencial, 'vigencia': null}),
      );

      expect(credencial.vigencia, isNull);
      expect(credencial.toJson()['vigencia'], isNull);
    });

    test('solo expone id, tipo, estado, terminación y vigencia', () {
      // Aunque la respuesta trajera el identificador completo o la semilla,
      // el modelo no los guarda ni los vuelve a escribir.
      final credencial = CredencialResumen.fromJson(
        _comoLlega({
          ..._credencial,
          'identificador': 'E2801190A5030064033DC8B7',
          'semilla_totp_cifrada': 'secreto',
          'semilla': 'secreto',
        }),
      );

      expect(credencial.toJson().keys, [
        'id',
        'tipo',
        'estado',
        'terminacion',
        'vigencia',
      ]);
    });

    test('terminacionDe deja los últimos 4 caracteres', () {
      expect(
        CredencialResumen.terminacionDe('E2801190A5030064033DC8B7'),
        'C8B7',
      );
      expect(CredencialResumen.terminacionDe('04A1B2C3D4E5F6'), 'E5F6');
      expect(CredencialResumen.terminacionDe('ABCD'), 'ABCD');
      expect(CredencialResumen.terminacionDe('AB'), 'AB');
      expect(CredencialResumen.terminacionDe(''), '');
    });

    test('un tipo o estado desconocido lanza FormatException', () {
      expect(
        () => CredencialResumen.fromJson(
          _comoLlega({..._credencial, 'tipo': 'huella'}),
        ),
        throwsFormatException,
      );
      expect(
        () => CredencialResumen.fromJson(
          _comoLlega({..._credencial, 'estado': 'pendiente'}),
        ),
        throwsFormatException,
      );
    });
  });

  group('UsuarioAutorizado', () {
    test('fromJson y toJson son inversos', () {
      const json = {'nombre': 'Ana Pérez', 'es_titular': true};
      final usuario = UsuarioAutorizado.fromJson(_comoLlega(json));

      expect(usuario.nombre, 'Ana Pérez');
      expect(usuario.esTitular, isTrue);
      expect(usuario.toJson(), json);
    });

    test('sin nombre lanza FormatException', () {
      expect(
        () => UsuarioAutorizado.fromJson(const {'es_titular': false}),
        throwsFormatException,
      );
    });
  });

  group('VehiculoResumen', () {
    test('fromJson y toJson son inversos', () {
      final vehiculo = VehiculoResumen.fromJson(_comoLlega(_resumen));

      expect(vehiculo.tipo, TipoVehiculo.moto);
      expect(vehiculo.estado, EstadoRegistro.activo);
      expect(vehiculo.placa, 'A1B2C');
      expect(vehiculo.esTitular, isTrue);
      expect(vehiculo.toJson(), _resumen);
    });

    test('placa y foto pueden venir en null', () {
      final json = {
        ..._resumen,
        'tipo': 'bici',
        'placa': null,
        'foto_id': null,
      };
      final vehiculo = VehiculoResumen.fromJson(_comoLlega(json));

      expect(vehiculo.placa, isNull);
      expect(vehiculo.fotoId, isNull);
      expect(vehiculo.toJson(), json);
    });

    test('un tipo desconocido lanza FormatException', () {
      expect(
        () => VehiculoResumen.fromJson(
          _comoLlega({..._resumen, 'tipo': 'camion'}),
        ),
        throwsFormatException,
      );
    });
  });

  group('VehiculoDetalle', () {
    test('fromJson y toJson son inversos', () {
      final vehiculo = VehiculoDetalle.fromJson(_comoLlega(_detalle));

      expect(vehiculo.id, _resumen['id']);
      expect(vehiculo.fotoPlacaId, _detalle['foto_placa_id']);
      expect(vehiculo.numeroSerie, isNull);
      expect(vehiculo.credenciales.single.terminacion, 'C8B7');
      expect(vehiculo.usuariosAutorizados.map((u) => u.nombre), [
        'Ana Pérez',
        'Luis Gómez',
      ]);
      expect(vehiculo.usuariosAutorizados.first.esTitular, isTrue);
      expect(vehiculo.solicitudPendiente, isFalse);
      expect(vehiculo.toJson(), _detalle);
    });

    test('sin credenciales ni otros usuarios', () {
      final vehiculo = VehiculoDetalle.fromJson(
        _comoLlega({
          ..._detalle,
          'credenciales': <Object>[],
          'solicitud_pendiente': true,
        }),
      );

      expect(vehiculo.credenciales, isEmpty);
      expect(vehiculo.solicitudPendiente, isTrue);
    });

    test('sin la lista de credenciales lanza FormatException', () {
      expect(
        () => VehiculoDetalle.fromJson(_comoLlega(_resumen)),
        throwsFormatException,
      );
    });
  });

  group('Solicitud', () {
    test('fromJson y toJson son inversos', () {
      final solicitud = Solicitud.fromJson(_comoLlega(_solicitud));

      expect(solicitud.tipo, TipoSolicitud.cambio);
      expect(solicitud.estado, EstadoSolicitud.rechazada);
      expect(solicitud.comentario, 'La foto no corresponde al vehículo.');
      expect(solicitud.creadoEn, DateTime.utc(2026, 10, 7, 18, 30));
      expect(solicitud.resueltaEn, DateTime.utc(2026, 10, 8, 15));
      expect(solicitud.datosPropuestos!.color, 'Negro');
      expect(solicitud.toJson(), _solicitud);
    });

    test('una baja pendiente no trae datos, comentario ni resolución', () {
      final json = {
        ..._solicitud,
        'tipo': 'baja',
        'estado': 'pendiente',
        'datos_propuestos': null,
        'comentario': null,
        'resuelta_en': null,
      };
      final solicitud = Solicitud.fromJson(_comoLlega(json));

      expect(solicitud.datosPropuestos, isNull);
      expect(solicitud.comentario, isNull);
      expect(solicitud.resueltaEn, isNull);
      expect(solicitud.toJson(), json);
    });

    test('las fechas se escriben en UTC', () {
      final solicitud = Solicitud.fromJson(
        _comoLlega({..._solicitud, 'creado_en': '2026-10-07T12:30:00-06:00'}),
      );

      expect(solicitud.toJson()['creado_en'], '2026-10-07T18:30:00.000Z');
    });

    test('sin fecha de creación o con un estado raro lanza', () {
      expect(
        () =>
            Solicitud.fromJson(_comoLlega({..._solicitud, 'creado_en': null})),
        throwsFormatException,
      );
      expect(
        () => Solicitud.fromJson(
          _comoLlega({..._solicitud, 'estado': 'cancelada'}),
        ),
        throwsFormatException,
      );
    });
  });
}
