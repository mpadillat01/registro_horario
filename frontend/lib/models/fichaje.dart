class Fichaje {
  final String id;
  final String usuarioId;
  final String empresaId;
  final String tipo;
  final DateTime fechaHora;
  final DateTime fechaCreacion;

  Fichaje({
    required this.id,
    required this.usuarioId,
    required this.empresaId,
    required this.tipo,
    required this.fechaHora,
    required this.fechaCreacion,
  });

  factory Fichaje.fromJson(Map<String, dynamic> json) {
    return Fichaje(
      id: json['id'],
      usuarioId: json['usuario_id'],
      empresaId: json['empresa_id'],
      tipo: json['tipo'],
      fechaHora: DateTime.parse(json['fecha_hora']),
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'empresa_id': empresaId,
      'tipo': tipo,
      'fecha_hora': fechaHora.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }
}
