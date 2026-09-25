/// Ficha retirada del padrón, conservada para una posible restauración.
class ProductorPapelera {
  const ProductorPapelera({
    required this.id,
    required this.nombre,
    required this.sindicato,
    required this.central,
    required this.eliminadoEn,
    required this.restaurable,
    this.ci,
    this.impedimento,
  });

  final int id;
  final String nombre;
  final String? ci;
  final String sindicato;
  final String central;
  final DateTime eliminadoEn;
  final bool restaurable;
  final String? impedimento;

  factory ProductorPapelera.desdeJson(Map<String, dynamic> json) =>
      ProductorPapelera(
        id: (json['id'] as num).toInt(),
        nombre: json['nombre'] as String? ?? '',
        ci: json['ci'] as String?,
        sindicato: json['sindicato'] as String? ?? '',
        central: json['central'] as String? ?? '',
        eliminadoEn: DateTime.parse(json['eliminadoEn'] as String),
        restaurable: json['restaurable'] as bool? ?? false,
        impedimento: json['impedimento'] as String?,
      );
}
