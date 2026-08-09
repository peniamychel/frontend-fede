import '../core/api_client.dart';
import '../core/pagina.dart';
import '../models/observacion.dart';

class ObservacionRepository {
  const ObservacionRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/observaciones';

  /// Listado paginado de observaciones. Los filtros son combinables:
  /// [soloPendientes] deja fuera las ya resueltas, y [texto] busca en el
  /// mensaje.
  Future<Pagina<Observacion>> listar({
    int? productorId,
    int? sindicatoId,
    int? centralId,
    bool? soloPendientes,
    String? texto,
    Paginacion paginacion = const Paginacion(),
  }) async {
    final datos = await _api.obtener(_ruta, query: {
      'productorId': productorId,
      'sindicatoId': sindicatoId,
      'centralId': centralId,
      'soloPendientes': soloPendientes,
      'texto': texto,
      ...paginacion.query,
    });
    return Pagina.desdeJson(datos.comoObjeto, Observacion.desdeJson);
  }

  Future<Observacion> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Observacion.desdeJson(datos.comoObjeto);
  }

  /// Cuántas observaciones siguen sin resolver. Sirve para el contador del
  /// panel.
  Future<int> totalPendientes() async {
    final datos = await _api.obtener('$_ruta/pendientes/total');
    if (datos is num) return datos.toInt();
    return int.tryParse('$datos') ?? 0;
  }

  Future<Observacion> crear(ObservacionRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Observacion.desdeJson(datos.comoObjeto);
  }

  Future<Observacion> actualizar(int id, ObservacionRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Observacion.desdeJson(datos.comoObjeto);
  }

  Future<Observacion> resolver(int id) async {
    final datos = await _api.parchear('$_ruta/$id/resolver');
    return Observacion.desdeJson(datos.comoObjeto);
  }

  Future<Observacion> reabrir(int id) async {
    final datos = await _api.parchear('$_ruta/$id/reabrir');
    return Observacion.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}
