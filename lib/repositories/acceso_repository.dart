import '../core/api_client.dart';

class AccesoRepository {
  AccesoRepository(this.api);
  final ApiClient api;
  Future<void> eliminarUsuario(int id) =>
      api.eliminar('/administracion/accesos/usuarios/$id');
  Future<List<Map<String, dynamic>>> centrales() async =>
      (await api.obtener('/centrales')).comoLista;

  Future<Map<String, dynamic>> usuario(int id) async =>
      (await api.obtener('/administracion/accesos/usuarios/$id')).comoObjeto;
  Future<List<Map<String, dynamic>>> sindicatos(int centralId) async =>
      (await api.obtener('/centrales/$centralId/sindicatos')).comoLista;

  Future<List<Map<String, dynamic>>> usuarios() async =>
      (await api.obtener('/administracion/accesos/usuarios')).comoLista;
  Future<List<Map<String, dynamic>>> roles() async =>
      (await api.obtener('/administracion/accesos/roles')).comoLista;
  Future<List<Map<String, dynamic>>> permisos() async =>
      (await api.obtener('/administracion/accesos/permisos')).comoLista;

  Future<Map<String, dynamic>> crearUsuario(
    String nombre,
    List<int> roles, {
    int? centralId,
    bool todosSindicatos = true,
    List<int> sindicatoIds = const [],
    bool permisosPersonalizados = false,
    List<String> permisos = const [],
  }) async => (await api.crear('/administracion/accesos/usuarios', {
    'nombreCompleto': nombre,
    'roles': roles,
    'centralId': centralId,
    'todosSindicatos': todosSindicatos,
    'sindicatoIds': sindicatoIds,
    'permisosPersonalizados': permisosPersonalizados,
    'permisos': permisos,
  })).comoObjeto;

  Future<void> editarUsuario(
    int id,
    String nombre,
    List<int> roles,
    bool activo, {
    int? centralId,
    bool todosSindicatos = true,
    List<int> sindicatoIds = const [],
    bool permisosPersonalizados = false,
    List<String> permisos = const [],
  }) async {
    await api.reemplazar('/administracion/accesos/usuarios/$id', {
      'nombreCompleto': nombre,
      'roles': roles,
      'activo': activo,
      'centralId': centralId,
      'todosSindicatos': todosSindicatos,
      'sindicatoIds': sindicatoIds,
      'permisosPersonalizados': permisosPersonalizados,
      'permisos': permisos,
    });
  }

  Future<String> regenerarCodigo(int id) async =>
      ((await api.crear(
            '/administracion/accesos/usuarios/$id/codigo',
            const {},
          )).comoObjeto['codigoAcceso']
          as String);

  Future<String> establecerCodigo(int id, String codigo) async =>
      ((await api.crear('/administracion/accesos/usuarios/$id/codigo-manual', {
            'codigoAcceso': codigo,
          })).comoObjeto['codigoAcceso']
          as String);

  Future<void> editarRol(
    int id,
    String nombre,
    String? descripcion,
    List<String> permisos,
    bool activo,
  ) async {
    await api.reemplazar('/administracion/accesos/roles/$id', {
      'nombre': nombre,
      'descripcion': descripcion,
      'permisos': permisos,
      'activo': activo,
    });
  }

  Future<void> crearRol(
    String nombre,
    String? descripcion,
    List<String> permisos,
  ) async {
    await api.crear('/administracion/accesos/roles', {
      'nombre': nombre,
      'descripcion': descripcion,
      'permisos': permisos,
      'activo': true,
    });
  }
}
