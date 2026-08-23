import '../core/api_client.dart';
import '../models/backup.dart';

class BackupRepository {
  BackupRepository(this.api);

  static const _ruta = '/administracion/backups';
  final ApiClient api;

  Future<List<Backup>> listar() async {
    final respuesta = await api.obtener(_ruta);
    return respuesta.comoLista.map(Backup.desdeJson).toList(growable: false);
  }

  Future<Backup> crear() async {
    final respuesta = await api.crear(_ruta, const <String, dynamic>{});
    return Backup.desdeJson(respuesta.comoObjeto);
  }

  Future<Backup> obtener(String id) async {
    final respuesta = await api.obtener('$_ruta/$id');
    return Backup.desdeJson(respuesta.comoObjeto);
  }

  Future<DescargaBinaria> descargar(String id) =>
      api.obtenerBytes('$_ruta/$id/descarga');

  Future<void> eliminar(String id) => api.eliminar('$_ruta/$id');
}
