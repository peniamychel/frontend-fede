import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/reunion.dart';

/// Reuniones, vueltas de lista y acta.
///
/// Pasar lista cuelga de la vuelta y no de la reunión: en una asamblea se llama
/// lista varias veces, y cada vuelta tiene sus propios presentes.
class ReunionRepository {
  const ReunionRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/reuniones';
  static const String _rutaLlamadas = '/llamadas';

  /// De la más reciente a la más antigua. Los tres filtros de nivel son
  /// excluyentes: se pasa el del nivel que interesa.
  ///
  /// [texto] busca por dos caminos, que son las dos formas en que alguien
  /// busca una asamblea meses después: por **lo que fue** —título, lugar, notas
  /// o número del acta— y por **a quién se vetó ahí** —su nombre, su cédula,
  /// cualquiera de sus dos códigos, o el motivo escrito—.
  Future<List<Reunion>> listar({
    int? sindicatoId,
    int? centralId,
    int? federacionId,
    TipoReunion? tipo,
    String? texto,
  }) async {
    final buscado = texto?.trim();
    final datos = await _api.obtener(_ruta, query: {
      'sindicatoId': sindicatoId,
      'centralId': centralId,
      'federacionId': federacionId,
      'tipo': tipo?.valor,
      if (buscado != null && buscado.isNotEmpty) 'texto': buscado,
    });
    return datos.comoLista.map(Reunion.desdeJson).toList(growable: false);
  }

  /// Cuántas hay de cada tipo, con el mismo filtro pero sin el tipo.
  ///
  /// El tipo queda fuera de la cuenta a propósito: la solapa de «Ampliado»
  /// tiene que decir cuántos ampliados hay aunque se esté mirando otra, o el
  /// número cambiaría al tocarla y no serviría para decidir adónde ir.
  Future<Map<TipoReunion, int>> conteoPorTipo({
    int? sindicatoId,
    int? centralId,
    int? federacionId,
    String? texto,
  }) async {
    final buscado = texto?.trim();
    final datos = await _api.obtener('$_ruta/conteo', query: {
      'sindicatoId': sindicatoId,
      'centralId': centralId,
      'federacionId': federacionId,
      if (buscado != null && buscado.isNotEmpty) 'texto': buscado,
    });
    final crudo = datos.comoObjeto;
    return {
      for (final t in TipoReunion.values)
        t: (crudo[t.valor] as num?)?.toInt() ?? 0,
    };
  }

  Future<Reunion> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Reunion.desdeJson(datos.comoObjeto);
  }

  Future<Reunion> crear(ReunionRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Reunion.desdeJson(datos.comoObjeto);
  }

  Future<Reunion> actualizar(int id, ReunionRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Reunion.desdeJson(datos.comoObjeto);
  }

  /// Cierra o reabre el pase de lista. Con la lista cerrada ya no se pueden
  /// abrir más vueltas, y la que estuviera abierta se cierra también.
  Future<Reunion> cambiarCierre(int id, bool cerrada) async {
    final datos =
        await _api.parchear('$_ruta/$id/cierre', cuerpo: {'estado': cerrada});
    return Reunion.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');

  // ------------------------------------------------- las vueltas de lista

  /// Las vueltas de esa reunión, de la primera a la última.
  Future<List<LlamadaLista>> llamadas(int reunionId) async {
    final datos = await _api.obtener('$_ruta/$reunionId/llamadas');
    return datos.comoLista.map(LlamadaLista.desdeJson).toList(growable: false);
  }

  /// Abre una vuelta. Devuelve 409 si la lista está cerrada o si ya hay otra
  /// vuelta abierta: primero se cierra esa.
  Future<LlamadaLista> abrirLlamada(int reunionId, {String? nota}) async {
    final datos =
        await _api.crear('$_ruta/$reunionId/llamadas', {'nota': nota});
    return LlamadaLista.desdeJson(datos.comoObjeto);
  }

  /// Cierra la vuelta: lo que se registre de acá en más va a la siguiente.
  Future<LlamadaLista> cerrarLlamada(int llamadaId) async {
    final datos = await _api.reemplazar('$_rutaLlamadas/$llamadaId/cierre', {});
    return LlamadaLista.desdeJson(datos.comoObjeto);
  }

  /// Los convocados de esa vuelta, marcando quiénes ya llegaron. Viene ordenada
  /// por apellido, para buscar a alguien a ojo cuando el carnet no aparece.
  Future<List<Convocado>> lista(int llamadaId) async {
    final datos = await _api.obtener('$_rutaLlamadas/$llamadaId/lista');
    return datos.comoLista.map(Convocado.desdeJson).toList(growable: false);
  }

  /// Pasa lista: registra a alguien por el código de su credencial.
  ///
  /// Es lo que hace el escaneo del QR, y también sirve escribiendo el código a
  /// mano. Escanear dos veces no falla: devuelve el registro con
  /// [RegistroAsistencia.repetido] en true.
  Future<RegistroAsistencia> registrar(int llamadaId, String codigo) async {
    final datos = await _api
        .crear('$_rutaLlamadas/$llamadaId/asistencias', {'codigo': codigo});
    return RegistroAsistencia.desdeJson(datos.comoObjeto);
  }

  /// Quita a alguien de esa vuelta, para cuando se escaneó el carnet
  /// equivocado.
  Future<void> quitar(int llamadaId, int productorId) =>
      _api.eliminar('$_rutaLlamadas/$llamadaId/asistencias/$productorId');

  // ------------------------------------------------------------- el acta

  /// Agrega una hoja al final del acta: un PDF, o la foto del cuaderno.
  ///
  /// No se reduce como las fotos de los productores. Un acta se lee, y bajarle
  /// la resolución la vuelve inservible justo cuando alguien necesita
  /// verificar qué se decidió.
  ///
  /// [codigo] es el número del acta en el libro del sindicato. Hace falta con
  /// la primera hoja: el archivo es una foto de una hoja de ese libro, y sin el
  /// número nadie puede volver al original a cotejar. Con las siguientes se
  /// puede omitir —son del mismo acta— o mandar otro para corregirlo.
  Future<Reunion> agregarHoja({
    required int reunionId,
    required List<int> bytes,
    required String nombreArchivo,
    String? codigo,
  }) async {
    final datos = await _api.subirArchivo(
      '$_ruta/$reunionId/acta',
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
      campos: {'codigo': codigo},
    );
    return Reunion.desdeJson(datos.comoObjeto);
  }

  /// Corrige el número del acta, sin tocar las hojas: es un dato del acta, no
  /// de cada foto. Devuelve 409 si la reunión todavía no tiene acta.
  Future<Reunion> ponerCodigoActa(int reunionId, String codigo) async {
    final datos = await _api
        .reemplazar('$_ruta/$reunionId/acta/codigo', {'codigo': codigo});
    return Reunion.desdeJson(datos.comoObjeto);
  }

  /// Dirección de una hoja, para abrirla. El backend la manda con su tipo, así
  /// que el navegador la muestra en vez de descargarla a ciegas.
  Uri urlHoja(int reunionId, int hojaId) =>
      ApiConfig.uri('$_ruta/$reunionId/acta/hojas/$hojaId');

  /// Quita una hoja y renumera las que quedan. Devuelve 409 si es la última y
  /// en esa reunión se decidió algún veto.
  Future<Reunion> quitarHoja(int reunionId, int hojaId) async {
    final datos = await _api
        .eliminarConRespuesta('$_ruta/$reunionId/acta/hojas/$hojaId');
    return Reunion.desdeJson(datos.comoObjeto);
  }
}
