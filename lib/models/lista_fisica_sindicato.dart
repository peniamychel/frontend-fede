class ListaFisicaSindicato {
  const ListaFisicaSindicato({
    required this.sindicatoId,
    required this.sindicato,
    required this.paginas,
    required this.detallePaginas,
    this.pdfUrl,
    this.actualizadaEn,
  });

  final int sindicatoId;
  final String sindicato;
  final int paginas;
  final String? pdfUrl;
  final DateTime? actualizadaEn;
  final List<PaginaListaFisica> detallePaginas;

  bool get tienePaginas => detallePaginas.isNotEmpty;

  factory ListaFisicaSindicato.desdeJson(Map<String, dynamic> json) {
    final detalle = json['detallePaginas'];
    return ListaFisicaSindicato(
      sindicatoId: (json['sindicatoId'] as num?)?.toInt() ?? 0,
      sindicato: json['sindicato'] as String? ?? '',
      paginas: (json['paginas'] as num?)?.toInt() ?? 0,
      pdfUrl: json['pdfUrl'] as String?,
      actualizadaEn: switch (json['actualizadaEn']) {
        final String valor => DateTime.tryParse(valor),
        _ => null,
      },
      detallePaginas: detalle is List
          ? detalle
                .whereType<Map<String, dynamic>>()
                .map(PaginaListaFisica.desdeJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class PaginaListaFisica {
  const PaginaListaFisica({
    required this.id,
    required this.orden,
    required this.nombre,
    required this.tipoMime,
    required this.tamanoBytes,
    required this.url,
  });

  final int id;
  final int orden;
  final String nombre;
  final String tipoMime;
  final int tamanoBytes;
  final String url;

  factory PaginaListaFisica.desdeJson(Map<String, dynamic> json) =>
      PaginaListaFisica(
        id: (json['id'] as num?)?.toInt() ?? 0,
        orden: (json['orden'] as num?)?.toInt() ?? 0,
        nombre: json['nombre'] as String? ?? 'página',
        tipoMime: json['tipoMime'] as String? ?? 'image/jpeg',
        tamanoBytes: (json['tamanoBytes'] as num?)?.toInt() ?? 0,
        url: json['url'] as String? ?? '',
      );
}
