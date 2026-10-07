import 'dart:io';

import 'package:backend/archivos/servicio_archivos.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/http/error_api.dart';
import 'package:postgres/postgres.dart';
import 'package:shared/shared.dart';

/// Consulta de los vehículos de un usuario: los que tiene autorizados (como
/// titular o no) y que no están de baja.
///
/// Sus métodos lanzan [ErrorApi] con el código que la API debe responder.
class ServicioVehiculos {
  /// Crea el servicio sobre el [pool] de la base.
  ServicioVehiculos({required PoolDb pool}) : _pool = pool;

  final PoolDb _pool;

  /// 404: el vehículo no existe, está de baja o no es del usuario. Es el
  /// mismo error en los tres casos, para no revelar vehículos ajenos.
  static const noEncontrado = ErrorApi(
    HttpStatus.notFound,
    'VEHICULO_NO_ENCONTRADO',
    'El vehículo no existe.',
  );

  /// Columnas que lee [_resumen], en ese orden; las dos últimas solo las usa
  /// el detalle.
  static const _columnas =
      'v.id::text, v.tipo::text, v.placa, v.marca, v.modelo, v.color, '
      'v.estado::text, v.foto_id::text, vu.es_titular, v.numero_serie, '
      'v.foto_placa_id::text';

  /// Vehículos del usuario con autorización activa y que no están de baja.
  static const _delUsuario =
      'FROM vehiculos v '
      'JOIN vehiculo_usuarios vu ON vu.vehiculo_id = v.id '
      'WHERE vu.usuario_id = @usuario:uuid AND vu.activo '
      "AND v.estado <> 'baja'";

  static final _comodines = RegExp(r'[\\%_]');
  static final _espacios = RegExp(r'\s+');

  /// Vehículos del usuario, del más reciente al más antiguo. [tipo] deja solo
  /// los de ese tipo y [q] busca un fragmento en la placa o en la marca, sin
  /// distinguir mayúsculas.
  ///
  /// Errores: `VALIDACION` (`tipo`: `TIPO_VEHICULO_INVALIDO`).
  Future<List<VehiculoResumen>> listar(
    String usuarioId, {
    String? tipo,
    String? q,
  }) async {
    final condiciones = <String>[];
    final parametros = <String, Object?>{'usuario': usuarioId};

    if (tipo != null && tipo.isNotEmpty) {
      final tipoVehiculo = TipoVehiculo.deNombre(tipo);
      if (tipoVehiculo == null) {
        throw const ErrorApi.validacion({
          'tipo': CodigoValidacion.tipoVehiculoInvalido,
        });
      }
      condiciones.add('v.tipo = CAST(@tipo:text AS tipo_vehiculo)');
      parametros['tipo'] = tipoVehiculo.nombre;
    }

    final busqueda = q?.trim() ?? '';
    if (busqueda.isNotEmpty) {
      // Los comodines de LIKE que escriba el usuario se buscan tal cual.
      final literal = busqueda.replaceAllMapped(
        _comodines,
        (comodin) => '\\${comodin[0]}',
      );
      // La placa se guarda sin espacios: "abc 123" debe encontrar ABC123.
      condiciones.add('(v.placa ILIKE @placa OR v.marca ILIKE @marca)');
      parametros['placa'] = '%${literal.replaceAll(_espacios, '')}%';
      parametros['marca'] = '%$literal%';
    }

    final filtro = condiciones.map((condicion) => ' AND $condicion').join();
    final filas = await _pool.execute(
      Sql.named(
        'SELECT $_columnas $_delUsuario$filtro ORDER BY v.creado_en DESC, v.id',
      ),
      parameters: parametros,
    );
    return filas.map(_resumen).toList();
  }

  /// Detalle del vehículo [id]: datos, fotos, credenciales, usuarios
  /// autorizados y si tiene una solicitud pendiente.
  ///
  /// El titular ve todas las credenciales del vehículo; un usuario autorizado
  /// ve los tags y calcomanías, y solo su propio QR.
  ///
  /// Errores: `VEHICULO_NO_ENCONTRADO`.
  Future<VehiculoDetalle> obtener(String usuarioId, String id) async {
    if (!esUuid(id)) throw noEncontrado;
    return _pool.run((db) async {
      final filas = await db.execute(
        Sql.named(
          'SELECT $_columnas, EXISTS (SELECT 1 FROM solicitudes s '
          "WHERE s.vehiculo_id = v.id AND s.estado = 'pendiente') "
          '$_delUsuario AND v.id = @id:uuid',
        ),
        parameters: {'usuario': usuarioId, 'id': id},
      );
      final fila = filas.firstOrNull;
      if (fila == null) throw noEncontrado;
      final resumen = _resumen(fila);

      // La semilla del QR no se consulta: de la credencial solo salen el
      // tipo, el estado, la vigencia y el final del identificador.
      final credenciales = await db.execute(
        Sql.named(
          'SELECT id::text, tipo::text, estado::text, identificador, vigencia '
          'FROM credenciales WHERE vehiculo_id = @id:uuid '
          "AND (@esTitular:boolean OR tipo <> 'qr' "
          'OR usuario_id = @usuario:uuid) '
          'ORDER BY creado_en, id',
        ),
        parameters: {
          'id': id,
          'usuario': usuarioId,
          'esTitular': resumen.esTitular,
        },
      );
      final autorizados = await db.execute(
        Sql.named(
          'SELECT u.nombre, vu.es_titular FROM vehiculo_usuarios vu '
          'JOIN usuarios u ON u.id = vu.usuario_id '
          'WHERE vu.vehiculo_id = @id:uuid AND vu.activo '
          'ORDER BY vu.es_titular DESC, u.nombre',
        ),
        parameters: {'id': id},
      );

      return VehiculoDetalle(
        id: resumen.id,
        tipo: resumen.tipo,
        placa: resumen.placa,
        marca: resumen.marca,
        modelo: resumen.modelo,
        color: resumen.color,
        estado: resumen.estado,
        fotoId: resumen.fotoId,
        esTitular: resumen.esTitular,
        numeroSerie: fila[9] as String?,
        fotoPlacaId: fila[10] as String?,
        solicitudPendiente: fila[11]! as bool,
        credenciales: [
          for (final credencial in credenciales)
            CredencialResumen(
              id: credencial[0]! as String,
              tipo: TipoCredencial.deNombre(credencial[1])!,
              estado: EstadoCredencial.deNombre(credencial[2])!,
              terminacion: CredencialResumen.terminacionDe(
                credencial[3]! as String,
              ),
              vigencia: credencial[4] as DateTime?,
            ),
        ],
        usuariosAutorizados: [
          for (final autorizado in autorizados)
            UsuarioAutorizado(
              nombre: autorizado[0]! as String,
              esTitular: autorizado[1]! as bool,
            ),
        ],
      );
    });
  }

  static VehiculoResumen _resumen(ResultRow fila) => VehiculoResumen(
    id: fila[0]! as String,
    tipo: TipoVehiculo.deNombre(fila[1])!,
    placa: fila[2] as String?,
    marca: fila[3] as String? ?? '',
    modelo: fila[4] as String? ?? '',
    color: fila[5] as String? ?? '',
    estado: EstadoRegistro.deNombre(fila[6])!,
    fotoId: fila[7] as String?,
    esTitular: fila[8]! as bool,
  );
}
