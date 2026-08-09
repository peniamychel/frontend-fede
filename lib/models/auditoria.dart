/// Control de una fila: si está habilitada y cuándo se tocó.
///
/// Llega anidada dentro de cada respuesta, en el campo `auditoria`. El backend
/// mantiene las dos fechas solo, así que acá son de lectura.
class Auditoria {
  const Auditoria({
    required this.estado,
    this.creadoEn,
    this.editadoEn,
  });

  /// Si el registro está habilitado. Nace en true.
  final bool estado;

  final DateTime? creadoEn;
  final DateTime? editadoEn;

  /// Para las respuestas viejas o los objetos armados a mano en una prueba:
  /// sin datos de auditoría se asume habilitado, que es como nacen.
  static const Auditoria habilitado = Auditoria(estado: true);

  factory Auditoria.desdeJson(Map<String, dynamic>? json) {
    if (json == null) return habilitado;
    return Auditoria(
      estado: json['estado'] as bool? ?? true,
      creadoEn: _fecha(json['creadoEn']),
      editadoEn: _fecha(json['editadoEn']),
    );
  }

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.tryParse(valor) : null;

  /// Fecha lista para mostrar, o null si no vino.
  static String? formatear(DateTime? fecha) {
    if (fecha == null) return null;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }
}
