import '../core/api_client.dart';
import '../models/operador_credencial.dart';

class OperadorCredencialRepository {
  OperadorCredencialRepository(this._api);

  final ApiClient _api;
  static const _ruta = '/credenciales-operadores';

  Future<List<OperadorCredencial>> listar({String? buscar}) async {
    final datos = await _api.obtener(_ruta, query: {'buscar': buscar?.trim()});
    return datos.comoLista
        .map((e) => OperadorCredencial.desdeJson(e.comoObjeto))
        .toList();
  }

  Future<OperadorCredencial> obtener(int id) async =>
      OperadorCredencial.desdeJson(
        (await _api.obtener('$_ruta/$id')).comoObjeto,
      );

  Future<OperadorCredencial> guardar(OperadorCredencial operador) async =>
      OperadorCredencial.desdeJson(
        (operador.id == 0
                ? await _api.crear(_ruta, operador.aJson())
                : await _api.reemplazar(
                    '$_ruta/${operador.id}',
                    operador.aJson(),
                  ))
            .comoObjeto,
      );

  Future<void> eliminar(int id) => _api.eliminar('$_ruta/$id');

  Future<OperadorCredencial> subirFoto(
    int id, {
    required List<int> bytes,
  }) async => OperadorCredencial.desdeJson(
    (await _api.subirArchivo(
      '$_ruta/$id/foto',
      campo: 'archivo',
      bytes: bytes,
      nombreArchivo: 'fotografia-operador.png',
    )).comoObjeto,
  );

  Future<DescargaBinaria> descargarFoto(int id) =>
      _api.obtenerBytes('$_ruta/$id/foto');

  Future<OperadorCredencial> quitarFoto(int id) async =>
      OperadorCredencial.desdeJson(
        (await _api.eliminarConRespuesta('$_ruta/$id/foto')).comoObjeto,
      );

  Future<String> resena() async =>
      (await _api.obtener('$_ruta/configuracion')).comoObjeto['resena']
          as String? ??
      '';

  Future<void> guardarResena(String resena) async {
    await _api.reemplazar('$_ruta/configuracion', {'resena': resena.trim()});
  }

  Future<OperadorCredencialPrevia> previa(int id) async =>
      OperadorCredencialPrevia.desdeJson(
        (await _api.obtener('$_ruta/$id/previa')).comoObjeto,
      );

  Future<DescargaBinaria> pdf(int id, {String cara = 'COMPLETA'}) =>
      _api.obtenerBytes('$_ruta/$id/credencial.pdf', query: {'cara': cara});
}
