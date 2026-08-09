import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/importacion.dart';

class ImportacionRepository {
  const ImportacionRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/importaciones/productores';

  /// Dirección de la plantilla de ejemplo.
  ///
  /// No se descarga con el cliente HTTP: se le pasa al navegador, que la baja
  /// solo porque la respuesta viene con `Content-Disposition: attachment`. Así
  /// no hay que resolver dónde guardar el archivo en cada plataforma.
  Uri get urlPlantilla => ApiConfig.uri('/importaciones/plantilla');

  /// Sube la planilla y devuelve el informe.
  ///
  /// Con [simular] en true —el valor por defecto, igual que en el backend— no
  /// se escribe nada: el servidor ejecuta el proceso entero y deshace la
  /// transacción. Por eso el informe de la simulación describe exactamente lo
  /// que haría la confirmación.
  Future<ImportacionResultado> importar({
    required List<int> bytes,
    required String nombreArchivo,
    required int federacionId,
    bool simular = true,
    bool crearJerarquia = false,
    bool ignorarFilasConError = false,
  }) async {
    final datos = await _api.subirArchivo(
      _ruta,
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
      query: {
        'federacionId': federacionId,
        'simular': simular,
        'crearJerarquia': crearJerarquia,
        'ignorarFilasConError': ignorarFilasConError,
      },
    );
    return ImportacionResultado.desdeJson(datos.comoObjeto);
  }
}
