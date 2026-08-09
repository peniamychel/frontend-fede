/// Anotación de revisión sobre un productor. Se abre, se resuelve, y se puede
/// reabrir si el problema vuelve.
class Observacion {
  const Observacion({
    required this.id,
    required this.mensaje,
    required this.resuelta,
    required this.resueltaEn,
    required this.productorId,
  });

  final int id;
  final String mensaje;
  final bool resuelta;
  final DateTime? resueltaEn;
  final int productorId;

  bool get pendiente => !resuelta;

  factory Observacion.desdeJson(Map<String, dynamic> json) => Observacion(
        id: (json['id'] as num?)?.toInt() ?? 0,
        mensaje: json['mensaje'] as String? ?? '',
        resuelta: json['resuelta'] as bool? ?? false,
        resueltaEn: switch (json['resueltaEn']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is Observacion && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ObservacionRequest {
  const ObservacionRequest({required this.mensaje, required this.productorId});

  final String mensaje;
  final int productorId;

  Map<String, dynamic> aJson() => {
        'mensaje': mensaje,
        'productorId': productorId,
      };
}
