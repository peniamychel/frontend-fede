import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/pagina.dart';
import '../models/cargo.dart';
import '../models/credencial_previa.dart';
import '../models/imagen.dart';
import '../models/lado_credencial.dart';
import '../models/productor.dart';

/// Criterios disponibles para ordenar el padrón desde el servidor.
///
/// El segundo campo desempata homónimos y el backend agrega el id al final,
/// evitando duplicados o saltos cuando la lista carga la siguiente página.
enum OrdenProductores {
  recientes('Modificados recientemente', ['updatedAt,desc', 'id,desc']),
  apellidos('Apellidos (A–Z)', ['apellidos,asc', 'nombres,asc']),
  nombres('Nombres (A–Z)', ['nombres,asc', 'apellidos,asc']);

  const OrdenProductores(this.etiqueta, this.parametros);

  final String etiqueta;
  final List<String> parametros;
}

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

  /// PDF de una sola página para imprimir cada lado por separado.
  Future<DescargaBinaria> descargarLadoCredencial(
    int id,
    LadoCredencial lado,
  ) => _api.obtenerBytes(
    '$_ruta/$id/credencial.pdf',
    // El diseño y la plantilla pueden cambiar conservando la misma ruta.
    // La marca temporal evita que Windows o el navegador reutilicen un PDF
    // generado antes de la última edición.
    query: {
      'cara': lado.parametroApi,
      'v': DateTime.now().millisecondsSinceEpoch,
    },
  );

  /// Lo que va a salir impreso, y lo que falta para poder imprimirlo.
  ///
  /// Hay que pedirla antes de abrir [urlCredencial]: si falta algo el backend
  /// responde 409, y como la descarga se abre en el navegador ese error
  /// aparecería como un JSON en pantalla en vez de como un aviso.
  Future<CredencialPrevia> previaCredencial(int id) async {
    final datos = await _api.obtener('$_ruta/$id/credencial/previa');
    return CredencialPrevia.desdeJson(datos.comoObjeto);
  }

  /// Suma una impresión del anverso aceptada por el controlador de Windows.
  /// El reverso no se contabiliza.
  Future<Productor> confirmarImpresionCredencial(int id) async {
    final datos = await _api.crear('$_ruta/$id/credencial/impresion', const {});
    return Productor.desdeJson(datos.comoObjeto);
  }

  /// Listado paginado del padrón. Los tres filtros son opcionales y
  /// combinables; [texto] busca a la vez en nombres, apellidos, cédula y carné.
  ///
  /// [orden] permite elegir el campo principal. El backend desempata siempre
  /// por id para que una fila no pueda salir en dos páginas distintas.
  Future<Pagina<Productor>> listar({
    int? sindicatoId,
    int? centralId,
    String? texto,
    OrdenProductores orden = OrdenProductores.apellidos,
    Paginacion paginacion = const Paginacion(),
  }) async {
    final datos = await _api.obtener(
      _ruta,
      query: {
        'sindicatoId': sindicatoId,
        'centralId': centralId,
        'texto': texto,
        ...paginacion.query,
        'sort': orden.parametros,
      },
    );
    return Pagina.desdeJson(datos.comoObjeto, Productor.desdeJson);
  }

  /// Ficha completa: el productor con sus lotes y sus observaciones.
  Future<ProductorDetalle> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return ProductorDetalle.desdeJson(datos.comoObjeto);
  }

  /// Ejecuta la única revisión SIE pendiente de una fila importada.
  /// El backend evita repetir la consulta una vez que fue completada.
  Future<RevisionSieProductor> revisarImportadoConSie(int id) async {
    final datos = await _api.crear('$_ruta/$id/revision-sie', const {});
    return RevisionSieProductor.desdeJson(datos.comoObjeto);
  }

  /// Comprobación manual temporal para productores que ya estaban cargados.
  /// Siempre consulta SIE, aunque la revisión automática ya haya terminado.
  Future<RevisionSieProductor> verificarManualmenteConSie(int id) async {
    final datos = await _api.crear('$_ruta/$id/verificacion-sie', const {});
    return RevisionSieProductor.desdeJson(datos.comoObjeto);
  }

  Future<RevisionSieProductor> confirmarRevisionSie(
    int id,
    RevisionSieProductor propuesta, {
    required bool aceptar,
  }) async {
    final datos = await _api.crear('$_ruta/$id/revision-sie/confirmacion', {
      'aceptar': aceptar,
      'actuales': propuesta.actuales,
      'propuestos': propuesta.propuestos,
    });
    return RevisionSieProductor.desdeJson(datos.comoObjeto);
  }

  /// Productores sin rótulo de fotografía. En el padrón original son 3.113 de
  /// 4.051, así que este listado viene paginado.
  Future<Pagina<Productor>> sinFoto({
    Paginacion paginacion = const Paginacion(),
  }) async {
    final datos = await _api.obtener(
      '$_ruta/sin-foto',
      query: paginacion.query,
    );
    return Pagina.desdeJson(datos.comoObjeto, Productor.desdeJson);
  }

  /// Cédulas asignadas a más de una persona. Devuelve las cédulas, no los
  /// productores: para ver quiénes las comparten, usar [porCedula].
  Future<List<String>> cedulasDuplicadas() async {
    final datos = await _api.obtener('$_ruta/duplicados/cedulas');
    return datos.comoListaDeTextos;
  }

  Future<List<Productor>> porCedula(String ci) async {
    final datos = await _api.obtener('$_ruta/por-cedula/$ci');
    return datos.comoLista.map(Productor.desdeJson).toList(growable: false);
  }

  /// Consulta nombres y apellidos en SIE. El token vive en el backend: nunca
  /// se entrega a esta aplicación ni queda dentro del JavaScript compilado.
  Future<ConsultaPersona> consultarPersona(String ci) async {
    final datos = await _api.crear('/personas/consulta', {'ci': ci});
    return ConsultaPersona.desdeJson(datos.comoObjeto);
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
    final datos = await _api.parchear(
      '$_ruta/$id/estado',
      cuerpo: {'estado': estado},
    );
    return Productor.desdeJson(datos.comoObjeto);
  }

  /// Marca manualmente al productor como observado y fuera de impresión.
  Future<Productor> observar(int id, String texto) async {
    final datos = await _api.parchear(
      '$_ruta/$id/observacion',
      cuerpo: {'texto': texto},
    );
    return Productor.desdeJson(datos.comoObjeto);
  }

  /// Quita la observación manual. Los demás requisitos siguen vigentes.
  Future<Productor> quitarObservacion(int id) async {
    final datos = await _api.eliminarConRespuesta('$_ruta/$id/observacion');
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

  /// Elimina el productor y sus datos dependientes (fotos, cargos, vetos e
  /// historial de tenencias). El backend lo rechaza si todavía tiene una
  /// parcela vigente: los lotes no se eliminan en cascada.
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
