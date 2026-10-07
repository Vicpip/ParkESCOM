import 'package:backend/auth/usuario.dart';
import 'package:backend/credenciales/servicio_credenciales.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /credenciales/{id}/reportar-perdida`: el titular del vehículo (o el
/// dueño del QR) marca la credencial como perdida. 409 si ya no está activa.
Future<Response> onRequest(RequestContext context, String id) =>
    protegida(context, (context) async {
      exigirMetodo(context, HttpMethod.post);
      final credencial = await context
          .read<ServicioCredenciales>()
          .reportarPerdida(context.read<UsuarioAutenticado>().id, id);
      return Response.json(body: {'credencial': credencial.toJson()});
    });
