class Invitacion {
  final String id;
  final String empresaId;
  final String email;
  final String token;
  final bool usada;
  final DateTime fechaCreacion;

  Invitacion({
    required this.id,
    required this.empresaId,
    required this.email,
    required this.token,
    required this.usada,
    required this.fechaCreacion,
  });

  factory Invitacion.fromJson(Map<String, dynamic> json) {
    return Invitacion(
      id: json['id'],
      empresaId: json['empresa_id'],
      email: json['email'],
      token: json['token'],
      usada: json['usada'] ?? false,
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresa_id': empresaId,
      'email': email,
      'token': token,
      'usada': usada,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }
}
