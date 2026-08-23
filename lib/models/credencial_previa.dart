/// Lo que va a salir impreso en una credencial, antes de imprimirla.
///
/// Una credencial sale plastificada y se reparte. Descubrir que le falta la
/// foto cuando ya está en la mano de alguien significa rehacerla, así que el
/// backend la revisa primero y no emite el PDF hasta que esté completa.
class CredencialPrevia {
  const CredencialPrevia({
    required this.productorId,
    required this.nombreCompleto,
    required this.federacion,
    required this.central,
    required this.sindicato,
    required this.nombres,
    required this.apellidos,
    required this.ci,
    required this.lotes,
    required this.codigoQr,
    required this.faltantes,
    required this.completa,
    this.bloqueo,
    this.codigoPadron,
    this.fotoUrl,
    this.selloFederacionUrl,
    this.selloCentralUrl,
    this.selloSindicatoUrl,
    this.ejecutivoFederacion,
    FirmantePrevio? secretarioGeneralCentral,
    FirmantePrevio? secretarioGeneralSindicato,
    FirmantePrevio? secretarioGeneral,
    FirmantePrevio? secretarioRelaciones,
    @Deprecated('Usar secretarioGeneral') FirmantePrevio? presidente,
    @Deprecated('Usar secretarioRelaciones') FirmantePrevio? secretario,
  }) : secretarioGeneralCentral =
           secretarioGeneralCentral ?? secretarioGeneral ?? presidente,
       secretarioGeneralSindicato =
           secretarioGeneralSindicato ?? secretarioRelaciones ?? secretario;

  final int productorId;
  final String nombreCompleto;

  /// Título de la federación tal como se imprime en la banda verde.
  final String federacion;
  final String central;
  final String sindicato;

  final String nombres;
  final String apellidos;
  final String ci;

  /// Códigos de los lotes que tiene hoy. Puede venir vacío sin que eso impida
  /// emitir: quien vendió su parcela sigue siendo afiliado.
  final String lotes;

  /// El código del padrón, `2-IVI-1`. Null si todavía no se puede armar.
  final String? codigoPadron;

  /// El código que dice el QR.
  final String codigoQr;

  final String? fotoUrl;

  final String? selloFederacionUrl;
  final String? selloCentralUrl;
  final String? selloSindicatoUrl;
  final FirmantePrevio? ejecutivoFederacion;
  final FirmantePrevio? secretarioGeneralCentral;
  final FirmantePrevio? secretarioGeneralSindicato;

  @Deprecated('Usar secretarioGeneralCentral')
  FirmantePrevio? get secretarioGeneral => secretarioGeneralCentral;

  @Deprecated('Usar secretarioGeneralSindicato')
  FirmantePrevio? get secretarioRelaciones => secretarioGeneralSindicato;

  @Deprecated('Usar secretarioGeneralCentral')
  FirmantePrevio? get presidente => secretarioGeneralCentral;

  @Deprecated('Usar secretarioGeneralSindicato')
  FirmantePrevio? get secretario => secretarioGeneralSindicato;

  /// Lo que falta para poder emitirla. Vacía si está lista.
  final List<Faltante> faltantes;

  /// Por qué está bloqueada, si lo está. Hoy la única causa es un veto de
  /// asamblea vigente.
  ///
  /// Va aparte de los faltantes porque no es un dato que falte: es una
  /// decisión, y no se arregla completando nada.
  final BloqueoCredencial? bloqueo;

  final bool completa;

  factory CredencialPrevia.desdeJson(Map<String, dynamic> json) =>
      CredencialPrevia(
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
        nombreCompleto: json['nombreCompleto'] as String? ?? '',
        federacion: json['federacion'] as String? ?? '',
        central: json['central'] as String? ?? '',
        sindicato: json['sindicato'] as String? ?? '',
        nombres: json['nombres'] as String? ?? '',
        apellidos: json['apellidos'] as String? ?? '',
        ci: json['ci'] as String? ?? '',
        lotes: json['lotes'] as String? ?? '',
        codigoPadron: json['codigoPadron'] as String?,
        codigoQr: json['codigoQr'] as String? ?? '',
        fotoUrl: json['fotoUrl'] as String?,
        selloFederacionUrl: json['selloFederacionUrl'] as String?,
        selloCentralUrl: json['selloCentralUrl'] as String?,
        selloSindicatoUrl: json['selloSindicatoUrl'] as String?,
        ejecutivoFederacion: FirmantePrevio.desdeJson(
          json['ejecutivoFederacion'] as Map<String, dynamic>?,
        ),
        secretarioGeneralCentral: FirmantePrevio.desdeJson(
          json['secretarioGeneralCentral'] as Map<String, dynamic>?,
        ),
        secretarioGeneralSindicato: FirmantePrevio.desdeJson(
          json['secretarioGeneralSindicato'] as Map<String, dynamic>?,
        ),
        // Las claves anteriores se leen durante la transición para que el
        // frontend nuevo también pueda hablar con un backend aún no reiniciado.
        secretarioGeneral: FirmantePrevio.desdeJson(
          (json['secretarioGeneral'] ?? json['presidente'])
              as Map<String, dynamic>?,
        ),
        secretarioRelaciones: FirmantePrevio.desdeJson(
          (json['secretarioRelaciones'] ?? json['secretario'])
              as Map<String, dynamic>?,
        ),
        faltantes: Faltante.lista(json['faltantes']),
        bloqueo: BloqueoCredencial.desdeJson(
          json['bloqueo'] as Map<String, dynamic>?,
        ),
        completa: json['completa'] as bool? ?? false,
      );
}

