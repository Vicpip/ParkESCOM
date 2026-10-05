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
  });

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

  /// Representación que devuelve la API.
  Map<String, Object?> toJson() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'boleta_o_empleado': boletaOEmpleado,
    'rol': rol.name,
    'estado': estado,
  };
}
