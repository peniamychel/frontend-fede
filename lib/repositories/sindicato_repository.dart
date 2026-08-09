import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/sindicato.dart';

class SindicatoRepository {
  const SindicatoRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/sindicatos';

  /// Todos los sindicatos, o solo los de una central si se pasa [centralId].
  Future<List<Sindicato>> listar({int? centralId}) async {
    final datos = await _api.obtener(_ruta, query: {'centralId': centralId});
    return datos.comoLista.map(Sindicato.desdeJson).toList(growable: false);
  }

  Future<Sindicato> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Sindicato.desdeJson(datos.comoObjeto);
  }

  /// Dirección del informe en PDF: la nómina del sindicato lista para imprimir.
  ///
  /// Se devuelve la URL en vez de los bytes porque el backend marca el archivo
  /// como adjunto, y así el navegador o el sistema lo guardan solos, igual que
  /// la plantilla de importación.
  Uri urlInforme(int id) => ApiConfig.uri('$_ruta/$id/informe.pdf');

  /// Dirección del pliego de credenciales: las de todos sus productores, en
  /// hojas carta listas para imprimir a doble cara y recortar.
  Uri urlCredenciales(int id) => ApiConfig.uri('$_ruta/$id/credenciales.pdf');

  /// Códigos de lote que aparecen más de una vez dentro del sindicato.
  /// Devuelve los códigos, no los lotes.
  Future<List<String>> lotesDuplicados(int id) async {
    final datos = await _api.obtener('$_ruta/$id/lotes-duplicados');
    return datos.comoListaDeTextos;
  }

  Future<Sindicato> crear(SindicatoRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Sindicato.desdeJson(datos.comoObjeto);
  }

  /// Habilita o deshabilita el registro.
  ///
  /// Deshabilitar no borra: la fila queda entera y se puede volver a
  /// habilitar. Es la salida para lo que el backend no deja eliminar por
  /// tener registros dependientes.
  Future<Sindicato> cambiarEstado(int id, bool estado) async {
    final datos = await _api
        .parchear('$_ruta/$id/estado', cuerpo: {'estado': estado});
    return Sindicato.desdeJson(datos.comoObjeto);
  }

  Future<Sindicato> actualizar(int id, SindicatoRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Sindicato.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');

  // ---------- Ubicación ----------

  /// Los que ya tienen la sede marcada, para dibujarlos juntos en un mapa.
  Future<List<Sindicato>> conUbicacion({int? centralId}) async {
    final datos = await _api.obtener('$_ruta/con-ubicacion',
        query: {'centralId': centralId});
    return datos.comoLista.map(Sindicato.desdeJson).toList(growable: false);
  }

  /// Marca o mueve la sede. Devuelve el sindicato ya actualizado.
  Future<Sindicato> marcarUbicacion(int id, double latitud, double longitud) async {
    final datos = await _api.reemplazar('$_ruta/$id/ubicacion', {
      'latitud': latitud,
      'longitud': longitud,
    });
    return Sindicato.desdeJson(datos.comoObjeto);
  }

  /// Quita la ubicación. El sindicato sigue existiendo, solo pierde el punto,
  /// y por eso devuelve el sindicato en vez de nada.
  Future<Sindicato> borrarUbicacion(int id) async {
    final datos = await _api.eliminarConRespuesta('$_ruta/$id/ubicacion');
    return Sindicato.desdeJson(datos.comoObjeto);
  }
}
