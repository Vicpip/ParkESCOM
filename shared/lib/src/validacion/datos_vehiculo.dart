import '../modelos/enumeraciones.dart';
import 'codigos_validacion.dart';

/// Longitud máxima de la marca, el modelo, el color y el número de serie.
const longitudMaximaDatoVehiculo = 60;

/// Longitud máxima de una placa ya normalizada.
const longitudMaximaPlaca = 15;

final _formatoPlaca = RegExp(r'^[A-Z0-9-]+$');
final _espacios = RegExp(r'\s+');

/// Deja la placa como se guarda y se compara: en mayúsculas y sin espacios.
String normalizarPlaca(String placa) =>
    placa.replaceAll(_espacios, '').toUpperCase();

/// Datos de un vehículo tal como los captura el formulario de alta o de
/// cambio, ya normalizados: textos sin espacios alrededor, placa en mayúsculas
/// y sin espacios, y los opcionales vacíos como `null`.
///
/// Son los `datos` de una solicitud de alta o de cambio y lo que queda
/// guardado en sus datos propuestos. [validar] dice qué campos están mal.
class DatosVehiculo {
  /// Normaliza y guarda los datos capturados.
  factory DatosVehiculo({
    required String tipo,
    required String marca,
    required String modelo,
    required String color,
    String? placa,
    String? numeroSerie,
    String? fotoId,
    String? fotoPlacaId,
  }) => DatosVehiculo._(
    tipo: tipo.trim(),
    placa: _opcional(normalizarPlaca(placa ?? '')),
    numeroSerie: _opcional(numeroSerie),
    marca: marca.trim(),
    modelo: modelo.trim(),
    color: color.trim(),
    fotoId: _opcional(fotoId),
    fotoPlacaId: _opcional(fotoPlacaId),
  );

  /// Lee los datos de un objeto JSON. Un campo ausente o que no es texto se
  /// toma como vacío, para que [validar] lo reporte con su código.
  factory DatosVehiculo.fromJson(Map<String, dynamic> json) => DatosVehiculo(
    tipo: _texto(json['tipo']) ?? '',
    placa: _texto(json['placa']),
    numeroSerie: _texto(json['numero_serie']),
    marca: _texto(json['marca']) ?? '',
    modelo: _texto(json['modelo']) ?? '',
    color: _texto(json['color']) ?? '',
    fotoId: _texto(json['foto_id']),
    fotoPlacaId: _texto(json['foto_placa_id']),
  );

  const DatosVehiculo._({
    required this.tipo,
    required this.placa,
    required this.numeroSerie,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.fotoId,
    required this.fotoPlacaId,
  });

  /// Tipo tal como llegó (`auto`, `moto`, `bici` o `scooter` si es válido).
  final String tipo;

  /// Placa en mayúsculas y sin espacios, o `null` si no se capturó.
  final String? placa;

  /// Número de serie, o `null` si no se capturó.
  final String? numeroSerie;

  /// Marca.
  final String marca;

  /// Modelo.
  final String modelo;

  /// Color.
  final String color;

  /// Id del archivo con la foto del vehículo.
  final String? fotoId;

  /// Id del archivo con la foto de la placa (obligatoria en motos).
  final String? fotoPlacaId;

  /// [tipo] como enum, o `null` si no es un tipo válido.
  TipoVehiculo? get tipoVehiculo => TipoVehiculo.deNombre(tipo);

  /// Revisa los datos y devuelve, por cada campo con error (con su nombre en
  /// la API: `tipo`, `placa`, `numero_serie`, `marca`, `modelo`, `color`,
  /// `foto_id`, `foto_placa_id`), su [CodigoValidacion]. Vacío si todo está
  /// bien.
  ///
  /// La placa es obligatoria en autos y motos; la foto de la placa, solo en
  /// motos. De las fotos solo se revisa que vengan: que existan y sean del
  /// usuario lo decide la API.
  Map<String, String> validar() {
    final tipoVehiculo = this.tipoVehiculo;
    final placa = this.placa;
    final numeroSerie = this.numeroSerie;

    String? errorPlaca;
    if (placa == null) {
      if (tipoVehiculo?.exigePlaca ?? false) {
        errorPlaca = CodigoValidacion.placaRequerida;
      }
    } else if (placa.length > longitudMaximaPlaca ||
        !_formatoPlaca.hasMatch(placa)) {
      errorPlaca = CodigoValidacion.placaInvalida;
    }

    return {
      if (tipoVehiculo == null) 'tipo': CodigoValidacion.tipoVehiculoInvalido,
      'placa': ?errorPlaca,
      if (numeroSerie != null && _muyLargo(numeroSerie))
        'numero_serie': CodigoValidacion.numeroSerieMuyLargo,
      'marca': ?_validarTexto(
        marca,
        vacio: CodigoValidacion.marcaVacia,
        muyLargo: CodigoValidacion.marcaMuyLarga,
      ),
      'modelo': ?_validarTexto(
        modelo,
        vacio: CodigoValidacion.modeloVacio,
        muyLargo: CodigoValidacion.modeloMuyLargo,
      ),
      'color': ?_validarTexto(
        color,
        vacio: CodigoValidacion.colorVacio,
        muyLargo: CodigoValidacion.colorMuyLargo,
      ),
      if (fotoId == null) 'foto_id': CodigoValidacion.fotoVehiculoRequerida,
      if (fotoPlacaId == null && (tipoVehiculo?.exigeFotoPlaca ?? false))
        'foto_placa_id': CodigoValidacion.fotoPlacaRequerida,
    };
  }

  /// Representación en la API y en los datos propuestos de una solicitud.
  Map<String, Object?> toJson() => {
    'tipo': tipo,
    'placa': placa,
    'numero_serie': numeroSerie,
    'marca': marca,
    'modelo': modelo,
    'color': color,
    'foto_id': fotoId,
    'foto_placa_id': fotoPlacaId,
  };
}

String? _texto(Object? valor) => valor is String ? valor : null;

String? _opcional(String? valor) {
  final limpio = valor?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

bool _muyLargo(String valor) => valor.runes.length > longitudMaximaDatoVehiculo;

String? _validarTexto(
  String valor, {
  required String vacio,
  required String muyLargo,
}) {
  if (valor.isEmpty) return vacio;
  if (_muyLargo(valor)) return muyLargo;
  return null;
}
