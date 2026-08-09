/// Fila de la planilla que no se pudo importar.
class ErrorFila {
  const ErrorFila({
    required this.fila,
    required this.columna,
    required this.valor,
    required this.mensaje,
  });

  /// Número tal como lo muestra Excel: con encabezado en la 1, el primer dato
  /// es la 2. Se puede ir directo a esa fila en la planilla.
  final int fila;

  /// Columna que provocó el rechazo, o null si el problema es de la fila entera.
  final String? columna;

  final String? valor;
  final String mensaje;

  factory ErrorFila.desdeJson(Map<String, dynamic> json) => ErrorFila(
        fila: (json['fila'] as num?)?.toInt() ?? 0,
        columna: json['columna'] as String?,
        valor: json['valor'] as String?,
        mensaje: json['mensaje'] as String? ?? '',
      );
}

/// Sindicato que la planilla menciona y todavía no existe.
///
/// Lleva la central porque el nombre solo no identifica a ninguno: «1RO MAYO»
/// existe en varias centrales y son sindicatos distintos.
class SindicatoNuevo {
  const SindicatoNuevo({required this.central, required this.sindicato});

  final String central;
  final String sindicato;

  factory SindicatoNuevo.desdeJson(Map<String, dynamic> json) => SindicatoNuevo(
        central: json['central'] as String? ?? '',
        sindicato: json['sindicato'] as String? ?? '',
      );
}

/// Informe de una importación, simulada o real.
///
/// El backend corre el mismo código en los dos casos —incluidos los INSERT, que
/// en la simulación se deshacen al final—, así que lo que dice la vista previa
/// es exactamente lo que haría la confirmación.
class ImportacionResultado {
  const ImportacionResultado({
    required this.simulacion,
    required this.federacionId,
    required this.federacionNombre,
    required this.filasLeidas,
    required this.filasValidas,
    required this.filasRechazadas,
    required this.productores,
    required this.lotes,
    required this.observaciones,
    required this.centralesNuevas,
    required this.sindicatosNuevos,
    required this.posiblesDuplicados,
    required this.errores,
    required this.erroresOmitidos,
    required this.duracionMs,
  });

  /// True cuando no se escribió nada. Lo devuelve así tanto la simulación como
  /// la ejecución real que se abortó por tener filas inválidas.
  final bool simulacion;

  final int federacionId;
  final String federacionNombre;
  final int filasLeidas;
  final int filasValidas;
  final int filasRechazadas;
  final int productores;
  final int lotes;
  final int observaciones;
  final List<String> centralesNuevas;
  final List<SindicatoNuevo> sindicatosNuevos;

  /// Filas cuyo nombre, apellido y sindicato ya están en la base. No es un
  /// error; suele significar que la planilla se está subiendo dos veces.
  final int posiblesDuplicados;

  final List<ErrorFila> errores;
  final int erroresOmitidos;
  final int duracionMs;

  bool get hayRechazos => filasRechazadas > 0;
  bool get tocaLaJerarquia =>
      centralesNuevas.isNotEmpty || sindicatosNuevos.isNotEmpty;
  bool get hayAlgoQueImportar => filasValidas > 0;

  factory ImportacionResultado.desdeJson(Map<String, dynamic> json) {
    List<T> lista<T>(Object? crudo, T Function(Map<String, dynamic>) mapear) =>
        crudo is List
            ? crudo.whereType<Map<String, dynamic>>().map(mapear).toList()
            : const [];

    return ImportacionResultado(
      simulacion: json['simulacion'] as bool? ?? true,
      federacionId: (json['federacionId'] as num?)?.toInt() ?? 0,
      federacionNombre: json['federacionNombre'] as String? ?? '',
      filasLeidas: (json['filasLeidas'] as num?)?.toInt() ?? 0,
      filasValidas: (json['filasValidas'] as num?)?.toInt() ?? 0,
      filasRechazadas: (json['filasRechazadas'] as num?)?.toInt() ?? 0,
      productores: (json['productores'] as num?)?.toInt() ?? 0,
      lotes: (json['lotes'] as num?)?.toInt() ?? 0,
      observaciones: (json['observaciones'] as num?)?.toInt() ?? 0,
      centralesNuevas: switch (json['centralesNuevas']) {
        final List<dynamic> l => l.map((e) => '$e').toList(growable: false),
        _ => const [],
      },
      sindicatosNuevos:
          lista(json['sindicatosNuevos'], SindicatoNuevo.desdeJson),
      posiblesDuplicados: (json['posiblesDuplicados'] as num?)?.toInt() ?? 0,
      errores: lista(json['errores'], ErrorFila.desdeJson),
      erroresOmitidos: (json['erroresOmitidos'] as num?)?.toInt() ?? 0,
      duracionMs: (json['duracionMs'] as num?)?.toInt() ?? 0,
    );
  }
}
