/// Una página del `PagedModel` de Spring: el contenido más sus metadatos.
///
/// El backend la serializa como `{content: [...], page: {size, number,
/// totalElements, totalPages}}`.
class Pagina<T> {
  const Pagina({
    required this.contenido,
    required this.tamano,
    required this.numero,
    required this.totalElementos,
    required this.totalPaginas,
  });

  final List<T> contenido;
  final int tamano;

  /// Índice de página, empezando en cero — igual que en Spring.
  final int numero;

  final int totalElementos;
  final int totalPaginas;

  /// El tamaño que usa el backend cuando no se le manda ninguno
  /// (`@PageableDefault(size = 25)`).
  static const int tamanoPorDefecto = 25;

  bool get esUltima => numero + 1 >= totalPaginas;
  bool get estaVacia => contenido.isEmpty;
  bool get hayMas => !esUltima;

  factory Pagina.desdeJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) mapear,
  ) {
    final meta = json['page'];
    final metadatos = meta is Map ? meta : const {};
    final crudo = json['content'];

    return Pagina<T>(
      contenido: crudo is List
          ? crudo
              .whereType<Map<String, dynamic>>()
              .map(mapear)
              .toList(growable: false)
          : const [],
      tamano: (metadatos['size'] as num?)?.toInt() ?? 0,
      numero: (metadatos['number'] as num?)?.toInt() ?? 0,
      totalElementos: (metadatos['totalElements'] as num?)?.toInt() ?? 0,
      totalPaginas: (metadatos['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  /// Página vacía, para inicializar estado antes de la primera carga.
  static Pagina<T> vacia<T>() => Pagina<T>(
        contenido: const [],
        tamano: tamanoPorDefecto,
        numero: 0,
        totalElementos: 0,
        totalPaginas: 0,
      );

  /// Une esta página con la siguiente, para listas de scroll infinito.
  Pagina<T> mas(Pagina<T> siguiente) => Pagina<T>(
        contenido: [...contenido, ...siguiente.contenido],
        tamano: siguiente.tamano,
        numero: siguiente.numero,
        totalElementos: siguiente.totalElementos,
        totalPaginas: siguiente.totalPaginas,
      );
}

/// Los parámetros de paginación tal como viajan por la URL.
///
/// Ojo: el spec de OpenAPI declara `pageable` como un objeto requerido, pero
/// eso es un artefacto de springdoc. Por el cable van sueltos:
/// `?page=0&size=25&sort=apellidos,asc`.
class Paginacion {
  const Paginacion({
    this.pagina = 0,
    this.tamano = Pagina.tamanoPorDefecto,
    this.orden = const [],
  });

  final int pagina;
  final int tamano;

  /// Cada entrada es `campo` o `campo,asc` / `campo,desc`.
  final List<String> orden;

  Paginacion siguiente() => Paginacion(
        pagina: pagina + 1,
        tamano: tamano,
        orden: orden,
      );

  Map<String, dynamic> get query => {
        'page': pagina,
        'size': tamano,
        if (orden.isNotEmpty) 'sort': orden,
      };
}
