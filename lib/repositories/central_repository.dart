import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/central.dart';
import '../models/informe_impresion_central.dart';
import '../models/sindicato.dart';

class CentralRepository {
  const CentralRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/centrales';

  /// Todas las centrales, o solo las de una federación si se pasa
  /// [federacionId].
  Future<List<Central>> listar({int? federacionId}) async {
    final datos = await _api.obtener(
      _ruta,
      query: {'federacionId': federacionId},
    );
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

  /// Avance global de las credenciales de todos los sindicatos de la central.
  Future<InformeImpresionCentral> informeImpresion(int id) async {
    final datos = await _api.obtener('$_ruta/$id/credenciales/impresion');
    return InformeImpresionCentral.desdeJson(datos.comoObjeto);
  }

  /// Avance consolidado de todas las centrales de una federación.
  Future<InformeImpresionFederacion> informeImpresionFederacion(
    int federacionId,
  ) async {
    final datos = await _api.obtener(
      '/federaciones/$federacionId/credenciales/impresion',
    );
    return InformeImpresionFederacion.desdeJson(datos.comoObjeto);
  }

  /// PDF del avance consolidado de todas las centrales y sus sindicatos.
  Uri urlInformeImpresionFederacion(int federacionId) => ApiConfig.uri(
    '/federaciones/$federacionId/credenciales/impresion/informe.pdf',
  );

  /// PDF con el mismo resumen y el desglose por sindicato.
  Uri urlInformeImpresion(int id) =>
      ApiConfig.uri('$_ruta/$id/credenciales/impresion/informe.pdf');

  /// Planilla física para recolectar sellos, firma y pie de firma.
  Uri urlPlanillaRecoleccionDirectorio(int id) => ApiConfig.uri(
    '$_ruta/$id/credenciales/impresion/planilla-recoleccion.pdf',
  );

  Future<InformeNominalImpresionCentral> informeNominalImpresion(
    int id,
    List<int> sindicatoIds,
  ) async {
    final datos = await _api.crear(
      '$_ruta/$id/credenciales/impresion/informe-nominal',
      {'sindicatoIds': sindicatoIds},
    );
    return InformeNominalImpresionCentral.desdeJson(datos.comoObjeto);
  }

  Future<DescargaBinaria> descargarInformeNominalImpresion(
    int id,
    List<int> sindicatoIds,
  ) => _api.crearBytes(
    '$_ruta/$id/credenciales/impresion/informe-nominal.pdf',
    {'sindicatoIds': sindicatoIds},
  );

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
    final datos = await _api.parchear(
      '$_ruta/$id/estado',
      cuerpo: {'estado': estado},
    );
    return Central.desdeJson(datos.comoObjeto);
  }

  Future<Central> actualizar(int id, CentralRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Central.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}
