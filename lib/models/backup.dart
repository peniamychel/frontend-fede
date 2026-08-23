enum TipoBackup { manual, automatico }

enum EstadoBackup { enProceso, completado, fallido }

class Backup {
  const Backup({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.iniciadoEn,
    this.finalizadoEn,
    required this.archivo,
    this.tamanoBytes,
    this.sha256,
    required this.baseDatos,
    required this.solicitadoPor,
    this.versionMariaDb,
    this.error,
  });

  final String id;
  final TipoBackup tipo;
  final EstadoBackup estado;
  final DateTime iniciadoEn;
  final DateTime? finalizadoEn;
  final String archivo;
  final int? tamanoBytes;
  final String? sha256;
  final String baseDatos;
  final String solicitadoPor;
  final String? versionMariaDb;
  final String? error;

  bool get enProceso => estado == EstadoBackup.enProceso;
  bool get completado => estado == EstadoBackup.completado;

  factory Backup.desdeJson(Map<String, dynamic> json) => Backup(
    id: json['id'] as String,
    tipo: switch (json['tipo']) {
      'AUTOMATICO' => TipoBackup.automatico,
      _ => TipoBackup.manual,
    },
    estado: switch (json['estado']) {
      'COMPLETADO' => EstadoBackup.completado,
      'FALLIDO' => EstadoBackup.fallido,
      _ => EstadoBackup.enProceso,
    },
    iniciadoEn: DateTime.parse(json['iniciadoEn'] as String).toLocal(),
    finalizadoEn: json['finalizadoEn'] == null
        ? null
        : DateTime.parse(json['finalizadoEn'] as String).toLocal(),
    archivo: json['archivo'] as String,
    tamanoBytes: (json['tamanoBytes'] as num?)?.toInt(),
    sha256: json['sha256'] as String?,
    baseDatos: json['baseDatos'] as String,
    solicitadoPor: json['solicitadoPor'] as String,
    versionMariaDb: json['versionMariaDb'] as String?,
    error: json['error'] as String?,
  );
}
