class Usuario {
  final String id;
  final String empresaId;
  final String email;
  final String nombre;
  final String? apellidos;
  final String? dni;
  final String rol;
  final bool activo;
  final DateTime fechaCreacion;

  Usuario({
    required this.id,
    required this.empresaId,
    required this.email,
    required this.nombre,
    this.apellidos,
    this.dni,
    required this.rol,
    required this.activo,
    required this.fechaCreacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      empresaId: json['empresa_id'],
      email: json['email'],
      nombre: json['nombre'],
      apellidos: json['apellidos'],
      dni: json['dni'],
      rol: json['rol'],
      activo: json['activo'] ?? true,
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresa_id': empresaId,
      'email': email,
      'nombre': nombre,
      'apellidos': apellidos,
      'dni': dni,
      'rol': rol,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }
}
