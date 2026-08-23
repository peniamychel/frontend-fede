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
    'Asisten los Secretarios Generales y Secretarios Relaciones de los sindicatos de la central.',
    true,
  ),
  dirigentesFederacion(
    'DIRIGENTES_FEDERACION',
    Ambito.federacion,
    'Dirigentes de la federación',
    'Asisten los Secretarios Generales y Secretarios Relaciones de centrales y sindicatos.',
    true,
  );

  const TipoReunion(
    this.valor,
    this.convoca,
    this.etiqueta,
    this.detalle,
    this.soloDirigentes,
  );

  final String valor;

  /// Qué nivel la convoca. Determina qué se elige al crearla.
  final Ambito convoca;
  final String etiqueta;
  final String detalle;

  /// Si convoca solo a quienes ocupan un cargo.
  final bool soloDirigentes;

  /// Para las solapas, donde entran cuatro al lado del otro y el número.
  ///
  /// «Reunión de sindicato» dice lo mismo que «Sindicato» cuando ya se está
  /// mirando la lista de reuniones, y ocupa el doble.
  String get etiquetaCorta => switch (this) {
    TipoReunion.sindicato => 'Sindicato',
    TipoReunion.ampliado => 'Ampliado',
    TipoReunion.dirigentesCentral => 'Dirigentes central',
    TipoReunion.dirigentesFederacion => 'Dirigentes federación',
  };

  static TipoReunion? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final t in values) {
      if (t.valor == texto) return t;
    }
    return null;
  }
}

/// Una hoja del acta.
///
/// El acta casi nunca es un solo archivo: lo habitual es el cuaderno de actas
/// fotografiado hoja por hoja con el teléfono, ahí mismo en la asamblea. El
/// [orden] conserva la secuencia, que sin él son fotos sueltas.
class HojaActa {
  const HojaActa({
    required this.id,
    required this.orden,
    required this.nombre,
    required this.tipoMime,
    required this.tamanoBytes,
  });

  final int id;
  final int orden;
  final String nombre;
  final String tipoMime;
  final int tamanoBytes;

  bool get esPdf => tipoMime == 'application/pdf';

  /// El peso en la unidad que se lee de un vistazo.
  String get pesoLegible {
    if (tamanoBytes < 1024) return '$tamanoBytes B';
    if (tamanoBytes < 1024 * 1024) {
      return '${(tamanoBytes / 1024).round()} KB';
    }
    return '${(tamanoBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  factory HojaActa.desdeJson(Map<String, dynamic> json) => HojaActa(
    id: (json['id'] as num?)?.toInt() ?? 0,
    orden: (json['orden'] as num?)?.toInt() ?? 0,
    nombre: json['nombre'] as String? ?? 'hoja',
    tipoMime: json['tipoMime'] as String? ?? '',
    tamanoBytes: (json['tamanoBytes'] as num?)?.toInt() ?? 0,
  );
}

/// Una vuelta de lista dentro de una reunión.
///
/// En una asamblea se llama lista más de una vez: al empezar, más tarde para
/// los que llegaron con retraso, y a veces al final. Cada vuelta tiene su
/// propia lista de presentes, y mezclarlas perdería justo lo que se quiere
/// saber: quién estuvo en qué momento.
class LlamadaLista {
  const LlamadaLista({
    required this.id,
    required this.reunionId,
    required this.numero,
    required this.etiqueta,
    required this.abierta,
    required this.presentes,
    this.cerradaEn,
    this.nota,
  });

  final int id;
  final int reunionId;
  final int numero;

  /// "Primera llamada", "Segunda llamada"… como se dice en la asamblea.
  final String etiqueta;

  final bool abierta;
  final int presentes;
  final DateTime? cerradaEn;
  final String? nota;

  String? get horaCierre {
    final h = cerradaEn;
    if (h == null) return null;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(h.hour)}:${dos(h.minute)}';
  }

  factory LlamadaLista.desdeJson(Map<String, dynamic> json) => LlamadaLista(
    id: (json['id'] as num?)?.toInt() ?? 0,
    reunionId: (json['reunionId'] as num?)?.toInt() ?? 0,
    numero: (json['numero'] as num?)?.toInt() ?? 0,
    etiqueta: json['etiqueta'] as String? ?? 'Llamada',
    abierta: json['abierta'] as bool? ?? false,
    presentes: (json['presentes'] as num?)?.toInt() ?? 0,
    cerradaEn: switch (json['cerradaEn']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    nota: json['nota'] as String?,
  );
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
    this.tieneActa = false,
    this.codigoActa,
    this.vetosHabilitados = false,
    this.hojasActa = const [],
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

  /// Si el acta ya está cargada, aunque sea una sola hoja. Sin ella no se
  /// pueden decidir vetos: el acta es lo que respalda lo que ahí se decidió.
  final bool tieneActa;

  /// El número del acta en el libro del sindicato, como está escrito ahí.
  ///
  /// El libro es el original; lo que se sube es una foto de una de sus hojas.
  /// Sin el número, meses después nadie puede ir al libro a cotejar. Null
  /// mientras no haya acta, y también en las que se cargaron antes de que el
  /// sistema lo pidiera.
  final String? codigoActa;

  /// Si en esta reunión se pueden decidir vetos.
  ///
  /// No toda asamblea es para sancionar: la mayoría es informativa, y ofrecer
  /// el veto en todas invita a usarlo donde no corresponde.
  final bool vetosHabilitados;

  /// Las hojas del acta, en orden.
  final List<HojaActa> hojasActa;

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
    tieneActa: json['tieneActa'] as bool? ?? false,
    codigoActa: json['codigoActa'] as String?,
    vetosHabilitados: json['vetosHabilitados'] as bool? ?? false,
    hojasActa: switch (json['hojasActa']) {
      final List<dynamic> hojas =>
        hojas
            .whereType<Map<String, dynamic>>()
            .map(HojaActa.desdeJson)
            .toList(growable: false),
      _ => const <HojaActa>[],
    },
    convocados: (json['convocados'] as num?)?.toInt() ?? 0,
    presentes: (json['presentes'] as num?)?.toInt() ?? 0,
    lugar: json['lugar'] as String?,
    observaciones: json['observaciones'] as String?,
    auditoria: Auditoria.desdeJson(json['auditoria'] as Map<String, dynamic>?),
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
    this.vetosHabilitados = false,
  });

  final TipoReunion tipo;
  final int convocanteId;
  final String titulo;
  final DateTime fecha;
  final String? lugar;
  final String? observaciones;

  /// Si en esta reunión se van a poder decidir vetos. Por omisión, no.
  final bool vetosHabilitados;

  Map<String, dynamic> aJson() => {
    'tipo': tipo.valor,
    'convocanteId': convocanteId,
    'titulo': titulo,
    'fecha':
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}',
    'lugar': lugar,
    'observaciones': observaciones,
    'vetosHabilitados': vetosHabilitados,
  };

  /// Los mismos datos de una reunión ya guardada, para editarla.
  factory ReunionRequest.desde(Reunion r, {bool? vetosHabilitados}) =>
      ReunionRequest(
        tipo: r.tipo,
        convocanteId: r.convocanteId,
        titulo: r.titulo,
        fecha: r.fecha,
        lugar: r.lugar,
        observaciones: r.observaciones,
        vetosHabilitados: vetosHabilitados ?? r.vetosHabilitados,
      );
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
          (json['persona'] as Map<String, dynamic>?) ?? const {},
        ),
        presentes: (json['presentes'] as num?)?.toInt() ?? 0,
        convocados: (json['convocados'] as num?)?.toInt() ?? 0,
      );
}
