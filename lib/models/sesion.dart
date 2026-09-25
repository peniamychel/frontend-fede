class Sesion {
  const Sesion({
    required this.token,
    required this.usuario,
    required this.nombreCompleto,
    required this.rol,
    required this.roles,
    required this.permisos,
    required this.expiraEn,
    this.centralId,
  });

  final String token;
  final String usuario;
  final String nombreCompleto;
  final String rol;
  final Set<String> roles;
  final Set<String> permisos;
  final DateTime expiraEn;
  final int? centralId;

  bool get esAdministrador => centralId == null && rol == 'ADMIN';
  bool puede(String permiso) => esAdministrador || permisos.contains(permiso);
  bool get expirada => DateTime.now().isAfter(expiraEn);

  factory Sesion.desdeLogin(Map<String, dynamic> json) {
    final duracion = (json['duracionSegundos'] as num?)?.toInt() ?? 0;
    return Sesion(
      token: json['token'] as String,
      centralId: (json['centralId'] as num?)?.toInt(),
      usuario: json['usuario'] as String,
      nombreCompleto: json['nombreCompleto'] as String? ?? '',
      rol: json['rol'] as String? ?? '',
      roles: (json['roles'] as List? ?? const []).map((e) => '$e').toSet(),
      permisos: (json['permisos'] as List? ?? const [])
          .map((e) => '$e')
          .toSet(),
      expiraEn: DateTime.now().add(Duration(seconds: duracion)),
    );
  }

  factory Sesion.desdeJson(Map<String, dynamic> json) => Sesion(
    token: json['token'] as String,
    centralId: (json['centralId'] as num?)?.toInt(),
    usuario: json['usuario'] as String,
    nombreCompleto: json['nombreCompleto'] as String? ?? '',
    rol: json['rol'] as String? ?? '',
    roles: (json['roles'] as List? ?? const []).map((e) => '$e').toSet(),
    permisos: (json['permisos'] as List? ?? const []).map((e) => '$e').toSet(),
    expiraEn: DateTime.parse(json['expiraEn'] as String),
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'centralId': centralId,
    'usuario': usuario,
    'nombreCompleto': nombreCompleto,
    'rol': rol,
    'roles': roles.toList(),
    'permisos': permisos.toList(),
    'expiraEn': expiraEn.toIso8601String(),
  };

  Sesion conAutorizaciones(Map<String, dynamic> json) {
    final nuevosRoles = (json['roles'] as List? ?? const [])
        .map((e) => '$e')
        .toSet();
    return Sesion(
      token: token,
      centralId: (json['centralId'] as num?)?.toInt() == 0
          ? null
          : (json['centralId'] as num?)?.toInt(),
      usuario: usuario,
      nombreCompleto: nombreCompleto,
      rol: nuevosRoles.contains('ADMIN') ? 'ADMIN' : 'OPERADOR',
      roles: nuevosRoles,
      permisos: (json['permisos'] as List? ?? const [])
          .map((e) => '$e')
          .toSet(),
      expiraEn: expiraEn,
    );
  }
}
