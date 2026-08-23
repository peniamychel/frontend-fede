class Sesion {
  const Sesion({
    required this.token,
    required this.usuario,
    required this.nombreCompleto,
    required this.rol,
    required this.expiraEn,
  });

  final String token;
  final String usuario;
  final String nombreCompleto;
  final String rol;
  final DateTime expiraEn;

  bool get esAdministrador => rol == 'ADMIN';
  bool get expirada => DateTime.now().isAfter(expiraEn);

  factory Sesion.desdeLogin(Map<String, dynamic> json) {
    final duracion = (json['duracionSegundos'] as num?)?.toInt() ?? 0;
    return Sesion(
      token: json['token'] as String,
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String? ?? '',
      rol: json['rol'] as String? ?? '',
      expiraEn: DateTime.now().add(Duration(seconds: duracion)),
    );
  }

  factory Sesion.desdeJson(Map<String, dynamic> json) => Sesion(
    token: json['token'] as String,
    usuario: json['usuario'] as String,
    nombreCompleto: json['nombreCompleto'] as String? ?? '',
    rol: json['rol'] as String? ?? '',
    expiraEn: DateTime.parse(json['expiraEn'] as String),
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'usuario': usuario,
    'nombreCompleto': nombreCompleto,
    'rol': rol,
    'expiraEn': expiraEn.toIso8601String(),
  };
}
