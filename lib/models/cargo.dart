/// Nivel de la organización al que pertenece un directorio.
///
/// Cada uno tiene sus cargos y su propia lista de candidatos. La ruta es la que
/// usa la API: `/sindicatos/7/directorio`, `/centrales/4/directorio`,
/// `/federaciones/1/directorio`.
enum Ambito {
  sindicato('SINDICATO', 'Sindicato', 'sindicatos'),
  central('CENTRAL', 'Central', 'centrales'),
  federacion('FEDERACION', 'Federación', 'federaciones');

  const Ambito(this.valor, this.etiqueta, this.recurso);

  final String valor;
  final String etiqueta;

  /// Segmento de la URL: el recurso del que cuelga el directorio.
  final String recurso;

  static Ambito? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final a in values) {
      if (a.valor == texto) return a;
    }
    return null;
  }
}

/// Cargos del directorio.
///
/// Los comparten los tres niveles, pero cada uno admite los suyos: el backend
/// dice cuáles en la respuesta del directorio, así que acá no se duplica esa
/// regla.
enum TipoCargo {
  ejecutivo('EJECUTIVO', 'Ejecutivo'),
  secretarioGeneral('SECRETARIO_GENERAL', 'Secretario General'),
  secretarioRelaciones('SECRETARIO_RELACIONES', 'Secretario Relaciones'),
  haciendas('HACIENDAS', 'Haciendas'),
  vocal('VOCAL', 'Vocal'),

  // Solo para poder leer historiales antes de ejecutar la migración SQL.
  @Deprecated('Usar secretarioGeneral o ejecutivo según el nivel')
  presidente('PRESIDENTE', 'Presidente (histórico)'),
  @Deprecated('Usar secretarioGeneral o secretarioRelaciones según el nivel')
  secretario('SECRETARIO', 'Secretario (histórico)');

  const TipoCargo(this.valor, this.etiqueta);

  /// Como viaja en la URL y en el JSON.
  final String valor;
  final String etiqueta;

  bool get esHistorico =>
      this == TipoCargo.presidente || this == TipoCargo.secretario;

  static Iterable<TipoCargo> get vigentes =>
      values.where((c) => !c.esHistorico);

  /// Posibles firmantes. El backend decide según el nivel del directorio.
  bool get puedeFirmar =>
      this == TipoCargo.ejecutivo ||
      this == TipoCargo.secretarioGeneral ||
      this == TipoCargo.secretarioRelaciones ||
      this == TipoCargo.presidente ||
      this == TipoCargo.secretario;

  static TipoCargo? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final c in values) {
      if (c.valor == texto) return c;
    }
    return null;
  }
}

/// Imágenes históricas que acompañan a un cargo.
///
/// Van atadas al período y no a la persona: la firma con la que alguien
/// autorizó documentos siendo presidente pertenece a ese mandato.
enum TipoImagenCargo {
  firma('FIRMA', 'Firma', 'La firma manuscrita'),
  pieFirma(
    'PIE_FIRMA',
    'Pie de firma',
    'La imagen con nombre, cargo y organización',
  );

  const TipoImagenCargo(this.valor, this.etiqueta, this.detalle);

  final String valor;
  final String etiqueta;
  final String detalle;

  /// Como va en la URL: con guion, que es lo natural en una dirección web.
  String get ruta => valor.toLowerCase().replaceAll('_', '-');
}

/// Un período en el que un productor ocupó un cargo.
///
/// El directorio no se guarda como un campo del sindicato sino como períodos
/// con fechas: así cambiar de presidente es cerrar uno y abrir otro, y el
/// historial existe sin tener que construirlo aparte.
class Cargo {
  const Cargo({
    required this.id,
    required this.cargo,
    required this.productorId,
    required this.productorNombre,
    required this.ambito,
    required this.ambitoId,
    required this.ambitoNombre,
    required this.desde,
    required this.hasta,
    required this.vigente,
    this.firmaUrl,
    this.pieFirma,
    this.pieFirmaUrl,
  });

  final int id;
  final TipoCargo cargo;
  final int productorId;
  final String productorNombre;

  /// De qué nivel es este cargo, y de cuál sindicato, central o federación.
  final Ambito ambito;
  final int ambitoId;
  final String ambitoNombre;

  final DateTime desde;

  /// Null mientras sigue en funciones.
  final DateTime? hasta;
  final bool vigente;

  /// Direcciones de las imágenes de este período, o null si no se cargaron.
  final String? firmaUrl;

  /// Texto automático: productor, cargo y organización.
  final String? pieFirma;

  /// Solo para compatibilidad con datos históricos.
  final String? pieFirmaUrl;

