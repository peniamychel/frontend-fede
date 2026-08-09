import '../core/api_client.dart';
import '../models/lote.dart';

class LoteRepository {
  const LoteRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/lotes';

  /// Lotes filtrados por productor o por sindicato. Sin filtros devuelve todos,
  /// y este listado no está paginado en el backend.
  Future<List<Lote>> listar({int? productorId, int? sindicatoId}) async {
    final datos = await _api.obtener(_ruta, query: {
      'productorId': productorId,
      'sindicatoId': sindicatoId,
    });
    return datos.comoLista.map(Lote.desdeJson).toList(growable: false);
  }

  Future<Lote> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Lote.desdeJson(datos.comoObjeto);
  }

  /// Lotes cuyo estado de origen no se pudo normalizar. Cola de revisión
  /// manual.
  Future<List<Lote>> estadoDesconocido() async {
    final datos = await _api.obtener('$_ruta/estado-desconocido');
    return datos.comoLista.map(Lote.desdeJson).toList(growable: false);
  }

  Future<Lote> crear(LoteRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Lote.desdeJson(datos.comoObjeto);
  }

  Future<Lote> actualizar(int id, LoteRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Lote.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}
