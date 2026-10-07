import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:backend/solicitudes/servicio_solicitudes.dart';
import 'package:dart_frog/dart_frog.dart';

/// `GET /solicitudes/{id}`: una solicitud del usuario. 404 si es de otro.
Future<Response> onRequest(RequestContext context, String id) =>
    protegida(context, (context) async {
      exigirMetodo(context, HttpMethod.get);
      final solicitud = await context.read<ServicioSolicitudes>().obtener(
        context.read<UsuarioAutenticado>().id,
        id,
      );
      return Response.json(body: {'solicitud': solicitud.toJson()});
    });
