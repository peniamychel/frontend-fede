import 'auditoria.dart';

/// Nivel más alto de la jerarquía: Federación › Central › Sindicato › Productor.
class Federacion {
  const Federacion({
    required this.id,
    required this.nombre,
    this.auditoria = Auditoria.habilitado,
  });

  final int id;
  final String nombre;
  final Auditoria auditoria;

  bool get habilitado => auditoria.estado;

  factory Federacion.desdeJson(Map<String, dynamic> json) => Federacion(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombre: json['nombre'] as String? ?? '',
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
  const FederacionRequest({required this.nombre});

  final String nombre;

  Map<String, dynamic> aJson() => {'nombre': nombre};
}
