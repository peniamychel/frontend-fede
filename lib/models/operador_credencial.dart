import 'credencial_previa.dart';

/// Identidad para una credencial de operador; no representa una cuenta de acceso.
class OperadorCredencial {
  const OperadorCredencial({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.ci,
    required this.cargo,
    required this.telefono,
    this.fotoUrl,
  });

  final int id;
  final String nombres;
  final String apellidos;
  final String ci;
  final String cargo;
  final String telefono;
  final String? fotoUrl;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory OperadorCredencial.desdeJson(Map<String, dynamic> json) =>
      OperadorCredencial(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombres: json['nombres'] as String? ?? '',
        apellidos: json['apellidos'] as String? ?? '',
        ci: json['ci'] as String? ?? '',
        cargo: json['cargo'] as String? ?? '',
        telefono: json['telefono'] as String? ?? '',
        fotoUrl: json['fotoUrl'] as String?,
      );

  Map<String, dynamic> aJson() => {
    'nombres': nombres.trim(),
    'apellidos': apellidos.trim(),
    'ci': ci.trim(),
    'cargo': cargo.trim(),
    'telefono': telefono.trim(),
  };
}

class OperadorCredencialPrevia {
  const OperadorCredencialPrevia({
    required this.operador,
    required this.resena,
    required this.federacion,
    this.ejecutivo,
  });

  final OperadorCredencial operador;
  final String resena;
  final String federacion;
  final FirmantePrevio? ejecutivo;

  factory OperadorCredencialPrevia.desdeJson(Map<String, dynamic> json) =>
      OperadorCredencialPrevia(
        operador: OperadorCredencial.desdeJson(json),
        resena: json['resena'] as String? ?? '',
        federacion: json['federacion'] as String? ?? '',
        ejecutivo: FirmantePrevio.desdeJson(
          json['ejecutivo'] as Map<String, dynamic>?,
        ),
      );

  /// Reutiliza el lienzo de diseño, sin mezclar los registros del padrón.
  CredencialPrevia get tarjeta => CredencialPrevia(
    productorId: operador.id,
    nombreCompleto: operador.nombreCompleto,
    federacion: federacion,
    central: '',
    sindicato: '',
    nombres: operador.nombres,
    apellidos: operador.apellidos,
    ci: operador.ci,
    lotes: '',
    codigoQr: '',
    faltantes: const [],
    completa: true,
    fotoUrl: operador.fotoUrl,
    ejecutivoFederacion: ejecutivo,
  );

  Map<String, String> get valores => {
    'CARGO': operador.cargo,
    'TELEFONO': operador.telefono,
    'RESENA': resena,
  };
}
