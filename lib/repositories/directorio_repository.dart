import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/cargo.dart';
import '../models/lado_credencial.dart';
import '../models/productor.dart';

/// Directorios de los tres niveles: sindicato, central y federación.
///
/// Vive aparte de los repositorios de cada nivel porque el directorio funciona
/// igual en los tres: lo único que cambia es de qué recurso cuelga la ruta, y
/// eso lo dice [Ambito.recurso].
class DirectorioRepository {
  const DirectorioRepository(this._api);

  final ApiClient _api;

  String _base(Ambito ambito, int id) => '/${ambito.recurso}/$id/directorio';

  /// Un puesto por cada cargo del nivel, ocupado o vacante.
  Future<Directorio> obtener(Ambito ambito, int id) async {
    final datos = await _api.obtener(_base(ambito, id));
    return Directorio.desdeJson(datos.comoObjeto);
  }

  /// Todos los períodos, del más reciente al más antiguo.
  Future<List<Cargo>> historial(Ambito ambito, int id) async {
    final datos = await _api.obtener('${_base(ambito, id)}/historial');
    return datos.comoLista.map(Cargo.desdeJson).toList(growable: false);
  }

  /// Productores que pueden ocupar un cargo de este nivel.
  ///
  /// El backend ya descarta a quienes ocupan otro cargo y a los
  /// deshabilitados, así que la lista se puede mostrar tal cual.
  Future<List<Productor>> candidatos(Ambito ambito, int id) async {
    final datos = await _api.obtener('${_base(ambito, id)}/candidatos');
    return datos.comoLista.map(Productor.desdeJson).toList(growable: false);
  }

  /// Pone a un productor en el cargo. Si había alguien, su período se cierra
  /// solo el día anterior.
  Future<Directorio> asignar({
    required Ambito ambito,
    required int id,
    required TipoCargo cargo,
    required int productorId,
    DateTime? desde,
  }) async {
    final datos = await _api.reemplazar('${_base(ambito, id)}/${cargo.valor}', {
      'productorId': productorId,
      if (desde != null) 'desde': _soloFecha(desde),
    });
    return Directorio.desdeJson(datos.comoObjeto);
  }

  /// Deja el cargo vacante sin nombrar reemplazo.
  Future<Directorio> terminar({
    required Ambito ambito,
    required int id,
    required TipoCargo cargo,
    DateTime? hasta,
  }) async {
    // La fecha va como query aparte y no pegada con un `?`: la URI se arma con
    // Uri(path: ...), que codificaría el signo de pregunta dentro del camino y
    // el servidor devolvería 404.
    final datos = await _api.eliminarConRespuesta(
      '${_base(ambito, id)}/${cargo.valor}',
      query: {'hasta': hasta == null ? null : _soloFecha(hasta)},
    );
    return Directorio.desdeJson(datos.comoObjeto);
  }

  /// Dirección de la credencial del dirigente: dos páginas del tamaño de una
  /// cédula, **en vertical**, al revés que la del productor.
  ///
  /// Cuelga del período y no del nivel porque el período existe por sí mismo:
  /// sobrevive al relevo, y su credencial sirve como constancia de que ocupó
  /// el cargo entre tales fechas.
  Uri urlCredencial(int cargoId) =>
      ApiConfig.uri('/cargos/$cargoId/credencial.pdf');

  /// PDF de una sola página para una Zebra sin dúplex automático.
  Future<DescargaBinaria> descargarLadoCredencial(
    int cargoId,
    LadoCredencial lado,
  ) => _api.obtenerBytes(
    '/cargos/$cargoId/credencial.pdf',
    query: {'cara': lado.parametroApi},
  );

  // ---------- Imágenes del período ----------

  /// Sube una imagen histórica de un período. La interfaz actual usa solo FIRMA.
  ///
  /// Cualquier tamaño de archivo sirve: el servidor la reduce a 200 píxeles de
  /// lado mayor conservando la proporción.
  ///
  /// La ruta cuelga de `/cargos` y no del nivel porque las imágenes son del
  /// período, que también existe cuando ya terminó. Solo los dos cargos
  /// firmantes de cada nivel las admiten; con otro cargo el backend responde 409.
  Future<Cargo> subirImagen({
    required int cargoId,
    required TipoImagenCargo tipo,
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    final datos = await _api.subirArchivo(
      '/cargos/$cargoId/imagenes/${tipo.ruta}',
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
    return Cargo.desdeJson(datos.comoObjeto);
  }

  Future<Cargo> eliminarImagen(int cargoId, TipoImagenCargo tipo) async {
    final datos = await _api.eliminarConRespuesta(
      '/cargos/$cargoId/imagenes/${tipo.ruta}',
    );
    return Cargo.desdeJson(datos.comoObjeto);
  }

  Future<Cargo> actualizarPieFirma(int cargoId, String? pieFirma) async {
    final datos = await _api.parchear(
      '/cargos/$cargoId/pie-firma',
      cuerpo: {'pieFirma': pieFirma},
    );
    return Cargo.desdeJson(datos.comoObjeto);
  }

  Future<Directorio> subirSello({
    required Ambito ambito,
    required int id,
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    final datos = await _api.subirArchivo(
      '${_base(ambito, id)}/sello',
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
    return Directorio.desdeJson(datos.comoObjeto);
  }

  Future<Directorio> eliminarSello(Ambito ambito, int id) async {
    final datos = await _api.eliminarConRespuesta('${_base(ambito, id)}/sello');
    return Directorio.desdeJson(datos.comoObjeto);
  }

  /// El backend espera una fecha sin hora: mandar el instante completo lo hace
  /// fallar al interpretarla.
  static String _soloFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
