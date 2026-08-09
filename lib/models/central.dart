import 'auditoria.dart';

/// Central: agrupa sindicatos y pertenece a una federación.
class Central {
  const Central({
    required this.id,
    required this.nombre,
    required this.federacionId,
    required this.federacionNombre,
    this.numero,
    this.auditoria = Auditoria.habilitado,
  });

  final int id;
  final String nombre;
  final int federacionId;
  final String federacionNombre;
  final Auditoria auditoria;

  bool get habilitado => auditoria.estado;

  /// Número que le asigna la federación. Único entre todas las centrales, y
  /// null mientras no se lo carguen.
  final String? numero;

  factory Central.desdeJson(Map<String, dynamic> json) => Central(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombre: json['nombre'] as String? ?? '',
        federacionId: (json['federacionId'] as num?)?.toInt() ?? 0,
        federacionNombre: json['federacionNombre'] as String? ?? '',
        numero: json['numero'] as String?,
        auditoria:
            Auditoria.desdeJson(json['auditoria'] as Map<String, dynamic>?),
      );

  @override
  bool operator ==(Object other) => other is Central && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class CentralRequest {
  const CentralRequest({
    required this.nombre,
    required this.federacionId,
    this.numero,
  });

  final String nombre;
  final int federacionId;
  final String? numero;

  /// El número viaja siempre, incluso en null: así se puede borrar el que
  /// tenía. Omitirlo dejaría el anterior, que no es lo que pide quien vacía
  /// el campo.
  Map<String, dynamic> aJson() => {
        'nombre': nombre,
        'federacionId': federacionId,
        'numero': numero,
      };
}
