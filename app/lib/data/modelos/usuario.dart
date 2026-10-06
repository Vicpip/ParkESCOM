/// Rol de una cuenta.
enum Rol { usuario, guardia, admin }

/// Estado de una cuenta.
enum EstadoCuenta { pendiente, activo, baja }

/// Cuenta con la sesión abierta, tal como la devuelve la API en `usuario`.
class Usuario {
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

  /// Lee el objeto `usuario` de una respuesta. Lanza si le falta un campo o
  /// trae un rol o estado desconocido.
  factory Usuario.deJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    correo: json['correo'] as String,
    boletaOEmpleado: json['boleta_o_empleado'] as String,
    rol: Rol.values.byName(json['rol'] as String),
    estado: EstadoCuenta.values.byName(json['estado'] as String),
    fotoTitularId: json['foto_titular_id'] as String?,
    fotoCredencialId: json['foto_credencial_id'] as String?,
  );

  final String id;
  final String nombre;
  final String correo;
  final String boletaOEmpleado;
  final Rol rol;
  final EstadoCuenta estado;

  /// Id del archivo con la foto del titular, si ya la subió.
  final String? fotoTitularId;

  /// Id del archivo con la foto de su credencial escolar o de empleado.
  final String? fotoCredencialId;

  /// Administración todavía no activa la cuenta.
  bool get estaPendiente => estado == EstadoCuenta.pendiente;

  /// Le falta la foto del titular o la de su credencial.
  bool get faltanFotos => fotoTitularId == null || fotoCredencialId == null;

  /// Cuenta de usuario que se quedó a medio registro: ya existe, pero aún
  /// debe subir sus fotos (solo se puede mientras está pendiente).
  bool get debeCompletarRegistro =>
      rol == Rol.usuario && estaPendiente && faltanFotos;
}
