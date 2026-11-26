/// Un cambio de estado registrado en el historial (RF-030), tal como lo
/// entrega GET /api/seguimiento/historial/{id} (RF-031).
class CambioEstado {
  final String? estadoAnterior;
  final String estadoNuevo;
  final DateTime fechaHora;
  final String usuario;
  final String? justificacion;

  const CambioEstado({
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.fechaHora,
    required this.usuario,
    this.justificacion,
  });

  factory CambioEstado.fromJson(Map<String, dynamic> j) => CambioEstado(
        estadoAnterior: j['estado_anterior'] as String?,
        estadoNuevo: j['estado_nuevo'] as String,
        fechaHora: DateTime.parse(j['fecha_hora'] as String),
        usuario: (j['usuario'] as String?) ?? 'Desconocido',
        justificacion: j['justificacion'] as String?,
      );
}
