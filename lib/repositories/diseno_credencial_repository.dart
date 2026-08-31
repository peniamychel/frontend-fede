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

  Future<EditorDisenoCredencial> subirPlantilla(
    CaraCredencial cara,
    List<int> bytes,
    String nombreArchivo,
  ) async {
    final datos = await _api.subirArchivo(
      '$_ruta/plantilla/${_cara(cara)}',
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
    return EditorDisenoCredencial.desdeJson(datos.comoObjeto);
  }

  Future<ImagenDisenoSubida> subirImagen(
    List<int> bytes,
    String nombreArchivo,
  ) async {
    final datos = await _api.subirArchivo(
      '$_ruta/imagen',
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
    return ImagenDisenoSubida.desdeJson(datos.comoObjeto);
  }

  Future<EditorDisenoCredencial> restablecerPlantilla(
    CaraCredencial cara,
  ) async {
    final datos = await _api.eliminarConRespuesta(
      '$_ruta/plantilla/${_cara(cara)}',
    );
    return EditorDisenoCredencial.desdeJson(datos.comoObjeto);
  }

  String _cara(CaraCredencial cara) =>
      cara == CaraCredencial.cara ? 'CARA' : 'REVERSO';
}
