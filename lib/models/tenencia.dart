/// Por qué algo cambió de manos: un lote de productor, o un sistema de lote.
enum MotivoTraspaso {
  venta('VENTA', 'Venta'),
  herencia('HERENCIA', 'Herencia'),
  cesion('CESION', 'Cesión'),

  /// El período anterior estaba mal cargado.
  ///
  /// Va aparte de la venta para que las cuentas no mientan: en un padrón que
  /// se está saneando, corregir una carga equivocada es tan frecuente como
  /// vender, y mezclarlas haría que "cuántas ventas hubo" no signifique nada.
  correccion('CORRECCION', 'Corrección de datos'),

  otro('OTRO', 'Otro');

  const MotivoTraspaso(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static MotivoTraspaso? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final v in values) {
      if (v.valor == texto) return v;
    }
    return null;
  }
}

/// Quién tiene un lote, y desde cuándo.
class Tenedor {
  const Tenedor({
    required this.productorId,
    required this.nombre,
    required this.desde,
  });

  final int productorId;
  final String nombre;
  final DateTime desde;

  factory Tenedor.desdeJson(Map<String, dynamic> json) => Tenedor(
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
        nombre: json['nombre'] as String? ?? '',
        desde: DateTime.tryParse('${json['desde']}') ?? DateTime(1970),
      );
}

/// El sistema instalado en un lote.
class SistemaEnLote {
  const SistemaEnLote({
    required this.sistemaId,
    required this.codigo,
    required this.desde,
  });

  final int sistemaId;
  final String codigo;
  final DateTime desde;

  factory SistemaEnLote.desdeJson(Map<String, dynamic> json) => SistemaEnLote(
        sistemaId: (json['sistemaId'] as num?)?.toInt() ?? 0,
        codigo: json['codigo'] as String? ?? '',
        desde: DateTime.tryParse('${json['desde']}') ?? DateTime(1970),
      );
}

/// Traspasar un lote a otro productor, o trasladar un sistema a otro lote.
///
/// Es el mismo cuerpo para los dos porque son el mismo hecho: algo cambió de
/// manos, tal día, por tal motivo.
class TraspasoRequest {
  const TraspasoRequest({
    required this.motivo,
    this.productorId,
    this.desde,
    this.observaciones,
  });

  final MotivoTraspaso motivo;

  /// A quién pasa. Null lo deja sin tenedor, que es una situación real:
  /// alguien vendió y el comprador todavía no está cargado en el padrón.
  final int? productorId;

  /// Desde cuándo. Null significa hoy.
  final DateTime? desde;

  final String? observaciones;

  Map<String, dynamic> aJson() => {
        'motivo': motivo.valor,
        if (productorId != null) 'productorId': productorId,
        if (desde != null) 'desde': _soloFecha(desde!),
        if (observaciones != null) 'observaciones': observaciones,
      };

  static String _soloFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Un período del historial: algo estuvo en manos de alguien entre dos fechas.
///
/// Sirve igual para la tenencia de un lote y para un sistema en un lote, porque
/// cuentan lo mismo. [queEs] es el lote o el sistema; [conQuien] es el productor
/// o el lote donde estuvo.
class Tenencia {
  const Tenencia({
    required this.id,
    required this.queEs,
    required this.queEsId,
    required this.conQuien,
    required this.conQuienId,
    required this.desde,
    required this.vigente,
    this.hasta,
    this.motivo,
    this.motivoEtiqueta,
    this.observaciones,
  });

  final int id;
  final String queEs;
  final int queEsId;
  final String conQuien;
  final int conQuienId;
  final DateTime desde;
  final DateTime? hasta;
  final bool vigente;
  final MotivoTraspaso? motivo;
  final String? motivoEtiqueta;
  final String? observaciones;

  String get periodo {
    final inicio = _fecha(desde);
    return hasta == null ? 'desde $inicio' : '$inicio — ${_fecha(hasta!)}';
  }

  static String _fecha(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  factory Tenencia.desdeJson(Map<String, dynamic> json) => Tenencia(
        id: (json['id'] as num?)?.toInt() ?? 0,
        queEs: json['queEs'] as String? ?? '',
        queEsId: (json['queEsId'] as num?)?.toInt() ?? 0,
        conQuien: json['conQuien'] as String? ?? '',
        conQuienId: (json['conQuienId'] as num?)?.toInt() ?? 0,
        desde: DateTime.tryParse('${json['desde']}') ?? DateTime(1970),
        hasta: switch (json['hasta']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
        vigente: json['vigente'] as bool? ?? false,
        motivo: MotivoTraspaso.desde(json['motivo']),
        motivoEtiqueta: json['motivoEtiqueta'] as String?,
        observaciones: json['observaciones'] as String?,
      );
}

/// Un sistema: el agregado que un lote puede tener o no, y que se traslada.
class Sistema {
  const Sistema({
    required this.id,
    required this.codigo,
    this.descripcion,
    this.lote,
  });

  final int id;
  final String codigo;
  final String? descripcion;

  /// Dónde está hoy. Null si está disponible.
  final SistemaEnUnLote? lote;

  bool get disponible => lote == null;

  factory Sistema.desdeJson(Map<String, dynamic> json) => Sistema(
        id: (json['id'] as num?)?.toInt() ?? 0,
        codigo: json['codigo'] as String? ?? '',
        descripcion: json['descripcion'] as String?,
        lote: switch (json['lote']) {
          final Map<String, dynamic> m => SistemaEnUnLote.desdeJson(m),
          _ => null,
        },
      );

  @override
  bool operator ==(Object other) => other is Sistema && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// El lote donde está instalado un sistema, con su contexto.
class SistemaEnUnLote {
  const SistemaEnUnLote({
    required this.loteId,
    required this.codigo,
    required this.sindicato,
    required this.desde,
    this.tenedor,
  });

  final int loteId;
  final String codigo;
  final String sindicato;

  /// Quién tiene ese lote hoy. Null si está sin tenedor.
  final String? tenedor;

  final DateTime desde;

  factory SistemaEnUnLote.desdeJson(Map<String, dynamic> json) => SistemaEnUnLote(
        loteId: (json['loteId'] as num?)?.toInt() ?? 0,
        codigo: json['codigo'] as String? ?? '',
        sindicato: json['sindicato'] as String? ?? '',
        tenedor: json['tenedor'] as String?,
        desde: DateTime.tryParse('${json['desde']}') ?? DateTime(1970),
      );
}

/// Alta y edición de un sistema.
class SistemaRequest {
  const SistemaRequest({required this.codigo, this.descripcion});

  final String codigo;
  final String? descripcion;

  Map<String, dynamic> aJson() => {
        'codigo': codigo,
        if (descripcion != null) 'descripcion': descripcion,
      };
}
