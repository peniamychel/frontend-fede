import '../core/api_client.dart';
import '../models/central.dart';
import '../models/federacion.dart';

class FederacionRepository {
  const FederacionRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/federaciones';

  Future<List<Federacion>> listar() async {
    final datos = await _api.obtener(_ruta);
    return datos.comoLista.map(Federacion.desdeJson).toList(growable: false);
  }

  /// Destino único de trabajo. Nunca toma la primera fila ni un ID fijo,
  /// porque las bases de desarrollo y producción pueden tener IDs distintos.
  Future<Federacion> deTrabajo() async {
    final candidatas = (await listar())
        .where(
          (f) =>
              f.nombre.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ') ==
              'CARRASCO TROPICAL',
        )
        .toList();
    if (candidatas.length != 1) {
      throw StateError(
        'No se encontró una única federación llamada CARRASCO TROPICAL. '
        'Revisá su registro antes de continuar.',
      );
    }
    return candidatas.single;
  }

  Future<Federacion> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Federacion.desdeJson(datos.comoObjeto);
  }

  /// Centrales que cuelgan de una federación.
  Future<List<Central>> centrales(int id) async {
    final datos = await _api.obtener('$_ruta/$id/centrales');
    return datos.comoLista.map(Central.desdeJson).toList(growable: false);
  }

  Future<Federacion> crear(FederacionRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Federacion.desdeJson(datos.comoObjeto);
  }

  /// Habilita o deshabilita el registro.
  ///
  /// Deshabilitar no borra: la fila queda entera y se puede volver a
  /// habilitar. Es la salida para lo que el backend no deja eliminar por
  /// tener registros dependientes.
  Future<Federacion> cambiarEstado(int id, bool estado) async {
    final datos = await _api.parchear(
      '$_ruta/$id/estado',
      cuerpo: {'estado': estado},
    );
    return Federacion.desdeJson(datos.comoObjeto);
  }

  Future<Federacion> actualizar(int id, FederacionRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Federacion.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}
