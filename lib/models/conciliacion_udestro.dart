import '../core/pagina.dart';
import 'importacion.dart';
import 'lote.dart';

enum EstadoConciliacionUdestro {
  borrador('BORRADOR'),
  aplicada('APLICADA');

  const EstadoConciliacionUdestro(this.valor);
  final String valor;

  static EstadoConciliacionUdestro desde(Object? valor) =>
      valor == 'APLICADA' ? aplicada : borrador;
}

enum AccionConciliacionUdestro {
  altaSistema('ALTA_SISTEMA', 'Altas con sistema'),
  cambiarASistema('CAMBIAR_A_SISTEMA', 'Cambios a sistema'),
  observarYCambiarASistema(
    'OBSERVAR_Y_CAMBIAR_A_SISTEMA',
    'Observados por identidad',
  ),
  cambiarABlanco('CAMBIAR_A_BLANCO', 'Cambios a blanco'),
  conservar('CONSERVAR', 'Sin cambios'),
  conflictoIdentidad('CONFLICTO_IDENTIDAD', 'Conflictos de identidad'),
  error('ERROR', 'Errores');

  const AccionConciliacionUdestro(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  static AccionConciliacionUdestro desde(Object? valor) =>
      values.firstWhere((e) => e.valor == valor, orElse: () => error);
}

enum DecisionConflictoUdestro {
  pendiente('PENDIENTE'),
  mismaPersona('MISMA_PERSONA'),
  personasDistintas('PERSONAS_DISTINTAS');

  const DecisionConflictoUdestro(this.valor);
  final String valor;

  static DecisionConflictoUdestro desde(Object? valor) =>
      values.firstWhere((e) => e.valor == valor, orElse: () => pendiente);
}

class CandidatoUdestro {
  const CandidatoUdestro({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.nombreCompleto,
    required this.ci,
    required this.central,
    required this.sindicato,
    this.clasificacion,
    this.fotoUrl,
  });

  final int id;
  final String nombres;
  final String apellidos;
  final String nombreCompleto;
  final String ci;
  final String central;
  final String sindicato;
  final EstadoLote? clasificacion;
  final String? fotoUrl;

  factory CandidatoUdestro.desdeJson(Map<String, dynamic> json) =>
      CandidatoUdestro(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombres: json['nombres'] as String? ?? '',
        apellidos: json['apellidos'] as String? ?? '',
        nombreCompleto: json['nombreCompleto'] as String? ?? '',
        ci: json['ci'] as String? ?? '',
        central: json['central'] as String? ?? '',
        sindicato: json['sindicato'] as String? ?? '',
        clasificacion: json['clasificacion'] == null
            ? null
            : EstadoLote.desde(json['clasificacion']),
        fotoUrl: json['fotoUrl'] as String?,
      );
}

class FilaConciliacionUdestro {
  const FilaConciliacionUdestro({
    required this.id,
    required this.numeroFila,
    required this.central,
    required this.sindicato,
    required this.nombres,
    required this.apellidos,
    required this.ci,
    required this.sindicatoNuevo,
    required this.accion,
    required this.motivo,
    required this.productorId,
    required this.clasificacionAnterior,
    required this.similitudNombre,
    required this.decision,
    required this.productorSeleccionadoId,
    required this.candidatos,
  });

