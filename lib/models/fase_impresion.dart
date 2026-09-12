/// Estado de la fase que controla las impresiones físicas de una central.
class EstadoFasesImpresionCentral {
  const EstadoFasesImpresionCentral({
    required this.centralId,
    required this.central,
    required this.historial,
    this.faseActiva,
  });

  final int centralId;
  final String central;
  final FaseImpresionCarnet? faseActiva;
  final List<FaseImpresionCarnet> historial;

  int get siguienteNumero =>
      historial.fold<int>(
        0,
        (maximo, fase) => fase.numero > maximo ? fase.numero : maximo,
      ) +
      1;

  factory EstadoFasesImpresionCentral.desdeJson(Map<String, dynamic> json) =>
      EstadoFasesImpresionCentral(
        centralId: (json['centralId'] as num?)?.toInt() ?? 0,
        central: json['central'] as String? ?? '',
        faseActiva: json['faseActiva'] is Map<String, dynamic>
            ? FaseImpresionCarnet.desdeJson(
                json['faseActiva'] as Map<String, dynamic>,
              )
            : null,
        historial: ((json['historial'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FaseImpresionCarnet.desdeJson)
            .toList(growable: false),
      );
}

class FaseImpresionCarnet {
  const FaseImpresionCarnet({
    required this.id,
    required this.numero,
    required this.estado,
    required this.total,
    required this.impresos,
    required this.pendientes,
    this.abiertaEn,
    this.cerradaEn,
  });

  final int id;
  final int numero;
  final String estado;
  final DateTime? abiertaEn;
  final DateTime? cerradaEn;
  final int total;
  final int impresos;
  final int pendientes;

  bool get abierta => estado == 'ABIERTA';

  factory FaseImpresionCarnet.desdeJson(Map<String, dynamic> json) =>
      FaseImpresionCarnet(
        id: (json['id'] as num?)?.toInt() ?? 0,
        numero: (json['numero'] as num?)?.toInt() ?? 0,
        estado: json['estado'] as String? ?? '',
        abiertaEn: DateTime.tryParse(json['abiertaEn'] as String? ?? ''),
        cerradaEn: DateTime.tryParse(json['cerradaEn'] as String? ?? ''),
        total: (json['total'] as num?)?.toInt() ?? 0,
        impresos: (json['impresos'] as num?)?.toInt() ?? 0,
        pendientes: (json['pendientes'] as num?)?.toInt() ?? 0,
      );
}

String ordinalFase(int numero) => switch (numero) {
  1 => '1ra',
  2 => '2da',
  3 => '3ra',
  _ => '${numero}ta',
};
