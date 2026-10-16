/// Fila de la planilla que no se pudo importar.
class ErrorFila {
  const ErrorFila({
    required this.fila,
    required this.columna,
    required this.valor,
    required this.mensaje,
    this.productor,
    this.ci,
    this.central,
    this.sindicato,
  });

  /// Número tal como lo muestra Excel: con encabezado en la 1, el primer dato
  /// es la 2. Se puede ir directo a esa fila en la planilla.
  final int fila;

  /// Columna que provocó el rechazo, o null si el problema es de la fila entera.
  final String? columna;

  final String? valor;
  final String mensaje;
  final String? productor;
  final String? ci;
  final String? central;
  final String? sindicato;

  factory ErrorFila.desdeJson(Map<String, dynamic> json) => ErrorFila(
    fila: (json['fila'] as num?)?.toInt() ?? 0,
    columna: json['columna'] as String?,
    valor: json['valor'] as String?,
    mensaje: json['mensaje'] as String? ?? '',
    productor: json['productor'] as String?,
    ci: json['ci'] as String?,
    central: json['central'] as String?,
    sindicato: json['sindicato'] as String?,
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
    this.productoresActualizados = 0,
    this.productoresNuevosSinLote,
    this.productoresSinCambios = 0,
    this.decisionesPendientes = 0,
    this.comparaciones = const [],
    this.filasOmitidas = 0,
    this.gruposDuplicados = const [],
    this.avisos = const [],
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
  final int productoresActualizados;
  final int? productoresNuevosSinLote;
  int get nuevosSinLote =>
      productoresNuevosSinLote ??
      (productores > lotes ? productores - lotes : 0);
  final int productoresSinCambios;
  final int decisionesPendientes;
  final List<ComparacionImportacion> comparaciones;
  final int filasOmitidas;
  final List<GrupoDuplicadoImportacion> gruposDuplicados;
  final List<ErrorFila> avisos;

  bool get hayRechazos => filasRechazadas > 0;
  bool get tocaLaJerarquia =>
      centralesNuevas.isNotEmpty || sindicatosNuevos.isNotEmpty;
  List<String> get centralesFaltantes => centralesNuevas;
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
      sindicatosNuevos: lista(
        json['sindicatosNuevos'],
        SindicatoNuevo.desdeJson,
      ),
      posiblesDuplicados: (json['posiblesDuplicados'] as num?)?.toInt() ?? 0,
      errores: lista(json['errores'], ErrorFila.desdeJson),
      erroresOmitidos: (json['erroresOmitidos'] as num?)?.toInt() ?? 0,
      duracionMs: (json['duracionMs'] as num?)?.toInt() ?? 0,
      productoresActualizados:
          (json['productoresActualizados'] as num?)?.toInt() ?? 0,
      productoresNuevosSinLote: (json['productoresNuevosSinLote'] as num?)
          ?.toInt(),
      productoresSinCambios:
          (json['productoresSinCambios'] as num?)?.toInt() ?? 0,
      decisionesPendientes:
          (json['decisionesPendientes'] as num?)?.toInt() ?? 0,
      comparaciones: lista(
        json['comparaciones'],
        ComparacionImportacion.desdeJson,
      ),
      filasOmitidas: (json['filasOmitidas'] as num?)?.toInt() ?? 0,
      gruposDuplicados: lista(
        json['gruposDuplicados'],
        GrupoDuplicadoImportacion.desdeJson,
      ),
      avisos: lista(json['avisos'], ErrorFila.desdeJson),
    );
  }
}

class GrupoDuplicadoImportacion {
  const GrupoDuplicadoImportacion({
    required this.huella,
    required this.ci,
    required this.filaElegida,
    required this.filas,
  });
  final String huella, ci;
  final int? filaElegida;
  final List<FilaDuplicadaImportacion> filas;
  factory GrupoDuplicadoImportacion.desdeJson(Map<String, dynamic> j) =>
      GrupoDuplicadoImportacion(
        huella: j['huella'] as String,
        ci: j['ci'] as String,
        filaElegida: (j['filaElegida'] as num?)?.toInt(),
        filas: (j['filas'] as List)
            .map(
              (f) =>
                  FilaDuplicadaImportacion.desdeJson(f as Map<String, dynamic>),
            )
            .toList(),
      );
}

class FilaDuplicadaImportacion {
  const FilaDuplicadaImportacion({
    required this.numero,
    required this.productor,
    required this.central,
    required this.sindicato,
    this.numeroLote,
    this.extension,
    this.clasificacion,
    this.observaciones,
    this.seleccionada = true,
  });
  final int numero;
  final String productor, central, sindicato;
  final String? numeroLote, extension, clasificacion, observaciones;
  final bool seleccionada;
  factory FilaDuplicadaImportacion.desdeJson(Map<String, dynamic> j) =>
      FilaDuplicadaImportacion(
        numero: (j['numero'] as num).toInt(),
        productor: j['productor'] as String,
        central: j['central'] as String? ?? '',
        sindicato: j['sindicato'] as String? ?? '',
        numeroLote: j['numeroLote'] as String?,
        extension: j['extension'] as String?,
        clasificacion: j['clasificacion'] as String?,
        observaciones: j['observaciones'] as String?,
        seleccionada: j['seleccionada'] as bool? ?? true,
      );
}

class ComparacionImportacion {
  const ComparacionImportacion({
    required this.fila,
    required this.productor,
    required this.nombrePlanilla,
    required this.ci,
    required this.central,
    required this.sindicato,
    required this.huella,
    required this.cambios,
  });
  final int fila;
  final String productor, nombrePlanilla, ci, central, sindicato, huella;
  final List<CambioImportacion> cambios;
  String clave(String campo) => '$huella:$campo';
  Map<String, dynamic> decision(Map<String, bool?> elegidos) => {
    'fila': fila,
    'huella': huella,
    'campos': {
      for (final c in cambios)
        if (!c.automatico && elegidos.containsKey(clave(c.campo)))
          c.campo: elegidos[clave(c.campo)],
    },
  };
  factory ComparacionImportacion.desdeJson(Map<String, dynamic> j) =>
      ComparacionImportacion(
        fila: (j['fila'] as num).toInt(),
        productor: j['productor'] as String,
        nombrePlanilla: j['nombrePlanilla'] as String,
        ci: j['ci'] as String,
        central: j['central'] as String,
        sindicato: j['sindicato'] as String,
        huella: j['huella'] as String,
        cambios: (j['cambios'] as List)
            .map((e) => CambioImportacion.desdeJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CambioImportacion {
  const CambioImportacion({
    required this.campo,
    required this.actual,
    required this.propuesto,
    required this.automatico,
  });
  final String campo;
  final String? actual;
  final String propuesto;
  final bool automatico;
  String get etiqueta => switch (campo) {
    'numeroLote' => 'Número de lote',
    'extension' => 'Extensión',
    'clasificacion' => 'Clasificación',
    'observaciones' => 'Observación',
    _ => campo,
  };
  factory CambioImportacion.desdeJson(Map<String, dynamic> j) =>
      CambioImportacion(
        campo: j['campo'] as String,
        actual: j['actual'] as String?,
        propuesto: j['propuesto'] as String,
        automatico: j['automatico'] as bool? ?? false,
      );
}
