import 'auditoria.dart';

/// Nivel más alto de la jerarquía: Federación › Central › Sindicato › Productor.
class Federacion {
  const Federacion({
    required this.id,
    required this.nombre,
    this.numero,
    this.auditoria = Auditoria.habilitado,
  });

  final int id;
  final String nombre;
  final Auditoria auditoria;

  /// Número que la identifica. Único entre todas, y null mientras no se lo
  /// carguen.
  final String? numero;

  bool get habilitado => auditoria.estado;

  factory Federacion.desdeJson(Map<String, dynamic> json) => Federacion(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombre: json['nombre'] as String? ?? '',
        numero: json['numero'] as String?,
        auditoria:
            Auditoria.desdeJson(json['auditoria'] as Map<String, dynamic>?),
      );

  @override
  bool operator ==(Object other) => other is Federacion && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Cuerpo de alta y edición de federaciones. El backend solo exige el nombre.
class FederacionRequest {
  const FederacionRequest({required this.nombre, this.numero});

  final String nombre;
  final String? numero;

  /// El número viaja siempre, incluso en null: así se puede borrar el que
  /// tenía. Omitirlo dejaría el anterior, que no es lo que pide quien vacía el
  /// campo.
  Map<String, dynamic> aJson() => {'nombre': nombre, 'numero': numero};
}
