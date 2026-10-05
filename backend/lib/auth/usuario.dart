import 'package:postgres/postgres.dart';

/// Rol de una cuenta; corresponde al enum `rol_usuario` de la base.
enum Rol {
  /// Dueño o conductor de vehículos.
  usuario,

  /// Opera la caseta.
  guardia,

  /// Administración.
  admin;

  /// Rol con ese [nombre], o `null` si no existe.
  static Rol? deNombre(Object? nombre) {
    for (final rol in values) {
      if (rol.name == nombre) return rol;
    }
    return null;
  }
}

/// Identidad que el middleware de autenticación saca del JWT de acceso.
class UsuarioAutenticado {
  /// Crea la identidad con el [id] (claim `sub`) y el [rol] del token.
  const UsuarioAutenticado({required this.id, required this.rol});

  /// UUID del usuario.
  final String id;

  /// Rol que tenía el usuario cuando se emitió el token.
  final Rol rol;
}

/// Datos básicos de una cuenta, sin el hash de la contraseña.
class Usuario {
  /// Crea el usuario con sus datos públicos.
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.boletaOEmpleado,
    required this.rol,
    required this.estado,
    this.fotoTitularId,
    this.fotoCredencialId,
  });

  /// Lee un usuario de una fila que empieza con [columnas].
  factory Usuario.deFila(ResultRow fila) => Usuario(
    id: fila[0]! as String,
    nombre: fila[1]! as String,
    correo: fila[2]! as String,
    boletaOEmpleado: fila[3]! as String,
    rol: Rol.deNombre(fila[4])!,
    estado: fila[5]! as String,
    fotoTitularId: fila[6] as String?,
    fotoCredencialId: fila[7] as String?,
  );

  /// Columnas de `usuarios` que lee [Usuario.deFila], en ese orden.
  static const columnas =
      'id::text, nombre, correo, boleta_o_empleado, rol::text, estado::text, '
      'foto_titular_id::text, foto_credencial_id::text';

  /// Posición de la primera columna que siga a [columnas] en un `SELECT`.
  static const columnasLeidas = 8;

  /// UUID del usuario.
  final String id;

  /// Nombre completo.
  final String nombre;

  /// Correo institucional, en minúsculas.
  final String correo;

  /// Boleta o número de empleado.
  final String boletaOEmpleado;

  /// Rol de la cuenta.
  final Rol rol;

  /// `pendiente`, `activo` o `baja`.
  final String estado;

  /// Id del archivo con la foto del titular, si ya la subió.
  final String? fotoTitularId;

  /// Id del archivo con la foto de su credencial escolar o de empleado.
  final String? fotoCredencialId;

  /// Representación que devuelve la API.
  Map<String, Object?> toJson() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'boleta_o_empleado': boletaOEmpleado,
    'rol': rol.name,
    'estado': estado,
    'foto_titular_id': fotoTitularId,
    'foto_credencial_id': fotoCredencialId,
  };
}
