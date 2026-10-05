import 'package:backend/auth/passwords.dart';
import 'package:postgres/postgres.dart';

/// Cuenta de demostración: correo, nombre, boleta o número de empleado y rol.
typedef UsuarioDemo = ({
  String correo,
  String nombre,
  String boletaOEmpleado,
  String rol,
});

/// Cuentas ficticias para desarrollo y para la demo.
const usuariosDemo = <UsuarioDemo>[
  (
    correo: 'demo.admin@ipn.mx',
    nombre: 'Admin de demostración',
    boletaOEmpleado: '900001',
    rol: 'admin',
  ),
  (
    correo: 'demo.guardia@ipn.mx',
    nombre: 'Guardia de demostración',
    boletaOEmpleado: '900002',
    rol: 'guardia',
  ),
  (
    correo: 'demo.usuario1@alumno.ipn.mx',
    nombre: 'Usuario Uno de demostración',
    boletaOEmpleado: '2026630001',
    rol: 'usuario',
  ),
  (
    correo: 'demo.usuario2@alumno.ipn.mx',
    nombre: 'Usuario Dos de demostración',
    boletaOEmpleado: '2026630002',
    rol: 'usuario',
  ),
];

/// Crea las cuentas de [usuariosDemo] que falten, activas y con [password].
///
/// Es idempotente: una cuenta que ya existe no se toca (tampoco su
/// contraseña). Devuelve los correos que creó en esta corrida.
Future<List<String>> sembrarUsuariosDemo(
  Session db, {
  required String password,
  int costo = 12,
}) async {
  final creados = <String>[];
  for (final demo in usuariosDemo) {
    final existe = await db.execute(
      Sql.named('SELECT 1 FROM usuarios WHERE correo = @correo'),
      parameters: {'correo': demo.correo},
    );
    if (existe.isNotEmpty) continue;
    await db.execute(
      Sql.named(
        'INSERT INTO usuarios '
        '(correo, hash_password, nombre, boleta_o_empleado, rol, estado) '
        'VALUES (@correo, @hash, @nombre, @boleta, '
        "CAST(@rol:text AS rol_usuario), 'activo')",
      ),
      parameters: {
        'correo': demo.correo,
        'hash': await hashearPassword(password, costo: costo),
        'nombre': demo.nombre,
        'boleta': demo.boletaOEmpleado,
        'rol': demo.rol,
      },
    );
    creados.add(demo.correo);
  }
  return creados;
}