  String? urlDe(TipoImagenCargo tipo) =>
      tipo == TipoImagenCargo.firma ? firmaUrl : pieFirmaUrl;

  bool get tieneFirmas => firmaUrl != null;

  String get periodo {
    final inicio = _fecha(desde);
    return hasta == null ? 'desde $inicio' : '$inicio — ${_fecha(hasta!)}';
  }

  static String _fecha(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  factory Cargo.desdeJson(Map<String, dynamic> json) => Cargo(
    id: (json['id'] as num?)?.toInt() ?? 0,
    cargo: TipoCargo.desde(json['cargo']) ?? TipoCargo.secretarioGeneral,
    productorId: (json['productorId'] as num?)?.toInt() ?? 0,
    productorNombre: json['productorNombre'] as String? ?? '',
    ambito: Ambito.desde(json['ambito']) ?? Ambito.sindicato,
    ambitoId: (json['ambitoId'] as num?)?.toInt() ?? 0,
    ambitoNombre: json['ambitoNombre'] as String? ?? '',
    desde: DateTime.tryParse('${json['desde']}') ?? DateTime(1970),
    hasta: switch (json['hasta']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    vigente: json['vigente'] as bool? ?? false,
    firmaUrl: json['firmaUrl'] as String?,
    pieFirma: json['pieFirma'] as String?,
    pieFirmaUrl: json['pieFirmaUrl'] as String?,
  );
}

/// Un cargo del directorio y quién lo ocupa.
///
/// Viene uno por cada cargo del nivel, ocupado o no. La pantalla dibuja lo que
/// llega en vez de saberse de memoria qué cargos tiene cada nivel: si mañana
/// la federación suma uno, aparece sin tocar el cliente.
class Puesto {
  const Puesto({
    required this.cargo,
    required this.etiqueta,
    required this.puedeFirmar,
    required this.actual,
  });

  final TipoCargo cargo;
  final String etiqueta;

  /// Si a este cargo se le pueden cargar firma y pie de firma.
  final bool puedeFirmar;

  /// Quién lo ocupa hoy. Null si está vacante.
  final Cargo? actual;

  bool get ocupado => actual != null;

  factory Puesto.desdeJson(Map<String, dynamic> json) {
    final tipo = TipoCargo.desde(json['cargo']) ?? TipoCargo.secretarioGeneral;
    return Puesto(
      cargo: tipo,
      etiqueta: json['etiqueta'] as String? ?? tipo.etiqueta,
      puedeFirmar: json['puedeFirmar'] as bool? ?? tipo.puedeFirmar,
      actual: switch (json['actual']) {
        final Map<String, dynamic> m => Cargo.desdeJson(m),
        _ => null,
      },
    );
  }
}

/// Directorio vigente de un sindicato, una central o la federación.
class Directorio {
  const Directorio({
    required this.ambito,
    required this.ambitoId,
    required this.ambitoNombre,
    required this.puestos,
    this.selloUrl,
    this.permitePieFirmaImagen = false,
    this.firmaObligatoria = true,
    this.selloObligatorio = true,
  });

  final Ambito ambito;
  final int ambitoId;
  final String ambitoNombre;
  final String? selloUrl;
  final bool permitePieFirmaImagen;
  final bool firmaObligatoria;
  final bool selloObligatorio;
  final List<Puesto> puestos;

  bool get estaCompleto => puestos.every((p) => p.ocupado);
  bool get estaVacio => puestos.every((p) => !p.ocupado);

  Puesto? puestoDe(TipoCargo tipo) {
    for (final p in puestos) {
      if (p.cargo == tipo) return p;
    }
    return null;
  }

  Cargo? cargoDe(TipoCargo tipo) => puestoDe(tipo)?.actual;

  factory Directorio.desdeJson(Map<String, dynamic> json) {
    final ambito = Ambito.desde(json['ambito']) ?? Ambito.sindicato;
    return Directorio(
      ambito: ambito,
      ambitoId: (json['ambitoId'] as num?)?.toInt() ?? 0,
      ambitoNombre: json['ambitoNombre'] as String? ?? '',
      selloUrl: json['selloUrl'] as String?,
      permitePieFirmaImagen:
          json['permitePieFirmaImagen'] as bool? ?? ambito != Ambito.sindicato,
      firmaObligatoria:
          json['firmaObligatoria'] as bool? ?? ambito != Ambito.sindicato,
      selloObligatorio: json['selloObligatorio'] as bool? ?? true,
      puestos: switch (json['puestos']) {
        final List<dynamic> lista =>
          lista
              .whereType<Map<String, dynamic>>()
              .map(Puesto.desdeJson)
              .toList(growable: false),
        _ => const <Puesto>[],
      },
    );
  }
}