/// Quien firma el reverso.
class FirmantePrevio {
  const FirmantePrevio({
    required this.nombre,
    this.cargo = '',
    this.organizacion = '',
    this.firmaUrl,
    bool? tieneFirma,
    bool? tieneSello,
  }) : _tieneFirmaAnterior = tieneFirma;

  final String nombre;
  final String cargo;
  final String organizacion;
  final String? firmaUrl;
  final bool? _tieneFirmaAnterior;

  bool get tieneFirma => firmaUrl != null || (_tieneFirmaAnterior ?? false);

  bool get listo => tieneFirma;

  String get pieFirma => [
    nombre,
    cargo,
    organizacion,
  ].where((linea) => linea.trim().isNotEmpty).join('\n');

  static FirmantePrevio? desdeJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return FirmantePrevio(
      nombre: json['nombre'] as String? ?? '',
      cargo: json['cargo'] as String? ?? '',
      organizacion: json['organizacion'] as String? ?? '',
      firmaUrl: json['firmaUrl'] as String?,
      tieneFirma: json['tieneFirma'] as bool?,
    );
  }
}

/// Un dato que falta, y dónde se carga.
///
/// El [donde] no es decoración: sin él la lista dice que algo está mal pero no
/// adónde ir, que es la mitad del trabajo.
class Faltante {
  const Faltante({
    required this.campo,
    required this.detalle,
    required this.donde,
  });

  final String campo;
  final String detalle;
  final String donde;

  factory Faltante.desdeJson(Map<String, dynamic> json) => Faltante(
    campo: json['campo'] as String? ?? '',
    detalle: json['detalle'] as String? ?? '',
    donde: json['donde'] as String? ?? '',
  );

  static List<Faltante> lista(Object? crudo) => (crudo as List? ?? [])
      .map((e) => Faltante.desdeJson(e as Map<String, dynamic>))
      .toList();
}

/// Vista previa del pliego de un sindicato.
class PliegoPrevio {
  const PliegoPrevio({
    required this.sindicatoId,
    required this.sindicato,
    required this.productores,
    required this.faltantesDelSindicato,
    required this.incompletos,
    required this.completa,
  });

  final int sindicatoId;
  final String sindicato;

  /// Cuántas credenciales saldrían.
  final int productores;

  /// Lo que le falta al sindicato, que le falta a todas por igual: la sigla de
  /// la central o la firma de un dirigente. Se muestra aparte porque arreglarlo
  /// una vez arregla el pliego entero.
  final List<Faltante> faltantesDelSindicato;

  final List<ProductorIncompleto> incompletos;

  final bool completa;

  factory PliegoPrevio.desdeJson(Map<String, dynamic> json) => PliegoPrevio(
    sindicatoId: (json['sindicatoId'] as num?)?.toInt() ?? 0,
    sindicato: json['sindicato'] as String? ?? '',
    productores: (json['productores'] as num?)?.toInt() ?? 0,
    faltantesDelSindicato: Faltante.lista(json['faltantesDelSindicato']),
    incompletos: ((json['incompletos'] as List?) ?? [])
        .map((e) => ProductorIncompleto.desdeJson(e as Map<String, dynamic>))
        .toList(),
    completa: json['completa'] as bool? ?? false,
  );
}

/// Un productor al que le falta algo para su credencial.
class ProductorIncompleto {
  const ProductorIncompleto({
    required this.productorId,
    required this.nombreCompleto,
    required this.faltantes,
  });

  final int productorId;
  final String nombreCompleto;
  final List<Faltante> faltantes;

  factory ProductorIncompleto.desdeJson(Map<String, dynamic> json) =>
      ProductorIncompleto(
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
        nombreCompleto: json['nombreCompleto'] as String? ?? '',
        faltantes: Faltante.lista(json['faltantes']),
      );
}

/// Por qué la credencial está bloqueada.
///
/// Hoy la única causa es un veto de asamblea vigente. Se distingue de los
/// faltantes a propósito: un faltante se arregla cargando el dato, un bloqueo
/// se levanta con otra decisión de asamblea, y confundirlos mandaría a alguien
/// a buscar una foto que no falta.
class BloqueoCredencial {
  const BloqueoCredencial({
    required this.titulo,
    required this.motivo,
    required this.reunion,
    required this.desde,
    required this.comoSeLevanta,
  });

  final String titulo;
  final String motivo;

  /// La reunión que lo decidió, para poder ir al acta.
  final String reunion;
  final DateTime? desde;

  /// Qué hay que hacer para destrabarlo.
  final String comoSeLevanta;

  static BloqueoCredencial? desdeJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return BloqueoCredencial(
      titulo: json['titulo'] as String? ?? 'Credencial bloqueada',
      motivo: json['motivo'] as String? ?? '',
      reunion: json['reunion'] as String? ?? '',
      desde: DateTime.tryParse(json['desde'] as String? ?? ''),
      comoSeLevanta: json['comoSeLevanta'] as String? ?? '',
    );
  }
}
