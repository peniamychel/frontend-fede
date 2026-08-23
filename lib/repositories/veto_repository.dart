import '../core/api_client.dart';
import '../models/veto.dart';

/// Vetos: quién está observado, por qué, y quién lo decidió.
class VetoRepository {
  const VetoRepository(this._api);

  final ApiClient _api;

  static const String _ruta = '/vetos';

  /// Busca vetados por cédula, código de credencial, nombre o apellido, y
  /// opcionalmente dentro de un sindicato.
  ///
  /// Por defecto trae solo los que están vetados hoy, que es lo que se necesita
  /// al controlar a alguien; con [vigentes] en false sale también el historial.
  Future<List<Veto>> buscar({
    String? texto,
    int? sindicatoId,
    bool vigentes = true,
  }) async {
    final buscado = texto?.trim();
    final datos = await _api.obtener(_ruta, query: {
      if (buscado != null && buscado.isNotEmpty) 'texto': buscado,
      'sindicatoId': ?sindicatoId,
      'vigentes': vigentes,
    });
    return datos.comoLista.map(Veto.desdeJson).toList(growable: false);
  }

  /// Todo lo que le pasó a una persona: el veto vigente y los ya levantados.
  Future<List<Veto>> historialDe(int productorId) async {
    final datos = await _api.obtener('$_ruta/productor/$productorId');
    return datos.comoLista.map(Veto.desdeJson).toList(growable: false);
  }

  /// Los vetos que se decidieron en una reunión.
  Future<List<Veto>> deLaReunion(int reunionId) async {
    final datos = await _api.obtener('$_ruta/reunion/$reunionId');
    return datos.comoLista.map(Veto.desdeJson).toList(growable: false);
  }

  Future<Veto> vetar(VetoRequest request) async {
    final datos = await _api.crear(_ruta, request.aJson());
    return Veto.desdeJson(datos.comoObjeto);
  }

  /// Lo saca de la lista. La reunión tiene que ser otra que la que lo vetó, y
  /// tener su acta cargada.
  Future<Veto> levantar(int vetoId, LevantarVetoRequest request) async {
    final datos = await _api.reemplazar('$_ruta/$vetoId/levantar', request.aJson());
    return Veto.desdeJson(datos.comoObjeto);
  }
}
