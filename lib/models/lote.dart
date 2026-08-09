/// Subdivisión de una parcela, ya normalizada por el backend.
enum ExtensionLote {
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  e('E');

  const ExtensionLote(this.valor);

  final String valor;

  static ExtensionLote? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final v in values) {
      if (v.valor == texto) return v;
    }
    return null;
  }
}

/// Estado del lote, normalizado a partir del texto libre del padrón original.
///
/// [desconocido] no es un error del cliente: significa que la escritura de
/// origen no se pudo interpretar, y el texto crudo queda en
/// [Lote.estadoOriginal].
enum EstadoLote {
  conSistema('CON_SISTEMA', 'Con sistema'),
  sinSistema('SIN_SISTEMA', 'Sin sistema'),
  blanco('BLANCO', 'Blanco'),
  fraccionado('FRACCIONADO', 'Fraccionado'),
  detallista('DETALLISTA', 'Detallista'),
  nuevo('NUEVO', 'Nuevo'),
  desconocido('DESCONOCIDO', 'Desconocido');

  const EstadoLote(this.valor, this.etiqueta);

  final String valor;

  /// Texto para mostrar en pantalla.
  final String etiqueta;

  /// Si el backend agregara un estado nuevo, cae en [desconocido] en vez de
  /// lanzar y tumbar la pantalla entera.
  static EstadoLote desde(Object? crudo) {
    final texto = '$crudo';
    for (final v in values) {
      if (v.valor == texto) return v;
    }
    return EstadoLote.desconocido;
  }
}

/// Por ahora el backend solo declara un mercado, pero es un enum: puede crecer.
enum Mercado {
  detallista('DETALLISTA', 'Detallista');

  const Mercado(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static Mercado? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final v in values) {
      if (v.valor == texto) return v;
    }
    return null;
  }
}

/// Parcela asignada a un productor.
class Lote {
  const Lote({
    required this.id,
    required this.numero,
    required this.extension,
    required this.codigo,
    required this.estado,
    required this.estadoOriginal,
    required this.mercado,
    required this.productorId,
  });

  final int id;
  final String? numero;
  final ExtensionLote? extension;

  /// Número y extensión ya juntos, tal como los arma el backend: `74-A`.
  final String codigo;

  final EstadoLote estado;

  /// El texto como vino en la planilla, antes de normalizar.
  final String? estadoOriginal;

  final Mercado? mercado;
  final int productorId;

  /// El estado no se pudo interpretar y conviene revisarlo a mano.
  bool get necesitaRevision => estado == EstadoLote.desconocido;

  factory Lote.desdeJson(Map<String, dynamic> json) => Lote(
        id: (json['id'] as num?)?.toInt() ?? 0,
        numero: json['numero'] as String?,
        extension: ExtensionLote.desde(json['extension']),
        codigo: json['codigo'] as String? ?? '',
        estado: EstadoLote.desde(json['estado']),
        estadoOriginal: json['estadoOriginal'] as String?,
        mercado: Mercado.desde(json['mercado']),
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is Lote && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Alta y edición de lotes.
///
/// `estado` va como texto libre a propósito: el backend acepta la escritura
/// original de la planilla y la normaliza él mismo al enum.
class LoteRequest {
  const LoteRequest({
    required this.productorId,
    this.numero,
    this.extension,
    this.estado,
    this.mercado,
  });

  final int productorId;
  final String? numero;
  final ExtensionLote? extension;
  final String? estado;
  final String? mercado;

  Map<String, dynamic> aJson() => {
        'productorId': productorId,
        if (numero != null) 'numero': numero,
        if (extension != null) 'extension': extension!.valor,
        if (estado != null) 'estado': estado,
        if (mercado != null) 'mercado': mercado,
      };
}
