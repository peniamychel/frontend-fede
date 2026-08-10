import '../core/api_client.dart';
import '../models/lote.dart';
import '../models/tenencia.dart';

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

  /// Corrige los datos de la parcela.
  ///
  /// No cambia al tenedor ni el sindicato: la tierra no se muda, y cambiar de
  /// manos es un traspaso con fecha y motivo. Para eso está [traspasar].
  Future<Lote> actualizar(int id, LoteRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Lote.desdeJson(datos.comoObjeto);
  }

  /// Pasa el lote a otro productor, o lo deja sin tenedor.
  ///
  /// El período del tenedor anterior no se borra: se cierra y queda en el
  /// historial con el motivo. Omitir `productorId` en la petición deja el lote
  /// sin tenedor.
  Future<Lote> traspasar(int id, TraspasoRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id/tenencia', request.aJson());
    return Lote.desdeJson(datos.comoObjeto);
  }

  /// Quiénes tuvieron el lote, del período más reciente al primero.
  Future<List<Tenencia>> historial(int id) async {
    final datos = await _api.obtener('$_ruta/$id/historial');
    return datos.comoLista.map(Tenencia.desdeJson).toList(growable: false);
  }

  /// Qué sistemas pasaron por el lote.
  Future<List<Tenencia>> historialDeSistemas(int id) async {
    final datos = await _api.obtener('$_ruta/$id/sistemas');
    return datos.comoLista.map(Tenencia.desdeJson).toList(growable: false);
  }

  // ---------- Ubicación ----------

  /// Los lotes de un sindicato que ya tienen punto, para dibujarlos juntos.
  Future<List<Lote>> conUbicacion(int sindicatoId) async {
    final datos = await _api
        .obtener('$_ruta/con-ubicacion', query: {'sindicatoId': sindicatoId});
    return datos.comoLista.map(Lote.desdeJson).toList(growable: false);
  }

  /// Marca o mueve el punto de la parcela. Devuelve el lote ya actualizado.
  Future<Lote> marcarUbicacion(int id, double latitud, double longitud) async {
    final datos = await _api.reemplazar('$_ruta/$id/ubicacion', {
      'latitud': latitud,
      'longitud': longitud,
    });
    return Lote.desdeJson(datos.comoObjeto);
  }

  /// Quita el punto. El lote sigue existiendo, solo deja de estar ubicado, y
  /// por eso devuelve el lote en vez de nada.
  Future<Lote> borrarUbicacion(int id) async {
    final datos = await _api.eliminarConRespuesta('$_ruta/$id/ubicacion');
    return Lote.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}

/// Sistemas: el agregado que un lote puede tener, y que se traslada.
class SistemaRepository {
  const SistemaRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/sistemas';

  /// Los dos filtros son excluyentes: [disponibles] son los que no están en
  /// ningún lote, y [sindicatoId] acota a los instalados en ese sindicato.
  Future<List<Sistema>> listar({bool disponibles = false, int? sindicatoId}) async {
    final datos = await _api.obtener(_ruta, query: {
      if (disponibles) 'disponibles': true,
      'sindicatoId': sindicatoId,
    });
    return datos.comoLista.map(Sistema.desdeJson).toList(growable: false);
  }

  Future<Sistema> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Sistema.desdeJson(datos.comoObjeto);
  }

  /// Por dónde pasó el sistema, del período más reciente al primero.
  Future<List<Tenencia>> historial(int id) async {
    final datos = await _api.obtener('$_ruta/$id/historial');
    return datos.comoLista.map(Tenencia.desdeJson).toList(growable: false);
  }

  Future<Sistema> crear(SistemaRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Sistema.desdeJson(datos.comoObjeto);
  }

  Future<Sistema> actualizar(int id, SistemaRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Sistema.desdeJson(datos.comoObjeto);
  }

  /// Instala el sistema en un lote, o lo retira si [loteId] va en null.
  Future<Sistema> trasladar(int id, int? loteId, TraspasoRequest request) async {
    final datos = await _api.reemplazar(
      '$_ruta/$id/traslado',
      request.aJson(),
      query: {'loteId': loteId},
    );
    return Sistema.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}
