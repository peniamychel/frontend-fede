import '../core/api_client.dart';
import '../models/central.dart';
import '../models/sindicato.dart';

class CentralRepository {
  const CentralRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/centrales';

  /// Todas las centrales, o solo las de una federación si se pasa
  /// [federacionId].
  Future<List<Central>> listar({int? federacionId}) async {
    final datos = await _api.obtener(_ruta, query: {'federacionId': federacionId});
    return datos.comoLista.map(Central.desdeJson).toList(growable: false);
  }

  Future<Central> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Central.desdeJson(datos.comoObjeto);
  }

  /// Sindicatos que cuelgan de una central.
  Future<List<Sindicato>> sindicatos(int id) async {
    final datos = await _api.obtener('$_ruta/$id/sindicatos');
    return datos.comoLista.map(Sindicato.desdeJson).toList(growable: false);
  }

  Future<Central> crear(CentralRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Central.desdeJson(datos.comoObjeto);
  }

  /// Habilita o deshabilita el registro.
  ///
  /// Deshabilitar no borra: la fila queda entera y se puede volver a
  /// habilitar. Es la salida para lo que el backend no deja eliminar por
  /// tener registros dependientes.
  Future<Central> cambiarEstado(int id, bool estado) async {
    final datos = await _api
        .parchear('$_ruta/$id/estado', cuerpo: {'estado': estado});
    return Central.desdeJson(datos.comoObjeto);
  }

  Future<Central> actualizar(int id, CentralRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Central.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}
