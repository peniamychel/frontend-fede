import 'auditoria.dart';
import 'cargo.dart';

/// Los cuatro tipos de reunión, con quién los convoca y a quién convocan.
///
/// Lo que cambia entre uno y otro es la lista de convocados, y de eso depende
/// todo: pasar lista es contrastar un carnet contra esa lista.
enum TipoReunion {
  sindicato(
    'SINDICATO',
    Ambito.sindicato,
    'Reunión de sindicato',
    'Asisten los productores del sindicato.',
    false,
  ),
  ampliado(
    'AMPLIADO',
    Ambito.central,
    'Ampliado de central',
    'Asisten todos los productores de los sindicatos de la central.',
    false,
  ),
  dirigentesCentral(
    'DIRIGENTES_CENTRAL',
    Ambito.central,
    'Dirigentes de la central',
    'Asisten los presidentes y secretarios de los sindicatos de la central.',
    true,
  ),
  dirigentesFederacion(
    'DIRIGENTES_FEDERACION',
    Ambito.federacion,
    'Dirigentes de la federación',
    'Asisten los presidentes y secretarios de las centrales y de los sindicatos.',
    true,
  );

  const TipoReunion(
      this.valor, this.convoca, this.etiqueta, this.detalle, this.soloDirigentes);

  final String valor;

  /// Qué nivel la convoca. Determina qué se elige al crearla.
  final Ambito convoca;
  final String etiqueta;
  final String detalle;

  /// Si convoca solo a quienes ocupan un cargo.
  final bool soloDirigentes;

  static TipoReunion? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final t in values) {
      if (t.valor == texto) return t;
    }
    return null;
  }
}

/// Una reunión convocada, con el recuento de la lista.
class Reunion {
  const Reunion({
    required this.id,
    required this.tipo,
    required this.convocanteId,
    required this.convocanteNombre,
    required this.titulo,
    required this.fecha,
    required this.cerrada,
    required this.convocados,
    required this.presentes,
    this.lugar,
    this.observaciones,
    this.auditoria = Auditoria.habilitado,
  });

  final int id;
  final TipoReunion tipo;
  final int convocanteId;
  final String convocanteNombre;
  final String titulo;
  final DateTime fecha;

  /// Una lista cerrada ya no admite más asistencias.
  final bool cerrada;

  final int convocados;
  final int presentes;
  final String? lugar;
  final String? observaciones;
  final Auditoria auditoria;

  /// Cuántos faltan. Nunca negativo.
  int get ausentes => convocados - presentes > 0 ? convocados - presentes : 0;

  /// Fracción presente, entre 0 y 1. Cero si no hay convocados.
  double get avance => convocados == 0 ? 0 : presentes / convocados;

  String get fechaCorta {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
  }

  factory Reunion.desdeJson(Map<String, dynamic> json) => Reunion(
        id: (json['id'] as num?)?.toInt() ?? 0,
        tipo: TipoReunion.desde(json['tipo']) ?? TipoReunion.sindicato,
        convocanteId: (json['convocanteId'] as num?)?.toInt() ?? 0,
        convocanteNombre: json['convocanteNombre'] as String? ?? '',
        titulo: json['titulo'] as String? ?? '',
        fecha: DateTime.tryParse('${json['fecha']}') ?? DateTime(1970),
        cerrada: json['cerrada'] as bool? ?? false,
        convocados: (json['convocados'] as num?)?.toInt() ?? 0,
        presentes: (json['presentes'] as num?)?.toInt() ?? 0,
        lugar: json['lugar'] as String?,
        observaciones: json['observaciones'] as String?,
        auditoria:
            Auditoria.desdeJson(json['auditoria'] as Map<String, dynamic>?),
      );
}

class ReunionRequest {
  const ReunionRequest({
    required this.tipo,
    required this.convocanteId,
    required this.titulo,
    required this.fecha,
    this.lugar,
    this.observaciones,
  });

  final TipoReunion tipo;
  final int convocanteId;
  final String titulo;
  final DateTime fecha;
  final String? lugar;
  final String? observaciones;

  Map<String, dynamic> aJson() => {
        'tipo': tipo.valor,
        'convocanteId': convocanteId,
        'titulo': titulo,
        'fecha': '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}',
        'lugar': lugar,
        'observaciones': observaciones,
      };
}

/// Una línea de la lista: alguien convocado, presente o no.
class Convocado {
  const Convocado({
    required this.productorId,
    required this.nombre,
    required this.sindicato,
    required this.presente,
    this.ci,
    this.cargo,
    this.registradaEn,
  });

  final int productorId;
  final String nombre;
  final String sindicato;
  final bool presente;
  final String? ci;

  /// Por qué está convocado, si es por un cargo. Null si asiste como afiliado.
  final String? cargo;

  final DateTime? registradaEn;

  String? get horaLlegada {
    final h = registradaEn;
    if (h == null) return null;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(h.hour)}:${dos(h.minute)}';
  }

  factory Convocado.desdeJson(Map<String, dynamic> json) => Convocado(
        productorId: (json['productorId'] as num?)?.toInt() ?? 0,
        nombre: json['nombre'] as String? ?? '',
        sindicato: json['sindicato'] as String? ?? '',
        presente: json['presente'] as bool? ?? false,
        ci: json['ci'] as String?,
        cargo: json['cargo'] as String?,
        registradaEn: switch (json['registradaEn']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
      );
}

/// Lo que devuelve escanear un carnet.
class RegistroAsistencia {
  const RegistroAsistencia({
    required this.repetido,
    required this.mensaje,
    required this.persona,
    required this.presentes,
    required this.convocados,
  });

  /// True si ya estaba registrado. No es un error: quien pasa lista escanea de
  /// nuevo por las dudas y necesita que se lo confirmen.
  final bool repetido;

  final String mensaje;
  final Convocado persona;
  final int presentes;
  final int convocados;

  factory RegistroAsistencia.desdeJson(Map<String, dynamic> json) =>
      RegistroAsistencia(
        repetido: json['resultado'] == 'REPETIDO',
        mensaje: json['mensaje'] as String? ?? '',
        persona: Convocado.desdeJson(
            (json['persona'] as Map<String, dynamic>?) ?? const {}),
        presentes: (json['presentes'] as num?)?.toInt() ?? 0,
        convocados: (json['convocados'] as num?)?.toInt() ?? 0,
      );
}
