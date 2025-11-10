class Empresa {
  final String id;
  final String nombre;
  final String nombreAdmin;
  final String emailAdmin;
  final int maxEmpleados;
  final DateTime fechaCreacion;

  Empresa({
    required this.id,
    required this.nombre,
    required this.nombreAdmin,
    required this.emailAdmin,
    required this.maxEmpleados,
    required this.fechaCreacion,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      id: json['id'],
      nombre: json['nombre'],
      nombreAdmin: json['nombre_admin'],
      emailAdmin: json['email_admin'],
      maxEmpleados: json['max_empleados'],
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'nombre_admin': nombreAdmin,
      'email_admin': emailAdmin,
      'max_empleados': maxEmpleados,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }
}
