/// Un productor vetado por decisión de asamblea.
///
/// Mientras el veto rige, la persona queda observada y su credencial no se
/// emite. No se la da de baja ni se la borra: sigue siendo afiliada, con su
/// parcela y su historial. Lo que pierde es el documento que la acredita.
///
/// Vetar y levantar son decisiones de reunión, y la reunión tiene que tener su
/// acta cargada: es lo que respalda la sanción.
class Veto {
  const Veto({
    required this.id,
    required this.vigente,
    required this.productorId,
    required this.productorNombre,
    required this.motivo,
    required this.desde,
    required this.reunion,
    this.ci,
    this.codigo,
    this.codigoPadron,
    this.sindicato = '',
    this.central = '',
    this.motivoLevantamiento,
    this.hasta,
    this.reunionLevanta,
  });

  final int id;

  /// Si sigue rigiendo hoy.
  final bool vigente;

  final int productorId;
  final String productorNombre;

  /// Los tres identificadores, porque así se pregunta en la práctica: alguien
  /// llega con la cédula en la mano, o con el carné, o solo dice su nombre.
  final String? ci;
  final String? codigo;
  final String? codigoPadron;

  final String sindicato;
  final String central;

  final String motivo;
  final DateTime desde;
  final ReunionBreve? reunion;

  final String? motivoLevantamiento;
  final DateTime? hasta;
  final ReunionBreve? reunionLevanta;

  String get ruta => central.isEmpty ? sindicato : '$central › $sindicato';

  factory Veto.desdeJson(Map<String, dynamic> json) => Veto(
        id: (json['id'] as num?)?.toInt() ?? 0,
        vigente: json['vigente'] as bool? ?? false,
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
        productorNombre: json['productorNombre'] as String? ?? '',
        ci: json['ci'] as String?,
        codigo: json['codigo'] as String?,
        codigoPadron: json['codigoPadron'] as String?,
        sindicato: json['sindicato'] as String? ?? '',
        central: json['central'] as String? ?? '',
        motivo: json['motivo'] as String? ?? '',
        desde: DateTime.tryParse(json['desde'] as String? ?? '') ?? DateTime.now(),
        reunion: ReunionBreve.desdeJson(json['reunion'] as Map<String, dynamic>?),
        motivoLevantamiento: json['motivoLevantamiento'] as String?,
        hasta: DateTime.tryParse(json['hasta'] as String? ?? ''),
        reunionLevanta:
            ReunionBreve.desdeJson(json['reunionLevanta'] as Map<String, dynamic>?),
      );
}

/// Lo mínimo para nombrar una reunión sin traerla entera.
class ReunionBreve {
  const ReunionBreve({
    required this.id,
    required this.titulo,
    required this.fecha,
  });

  final int id;
  final String titulo;
  final DateTime fecha;

  static ReunionBreve? desdeJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ReunionBreve(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titulo: json['titulo'] as String? ?? '',
      fecha: DateTime.tryParse(json['fecha'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Cuerpo para vetar a alguien.
class VetoRequest {
  const VetoRequest({
    required this.productorId,
    required this.reunionId,
    required this.motivo,
    this.desde,
  });

  final int productorId;
  final int reunionId;
  final String motivo;
  final DateTime? desde;

  Map<String, dynamic> aJson() => {
        'productorId': productorId,
        'reunionId': reunionId,
        'motivo': motivo,
        if (desde != null) 'desde': _soloFecha(desde!),
      };
}

/// Cuerpo para sacarlo de la lista.
class LevantarVetoRequest {
  const LevantarVetoRequest({
    required this.reunionId,
    required this.motivo,
    this.hasta,
  });

  final int reunionId;
  final String motivo;
  final DateTime? hasta;

  Map<String, dynamic> aJson() => {
        'reunionId': reunionId,
        'motivo': motivo,
        if (hasta != null) 'hasta': _soloFecha(hasta!),
      };
}

String _soloFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
