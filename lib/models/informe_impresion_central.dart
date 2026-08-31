/// Estado consolidado de la impresión de credenciales de una central.
class InformeImpresionCentral {
  const InformeImpresionCentral({
    required this.centralId,
    required this.central,
    required this.federacion,
    required this.sindicatos,
    required this.sindicatosSinSello,
    required this.total,
    required this.impresos,
    required this.pendientes,
    required this.pendientesConFoto,
    required this.sinFoto,
    required this.listosParaImprimir,
    required this.porcentajeAvance,
    required this.detalle,
  });

  final int centralId;
  final String central;
  final String federacion;
  final int sindicatos;
  final int sindicatosSinSello;
  final int total;
  final int impresos;
  final int pendientes;
  final int pendientesConFoto;
  final int sinFoto;
  final int listosParaImprimir;
  final double porcentajeAvance;
  final List<AvanceImpresionSindicato> detalle;

  factory InformeImpresionCentral.desdeJson(Map<String, dynamic> json) =>
      InformeImpresionCentral(
        centralId: (json['centralId'] as num?)?.toInt() ?? 0,
        central: json['central'] as String? ?? '',
        federacion: json['federacion'] as String? ?? '',
        sindicatos: (json['sindicatos'] as num?)?.toInt() ?? 0,
        sindicatosSinSello: (json['sindicatosSinSello'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        impresos: (json['impresos'] as num?)?.toInt() ?? 0,
        pendientes: (json['pendientes'] as num?)?.toInt() ?? 0,
        pendientesConFoto: (json['pendientesConFoto'] as num?)?.toInt() ?? 0,
        sinFoto: (json['sinFoto'] as num?)?.toInt() ?? 0,
        listosParaImprimir: (json['listosParaImprimir'] as num?)?.toInt() ?? 0,
        porcentajeAvance: (json['porcentajeAvance'] as num?)?.toDouble() ?? 0,
        detalle: ((json['detalle'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AvanceImpresionSindicato.desdeJson)
            .toList(growable: false),
      );
}

/// Estado consolidado de la impresión de todas las centrales de una federación.
class InformeImpresionFederacion {
  const InformeImpresionFederacion({
    required this.federacionId,
    required this.federacion,
    required this.centrales,
    required this.sindicatos,
    required this.sindicatosSinSello,
    required this.total,
    required this.impresos,
    required this.pendientes,
    required this.pendientesConFoto,
    required this.sinFoto,
    required this.listosParaImprimir,
    required this.porcentajeAvance,
    required this.detalle,
  });

  final int federacionId;
  final String federacion;
  final int centrales;
  final int sindicatos;
  final int sindicatosSinSello;
  final int total;
  final int impresos;
  final int pendientes;
  final int pendientesConFoto;
  final int sinFoto;
  final int listosParaImprimir;
  final double porcentajeAvance;
  final List<InformeImpresionCentral> detalle;

  factory InformeImpresionFederacion.desdeJson(Map<String, dynamic> json) =>
      InformeImpresionFederacion(
        federacionId: (json['federacionId'] as num?)?.toInt() ?? 0,
        federacion: json['federacion'] as String? ?? '',
        centrales: (json['centrales'] as num?)?.toInt() ?? 0,
        sindicatos: (json['sindicatos'] as num?)?.toInt() ?? 0,
        sindicatosSinSello: (json['sindicatosSinSello'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        impresos: (json['impresos'] as num?)?.toInt() ?? 0,
        pendientes: (json['pendientes'] as num?)?.toInt() ?? 0,
        pendientesConFoto: (json['pendientesConFoto'] as num?)?.toInt() ?? 0,
        sinFoto: (json['sinFoto'] as num?)?.toInt() ?? 0,
        listosParaImprimir: (json['listosParaImprimir'] as num?)?.toInt() ?? 0,
        porcentajeAvance: (json['porcentajeAvance'] as num?)?.toDouble() ?? 0,
        detalle: ((json['detalle'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(InformeImpresionCentral.desdeJson)
            .toList(growable: false),
      );
}

/// Avance de un sindicato dentro del consolidado de su central.
class AvanceImpresionSindicato {
  const AvanceImpresionSindicato({
    required this.sindicatoId,
    required this.sindicato,
    required this.selloCargado,
    required this.total,
    required this.impresos,
    required this.pendientes,
    required this.pendientesConFoto,
    required this.sinFoto,
    required this.listosParaImprimir,
    required this.porcentajeAvance,
  });

  final int sindicatoId;
  final String sindicato;
  final bool selloCargado;
  final int total;
  final int impresos;
  final int pendientes;
  final int pendientesConFoto;
  final int sinFoto;
  final int listosParaImprimir;
  final double porcentajeAvance;

  factory AvanceImpresionSindicato.desdeJson(Map<String, dynamic> json) =>
      AvanceImpresionSindicato(
        sindicatoId: (json['sindicatoId'] as num?)?.toInt() ?? 0,
        sindicato: json['sindicato'] as String? ?? '',
        selloCargado: json['selloCargado'] as bool? ?? false,
        total: (json['total'] as num?)?.toInt() ?? 0,
        impresos: (json['impresos'] as num?)?.toInt() ?? 0,
        pendientes: (json['pendientes'] as num?)?.toInt() ?? 0,
        pendientesConFoto: (json['pendientesConFoto'] as num?)?.toInt() ?? 0,
        sinFoto: (json['sinFoto'] as num?)?.toInt() ?? 0,
        listosParaImprimir: (json['listosParaImprimir'] as num?)?.toInt() ?? 0,
        porcentajeAvance: (json['porcentajeAvance'] as num?)?.toDouble() ?? 0,
      );
}

/// Listas de productores impresos y bloqueados por falta de datos.
class InformeNominalImpresionCentral {
  const InformeNominalImpresionCentral({
    required this.centralId,
    required this.central,
    required this.federacion,
    required this.totalImpresos,
    required this.totalFaltantesDatos,
    required this.sindicatos,
  });

  final int centralId;
  final String central;
  final String federacion;
  final int totalImpresos;
  final int totalFaltantesDatos;
  final List<InformeNominalSindicato> sindicatos;

  factory InformeNominalImpresionCentral.desdeJson(Map<String, dynamic> json) =>
      InformeNominalImpresionCentral(
        centralId: (json['centralId'] as num?)?.toInt() ?? 0,
        central: json['central'] as String? ?? '',
        federacion: json['federacion'] as String? ?? '',
        totalImpresos: (json['totalImpresos'] as num?)?.toInt() ?? 0,
        totalFaltantesDatos:
            (json['totalFaltantesDatos'] as num?)?.toInt() ?? 0,
        sindicatos: ((json['sindicatos'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(InformeNominalSindicato.desdeJson)
            .toList(growable: false),
      );
}

class InformeNominalSindicato {
  const InformeNominalSindicato({
    required this.sindicatoId,
    required this.sindicato,
    required this.impresos,
    required this.faltantesDatos,
  });

  final int sindicatoId;
  final String sindicato;
  final List<FilaInformeImpresion> impresos;
  final List<FilaInformeImpresion> faltantesDatos;

  factory InformeNominalSindicato.desdeJson(Map<String, dynamic> json) =>
      InformeNominalSindicato(
        sindicatoId: (json['sindicatoId'] as num?)?.toInt() ?? 0,
        sindicato: json['sindicato'] as String? ?? '',
        impresos: _filas(json['impresos']),
        faltantesDatos: _filas(json['faltantesDatos']),
      );

  static List<FilaInformeImpresion> _filas(Object? json) =>
      ((json as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FilaInformeImpresion.desdeJson)
          .toList(growable: false);
}

class FilaInformeImpresion {
  const FilaInformeImpresion({
    required this.productorId,
    required this.nombres,
    required this.apellidos,
    required this.ci,
    required this.lotes,
    required this.codigoPadron,
    required this.impresiones,
    required this.ultimaImpresion,
    required this.datosFaltantes,
  });

  final int productorId;
  final String nombres;
  final String apellidos;
  final String ci;
  final String lotes;
  final String codigoPadron;
  final int impresiones;
  final DateTime? ultimaImpresion;
  final List<String> datosFaltantes;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory FilaInformeImpresion.desdeJson(Map<String, dynamic> json) =>
      FilaInformeImpresion(
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
        nombres: json['nombres'] as String? ?? '',
        apellidos: json['apellidos'] as String? ?? '',
        ci: json['ci'] as String? ?? '',
        lotes: json['lotes'] as String? ?? '',
        codigoPadron: json['codigoPadron'] as String? ?? '',
        impresiones: (json['impresiones'] as num?)?.toInt() ?? 0,
        ultimaImpresion: DateTime.tryParse(
          json['ultimaImpresion'] as String? ?? '',
        ),
        datosFaltantes: ((json['datosFaltantes'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}
