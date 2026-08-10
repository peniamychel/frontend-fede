import 'tenencia.dart';

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

/// Una parcela del padrón.
///
/// **Pertenece al sindicato, no al productor.** La tierra no se mueve: quien la
/// tiene puede venderla e irse a otro sindicato, y la parcela se queda donde
/// siempre estuvo. Por eso [tenedor] puede ser null —un lote sin dueño
/// registrado es una situación real, no un error— y por eso el cambio de manos
/// tiene su propio historial en vez de pisar un campo.
class Lote {
  const Lote({
    required this.id,
    required this.numero,
    required this.extension,
    required this.codigo,
    required this.estado,
    required this.estadoOriginal,
    required this.mercado,
    required this.sindicatoId,
    required this.sindicatoNombre,
    this.superficie,
    this.latitud,
    this.longitud,
    this.ubicacionActualizadaEn,
    this.tenedor,
    this.sistema,
  });

  /// Superficie en hectáreas. Null si todavía no se midió, que no es lo mismo
  /// que cero: el padrón original no trae esta columna.
  final double? superficie;

  /// Coordenadas de la parcela en grados decimales. Van juntas: media
  /// coordenada no ubica nada.
  final double? latitud;
  final double? longitud;

  final DateTime? ubicacionActualizadaEn;

  bool get tieneUbicacion => latitud != null && longitud != null;

  /// Coordenadas listas para leer. Los 7 decimales que guarda el backend son
  /// para el mapa, no para el ojo.
  String get coordenadas => tieneUbicacion
      ? '${latitud!.toStringAsFixed(6)}, ${longitud!.toStringAsFixed(6)}'
      : 'Sin ubicación';

  /// Superficie para mostrar, sin ceros de más: 12.5 ha, no 12.5000 ha.
  String get superficieTexto {
    final s = superficie;
    if (s == null) return 'Sin medir';
    final texto = s == s.roundToDouble()
        ? s.toStringAsFixed(0)
        : s.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '$texto ha';
  }

  final int id;
  final String? numero;
  final ExtensionLote? extension;

  /// Número y extensión ya juntos, tal como los arma el backend: `74-A`.
  final String codigo;

  final EstadoLote estado;

  /// El texto como vino en la planilla, antes de normalizar.
  final String? estadoOriginal;

  final Mercado? mercado;

  /// Dónde está la tierra. No cambia.
  final int sindicatoId;
  final String sindicatoNombre;

  /// Quién lo tiene hoy. Null si quedó sin tenedor.
  final Tenedor? tenedor;

  /// El sistema instalado hoy. Null si no tiene.
  final SistemaEnLote? sistema;

  bool get tieneTenedor => tenedor != null;
  bool get tieneSistema => sistema != null;

  /// El estado no se pudo interpretar y conviene revisarlo a mano.
  bool get necesitaRevision => estado == EstadoLote.desconocido;

  /// La planilla dice que tiene sistema pero no se registró cuál.
  ///
  /// No es un error: al importar el padrón, la columna "ESTADO DEL LOTE" dice
  /// si hay sistema pero no lo identifica. Es un pendiente de saneamiento.
  bool get sistemaSinIdentificar =>
      estado == EstadoLote.conSistema && sistema == null;

  factory Lote.desdeJson(Map<String, dynamic> json) => Lote(
        id: (json['id'] as num?)?.toInt() ?? 0,
        numero: json['numero'] as String?,
        extension: ExtensionLote.desde(json['extension']),
        codigo: json['codigo'] as String? ?? '',
        estado: EstadoLote.desde(json['estado']),
        estadoOriginal: json['estadoOriginal'] as String?,
        mercado: Mercado.desde(json['mercado']),
        sindicatoId: (json['sindicatoId'] as num?)?.toInt() ?? 0,
        sindicatoNombre: json['sindicatoNombre'] as String? ?? '',
        superficie: (json['superficie'] as num?)?.toDouble(),
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
        ubicacionActualizadaEn: switch (json['ubicacionActualizadaEn']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
        tenedor: switch (json['tenedor']) {
          final Map<String, dynamic> m => Tenedor.desdeJson(m),
          _ => null,
        },
        sistema: switch (json['sistema']) {
          final Map<String, dynamic> m => SistemaEnLote.desdeJson(m),
          _ => null,
        },
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
    required this.sindicatoId,
    this.productorId,
    this.numero,
    this.extension,
    this.estado,
    this.mercado,
    this.superficie,
  });

  /// Superficie en hectáreas. Null la deja sin medir.
  final double? superficie;

  /// Dónde está la tierra. Obligatorio y no cambia.
  final int sindicatoId;

  /// Quién lo tiene, si ya se sabe. Solo cuenta al crear: cambiar de tenedor
  /// es un traspaso, tiene fecha y motivo, y va por [TraspasoRequest].
  final int? productorId;

  final String? numero;
  final ExtensionLote? extension;
  final String? estado;
  final String? mercado;

  Map<String, dynamic> aJson() => {
        'sindicatoId': sindicatoId,
        if (productorId != null) 'productorId': productorId,
        if (numero != null) 'numero': numero,
        if (extension != null) 'extension': extension!.valor,
        if (estado != null) 'estado': estado,
        if (mercado != null) 'mercado': mercado,
        if (superficie != null) 'superficie': superficie,
      };
}
