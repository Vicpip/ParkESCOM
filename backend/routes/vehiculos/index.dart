import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:backend/vehiculos/servicio_vehiculos.dart';
import 'package:dart_frog/dart_frog.dart';

/// `GET /vehiculos`: vehículos del usuario que no están de baja. `?tipo=`
/// filtra por tipo y `?q=` busca en la placa o en la marca.
Future<Response> onRequest(RequestContext context) =>
    protegida(context, _manejar);

Future<Response> _manejar(RequestContext context) async {
  exigirMetodo(context, HttpMethod.get);
  final filtros = context.request.uri.queryParameters;
  final vehiculos = await context.read<ServicioVehiculos>().listar(
    context.read<UsuarioAutenticado>().id,
    tipo: filtros['tipo'],
    q: filtros['q'],
  );
  return Response.json(
    body: {
      'vehiculos': [for (final vehiculo in vehiculos) vehiculo.toJson()],
    },
  );
}
