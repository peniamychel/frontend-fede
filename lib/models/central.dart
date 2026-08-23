import 'auditoria.dart';

/// Central: agrupa sindicatos y pertenece a una federación.
class Central {
  const Central({
    required this.id,
    required this.nombre,
    required this.federacionId,
    required this.federacionNombre,
    this.abreviatura,
    this.auditoria = Auditoria.habilitado,
  });

  final int id;
  final String nombre;
  final int federacionId;
  final String federacionNombre;
  final Auditoria auditoria;

  bool get habilitado => auditoria.estado;

  /// Sigla de tres letras en mayúsculas. Única entre todas las centrales, y
  /// null mientras no se la carguen.
  final String? abreviatura;

  factory Central.desdeJson(Map<String, dynamic> json) => Central(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombre: json['nombre'] as String? ?? '',
        federacionId: (json['federacionId'] as num?)?.toInt() ?? 0,
        federacionNombre: json['federacionNombre'] as String? ?? '',
        abreviatura: json['abreviatura'] as String?,
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
    this.abreviatura,
  });

  final String nombre;
  final int federacionId;
  final String? abreviatura;

  /// La abreviatura viaja siempre, incluso en null: así se puede borrar la que
  /// tenía. Omitirla dejaría la anterior, que no es lo que pide quien vacía
  /// el campo.
  Map<String, dynamic> aJson() => {
        'nombre': nombre,
        'federacionId': federacionId,
        'abreviatura': abreviatura,
      };
}
