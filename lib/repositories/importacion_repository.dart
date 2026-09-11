import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/importacion.dart';
import '../models/conciliacion_udestro.dart';
import '../core/pagina.dart';

class ImportacionRepository {
  const ImportacionRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/importaciones/productores';
  static const String _rutaUdestro = '/conciliaciones-udestro';

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

  /// Compara la lista completa de UDESTRO y guarda un borrador sin tocar el padrón.
  Future<ConciliacionUdestro> analizarUdestro({
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    final datos = await _api.subirArchivo(
      _rutaUdestro,
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
    return ConciliacionUdestro.desdeJson(datos.comoObjeto);
  }

  Future<ConciliacionUdestro> obtenerConciliacionUdestro(int id) async {
    final datos = await _api.obtener('$_rutaUdestro/$id');
    return ConciliacionUdestro.desdeJson(datos.comoObjeto);
  }

  Future<ConciliacionUdestro> ultimoBorradorUdestro() async {
    final datos = await _api.obtener('$_rutaUdestro/ultimo-borrador');
    return ConciliacionUdestro.desdeJson(datos.comoObjeto);
  }

  Future<Pagina<FilaConciliacionUdestro>> filasUdestro(
    int id, {
    required AccionConciliacionUdestro accion,
    int pagina = 0,
    int tamano = 50,
  }) async {
    final datos = await _api.obtener(
      '$_rutaUdestro/$id/filas',
      query: {
        'accion': accion.valor,
        'page': pagina,
        'size': tamano,
        'sort': 'id,asc',
      },
    );
    return paginaFilasUdestro(datos.comoObjeto);
  }

  Future<FilaConciliacionUdestro> decidirConflictoUdestro({
    required int conciliacionId,
    required int filaId,
    required DecisionConflictoUdestro decision,
    int? productorId,
  }) async {
    final datos = await _api.parchear(
      '$_rutaUdestro/$conciliacionId/filas/$filaId',
      cuerpo: {'decision': decision.valor, 'productorId': ?productorId},
    );
    return FilaConciliacionUdestro.desdeJson(datos.comoObjeto);
  }

  Future<ConciliacionUdestro> aplicarUdestro(
    int id, {
    required bool aprobarSindicatosNuevos,
  }) async {
    final datos = await _api.crearConTiempoLimite('$_rutaUdestro/$id/aplicar', {
      'aprobarSindicatosNuevos': aprobarSindicatosNuevos,
    }, tiempoLimite: const Duration(minutes: 30));
    return ConciliacionUdestro.desdeJson(datos.comoObjeto);
  }
}
