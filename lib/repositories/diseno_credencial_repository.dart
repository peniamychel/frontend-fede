import '../core/api_client.dart';
import '../models/diseno_credencial.dart';

class DisenoCredencialRepository {
  DisenoCredencialRepository(this._api);

  final ApiClient _api;
  static const _ruta = '/configuracion/credencial';

  Future<EditorDisenoCredencial> obtener() async {
    final datos = await _api.obtener(_ruta);
    return EditorDisenoCredencial.desdeJson(datos.comoObjeto);
  }

  Future<EditorDisenoCredencial> guardar(DisenoCredencial diseno) async {
    final datos = await _api.reemplazar(_ruta, diseno.aJson());
    return EditorDisenoCredencial.desdeJson(datos.comoObjeto);
  }

  Future<EditorDisenoCredencial> restablecer() async {
    final datos = await _api.reemplazar('$_ruta/restablecer', const {});
    return EditorDisenoCredencial.desdeJson(datos.comoObjeto);
  }
}
