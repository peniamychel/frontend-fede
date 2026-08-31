import 'auditoria.dart';

/// Sindicato: agrupa productores y pertenece a una central.
class Sindicato {
  const Sindicato({
    required this.id,
    required this.nombre,
    required this.centralId,
    required this.centralNombre,
    this.numero,
    this.latitud,
    this.longitud,
    this.ubicacionActualizadaEn,
    this.totalProductores,
    this.porcentajeImpresion,
    this.auditoria = Auditoria.habilitado,
  });

  final Auditoria auditoria;

  bool get habilitado => auditoria.estado;

  final int id;
  final String nombre;
  final int centralId;
  final String centralNombre;

  /// Número que le asigna la federación. Único entre todos los sindicatos, y
  /// null mientras no se lo carguen.
  final String? numero;

  /// Coordenadas de la sede en grados decimales. Null mientras no se marque
  /// en el mapa. Van juntas: media coordenada no ubica nada.
  final double? latitud;
  final double? longitud;

  final DateTime? ubicacionActualizadaEn;

  /// Resumen opcional que se completa al mostrar la jerarquía de una central.
  /// No forma parte de los datos editables del sindicato.
  final int? totalProductores;
  final double? porcentajeImpresion;

  bool get tieneUbicacion => latitud != null && longitud != null;

  /// Coordenadas listas para mostrar, con la precisión que tiene sentido leer.
  /// Los 7 decimales que guarda el backend son para el mapa, no para el ojo.
  String get coordenadas => tieneUbicacion
      ? '${latitud!.toStringAsFixed(6)}, ${longitud!.toStringAsFixed(6)}'
      : 'Sin ubicación';

  factory Sindicato.desdeJson(Map<String, dynamic> json) => Sindicato(
    id: (json['id'] as num?)?.toInt() ?? 0,
    nombre: json['nombre'] as String? ?? '',
    centralId: (json['centralId'] as num?)?.toInt() ?? 0,
    centralNombre: json['centralNombre'] as String? ?? '',
    numero: json['numero'] as String?,
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
    ubicacionActualizadaEn: switch (json['ubicacionActualizadaEn']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    totalProductores: (json['totalProductores'] as num?)?.toInt(),
    porcentajeImpresion: (json['porcentajeImpresion'] as num?)?.toDouble(),
    auditoria: Auditoria.desdeJson(json['auditoria'] as Map<String, dynamic>?),
  );

  Sindicato conResumenImpresion({
    required int totalProductores,
    required double porcentajeImpresion,
  }) => Sindicato(
    id: id,
    nombre: nombre,
    centralId: centralId,
    centralNombre: centralNombre,
    numero: numero,
    latitud: latitud,
    longitud: longitud,
    ubicacionActualizadaEn: ubicacionActualizadaEn,
    totalProductores: totalProductores,
    porcentajeImpresion: porcentajeImpresion,
    auditoria: auditoria,
  );

  @override
  bool operator ==(Object other) => other is Sindicato && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class SindicatoRequest {
  const SindicatoRequest({
    required this.nombre,
    required this.centralId,
    this.numero,
  });

  final String nombre;
  final int centralId;
  final String? numero;

  /// El número viaja siempre, incluso en null: así se puede borrar el que
  /// tenía. Omitirlo dejaría el anterior, que no es lo que pide quien vacía
  /// el campo.
  Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'centralId': centralId,
    'numero': numero,
  };
}
