import '../core/api_client.dart';
import '../models/reunion.dart';

/// Reuniones y pase de lista.
class ReunionRepository {
  const ReunionRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/reuniones';

  /// De la más reciente a la más antigua. Los tres filtros son excluyentes:
  /// se pasa el del nivel que interesa.
  Future<List<Reunion>> listar({
    int? sindicatoId,
    int? centralId,
    int? federacionId,
  }) async {
    final datos = await _api.obtener(_ruta, query: {
      'sindicatoId': sindicatoId,
      'centralId': centralId,
      'federacionId': federacionId,
    });
    return datos.comoLista.map(Reunion.desdeJson).toList(growable: false);
  }

  Future<Reunion> obtener(int id) async {
    final datos = await _api.obtener('$_ruta/$id');
    return Reunion.desdeJson(datos.comoObjeto);
  }

  /// La lista de convocados, marcando quiénes ya llegaron. Viene ordenada por
  /// apellido, para buscar a alguien a ojo cuando el carnet no aparece.
  Future<List<Convocado>> lista(int id) async {
    final datos = await _api.obtener('$_ruta/$id/lista');
    return datos.comoLista.map(Convocado.desdeJson).toList(growable: false);
  }

  Future<Reunion> crear(ReunionRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Reunion.desdeJson(datos.comoObjeto);
  }

  Future<Reunion> actualizar(int id, ReunionRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$id', request.aJson());
    return Reunion.desdeJson(datos.comoObjeto);
  }

  /// Pasa lista: registra a alguien por el código de su credencial.
  ///
  /// Es lo que hace el escaneo del QR, y también sirve escribiendo el código a
  /// mano. Escanear dos veces no falla: devuelve el registro con [
  /// RegistroAsistencia.repetido] en true.
  Future<RegistroAsistencia> registrar(int id, String codigo) async {
    final datos = await _api.crear('$_ruta/$id/asistencias', {'codigo': codigo});
    return RegistroAsistencia.desdeJson(datos.comoObjeto);
  }

  /// Quita a alguien de la lista, para cuando se escaneó el carnet equivocado.
  Future<void> quitar(int id, int productorId) =>
      _api.eliminar('$_ruta/$id/asistencias/$productorId');

  /// Cierra o reabre la lista.
  Future<Reunion> cambiarCierre(int id, bool cerrada) async {
    final datos =
        await _api.parchear('$_ruta/$id/cierre', cuerpo: {'estado': cerrada});
    return Reunion.desdeJson(datos.comoObjeto);
  }

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');
}
