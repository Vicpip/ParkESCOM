import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:backend/vehiculos/servicio_vehiculos.dart';
import 'package:dart_frog/dart_frog.dart';

/// `GET /vehiculos/{id}`: datos, fotos, credenciales, usuarios autorizados y
/// si hay una solicitud pendiente. 404 si el vehículo no es del usuario.
Future<Response> onRequest(RequestContext context, String id) =>
    protegida(context, (context) async {
      exigirMetodo(context, HttpMethod.get);
      final vehiculo = await context.read<ServicioVehiculos>().obtener(
        context.read<UsuarioAutenticado>().id,
        id,
      );
      return Response.json(body: {'vehiculo': vehiculo.toJson()});
    });