  final int id;
  final int? numeroFila;
  final String central;
  final String sindicato;
  final String nombres;
  final String apellidos;
  final String ci;
  final bool sindicatoNuevo;
  final AccionConciliacionUdestro accion;
  final String motivo;
  final int? productorId;
  final EstadoLote? clasificacionAnterior;
  final int? similitudNombre;
  final DecisionConflictoUdestro decision;
  final int? productorSeleccionadoId;
  final List<CandidatoUdestro> candidatos;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory FilaConciliacionUdestro.desdeJson(Map<String, dynamic> json) =>
      FilaConciliacionUdestro(
        id: (json['id'] as num?)?.toInt() ?? 0,
        numeroFila: (json['numeroFila'] as num?)?.toInt(),
        central: json['central'] as String? ?? '',
        sindicato: json['sindicato'] as String? ?? '',
        nombres: json['nombresUdestro'] as String? ?? '',
        apellidos: json['apellidosUdestro'] as String? ?? '',
        ci: json['ci'] as String? ?? '',
        sindicatoNuevo: json['sindicatoNuevo'] as bool? ?? false,
        accion: AccionConciliacionUdestro.desde(json['accion']),
        motivo: json['motivo'] as String? ?? '',
        productorId: (json['productorId'] as num?)?.toInt(),
        clasificacionAnterior: json['clasificacionAnterior'] == null
            ? null
            : EstadoLote.desde(json['clasificacionAnterior']),
        similitudNombre: (json['similitudNombre'] as num?)?.toInt(),
        decision: DecisionConflictoUdestro.desde(json['decision']),
        productorSeleccionadoId: (json['productorSeleccionadoId'] as num?)
            ?.toInt(),
        candidatos: switch (json['candidatos']) {
          final List<dynamic> l =>
            l
                .whereType<Map<String, dynamic>>()
                .map(CandidatoUdestro.desdeJson)
                .toList(growable: false),
          _ => const [],
        },
      );
}

class ConciliacionUdestro {
  const ConciliacionUdestro({
    required this.id,
    required this.estado,
    required this.archivo,
    required this.sha256,
    required this.federacionId,
    required this.federacion,
    required this.filasExcel,
    required this.altasSistema,
    required this.cambiosASistema,
    required this.observadosPorIdentidad,
    required this.cambiosABlanco,
    required this.conservados,
    required this.conflictos,
    required this.conflictosPendientes,
    required this.errores,
    required this.sindicatosNuevos,
    required this.listaParaAplicar,
    required this.creadaEn,
    required this.aplicadaEn,
  });

  final int id;
  final EstadoConciliacionUdestro estado;
  final String archivo;
  final String sha256;
  final int federacionId;
  final String federacion;
  final int filasExcel;
  final int altasSistema;
  final int cambiosASistema;
  final int observadosPorIdentidad;
  final int cambiosABlanco;
  final int conservados;
  final int conflictos;
  final int conflictosPendientes;
  final int errores;
  final List<SindicatoNuevo> sindicatosNuevos;
  final bool listaParaAplicar;
  final DateTime? creadaEn;
  final DateTime? aplicadaEn;

  int get cambiosTotales =>
      altasSistema + cambiosASistema + observadosPorIdentidad + cambiosABlanco;

  factory ConciliacionUdestro.desdeJson(Map<String, dynamic> json) =>
      ConciliacionUdestro(
        id: (json['id'] as num?)?.toInt() ?? 0,
        estado: EstadoConciliacionUdestro.desde(json['estado']),
        archivo: json['archivo'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
        federacionId: (json['federacionId'] as num?)?.toInt() ?? 0,
        federacion: json['federacion'] as String? ?? '',
        filasExcel: (json['filasExcel'] as num?)?.toInt() ?? 0,
        altasSistema: (json['altasSistema'] as num?)?.toInt() ?? 0,
        cambiosASistema: (json['cambiosASistema'] as num?)?.toInt() ?? 0,
        observadosPorIdentidad:
            (json['observadosPorIdentidad'] as num?)?.toInt() ?? 0,
        cambiosABlanco: (json['cambiosABlanco'] as num?)?.toInt() ?? 0,
        conservados: (json['conservados'] as num?)?.toInt() ?? 0,
        conflictos: (json['conflictos'] as num?)?.toInt() ?? 0,
        conflictosPendientes:
            (json['conflictosPendientes'] as num?)?.toInt() ?? 0,
        errores: (json['errores'] as num?)?.toInt() ?? 0,
        sindicatosNuevos: switch (json['sindicatosNuevos']) {
          final List<dynamic> l =>
            l
                .whereType<Map<String, dynamic>>()
                .map(SindicatoNuevo.desdeJson)
                .toList(growable: false),
          _ => const [],
        },
        listaParaAplicar: json['listaParaAplicar'] as bool? ?? false,
        creadaEn: DateTime.tryParse(json['creadaEn'] as String? ?? ''),
        aplicadaEn: DateTime.tryParse(json['aplicadaEn'] as String? ?? ''),
      );
}

Pagina<FilaConciliacionUdestro> paginaFilasUdestro(Map<String, dynamic> json) =>
    Pagina.desdeJson(json, FilaConciliacionUdestro.desdeJson);
