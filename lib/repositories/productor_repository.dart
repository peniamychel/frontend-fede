import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/pagina.dart';
import '../models/cargo.dart';
import '../models/imagen.dart';
import '../models/productor.dart';

class ProductorRepository {
  const ProductorRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/productores';

  /// Dirección de la credencial en PDF: dos páginas del tamaño de una cédula,
  /// anverso y reverso.
  ///
  /// Se devuelve la URL y no los bytes por lo mismo que el informe: el backend
  /// la marca como adjunto y el sistema la guarda solo.
  Uri urlCredencial(int id) => ApiConfig.uri('$_ruta/$id/credencial.pdf');

  /// Listado paginado del padrón. Los tres filtros son opcionales y
  /// combinables; [texto] busca a la vez en nombres, apellidos, cédula y carné.
  ///
  /// El backend ordena por apellidos y nombres, desempatando siempre por id,
  /// para que una misma fila no pueda salir en dos páginas distintas.
  Future<Pagina<Productor>> listar({
    int? sindicatoId,
    int? centralId,
    String? texto,
    Paginacion paginacion = const Paginacion(),
  }) async {
    final datos = await _api.obtener(_ruta, query: {
      'sindicatoId': sindicatoId,
      'centralId': centralId,
      'texto': texto,
      ...paginacion.query,
    });
    return Pagina.desdeJson(datos.comoObjeto, Productor.desdeJson);
  }

  /// Ficha completa: el productor con sus lotes y sus observaciones.
  Future<ProductorDetalle> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return ProductorDetalle.desdeJson(datos.comoObjeto);
  }

  /// Productores sin rótulo de fotografía. En el padrón original son 3.113 de
  /// 4.051, así que este listado viene paginado.
  Future<Pagina<Productor>> sinFoto({
    Paginacion paginacion = const Paginacion(),
  }) async {
    final datos = await _api.obtener('$_ruta/sin-foto', query: paginacion.query);
    return Pagina.desdeJson(datos.comoObjeto, Productor.desdeJson);
  }

  /// Cédulas asignadas a más de una persona. Devuelve las cédulas, no los
  /// productores: para ver quiénes las comparten, usar [porCedula].
  Future<List<String>> cedulasDuplicadas() async {
    final datos = await _api.obtener('$_ruta/duplicados/cedulas');
    return datos.comoListaDeTextos;
  }

  /// Carnés de productor asignados a más de una persona.
  Future<List<String>> carnetsDuplicados() async {
    final datos = await _api.obtener('$_ruta/duplicados/carnets');
    return datos.comoListaDeTextos;
  }

  Future<List<Productor>> porCedula(String ci) async {
    final datos = await _api.obtener('$_ruta/por-cedula/$ci');
    return datos.comoLista.map(Productor.desdeJson).toList(growable: false);
  }

  Future<List<Productor>> porCarnet(String carnet) async {
    final datos = await _api.obtener('$_ruta/por-carnet/$carnet');
    return datos.comoLista.map(Productor.desdeJson).toList(growable: false);
  }

  Future<Productor> crear(ProductorRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Productor.desdeJson(datos.comoObjeto);
  }

  /// Habilita o deshabilita el registro.
  ///
  /// Deshabilitar no borra: la fila queda entera y se puede volver a
  /// habilitar. Es la salida para lo que el backend no deja eliminar por
  /// tener registros dependientes.
  Future<Productor> cambiarEstado(int id, bool estado) async {
    final datos = await _api
        .parchear('$_ruta/$id/estado', cuerpo: {'estado': estado});
    return Productor.desdeJson(datos.comoObjeto);
  }

  /// Actualiza los datos, o mueve el productor a otro sindicato.
  Future<Productor> actualizar(int id, ProductorRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Productor.desdeJson(datos.comoObjeto);
  }

  /// Promueve la corrección de nombre propuesta a los campos definitivos y
  /// limpia la propuesta.
  Future<Productor> confirmarCorreccionNombre(int id) async {
    final datos = await _api.parchear('$_ruta/$id/confirmar-correccion-nombre');
    return Productor.desdeJson(datos.comoObjeto);
  }

  /// Elimina el productor. Arrastra en cascada sus lotes, observaciones e
  /// imágenes.
  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');

  // ---------- Imágenes ----------

  /// Cargos del directorio que ocupó, incluidos los de sindicatos anteriores.
  Future<List<Cargo>> cargos(int productorId) async {
    final datos = await _api.obtener('$_ruta/$productorId/cargos');
    return datos.comoLista.map(Cargo.desdeJson).toList(growable: false);
  }

  Future<List<Imagen>> imagenes(int productorId) async {
    final datos = await _api.obtener('$_ruta/$productorId/imagenes');
    return datos.comoLista.map(Imagen.desdeJson).toList(growable: false);
  }

  /// Sube la foto del productor. **Una sola imagen y de cualquier tamaño**: el
  /// servidor deriva la versión de consulta y la miniatura, y las reduce.
  ///
  /// No se valida el peso acá a propósito. Rechazar un archivo grande sería
  /// pedirle al usuario que haga con un editor lo que el servidor hace solo.
  /// [recorte] acota qué parte de la foto conservar. El corte lo aplica el
  /// servidor sobre la imagen en resolución completa, antes de reducirla.
  Future<ImagenSubida> subirImagen({
    required int productorId,
    required List<int> bytes,
    required String nombreArchivo,
    Recorte? recorte,
  }) async {
    final datos = await _api.subirArchivo(
      '$_ruta/$productorId/imagenes',
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
      query: recorte?.query,
    );
    return ImagenSubida.desdeJson(datos.comoObjeto);
  }

  /// Borra la foto: las dos variantes juntas, porque tampoco se suben por
  /// separado.
  Future<void> eliminarImagen(int productorId) =>
      _api.eliminar('$_ruta/$productorId/imagenes');
}
