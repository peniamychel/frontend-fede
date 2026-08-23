import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fede/core/api_client.dart';

void main() {
  test('la descarga acepta el tipo gzip específico del backend', () async {
    final cliente = MockClient((peticion) async {
      expect(peticion.headers['Accept'], '*/*');
      expect(peticion.headers['Authorization'], 'Bearer token-prueba');
      return http.Response.bytes(
        [0x1f, 0x8b, 0x08],
        200,
        headers: {
          'content-type': 'application/gzip',
          'content-disposition': 'attachment; filename="federa_prueba.sql.gz"',
        },
      );
    });
    final api = ApiClient(cliente: cliente)..usarToken('token-prueba');

    final descarga = await api.obtenerBytes(
      '/administracion/backups/1/descarga',
    );

    expect(descarga.tipoMime, 'application/gzip');
    expect(descarga.nombreArchivo, 'federa_prueba.sql.gz');
    expect(descarga.bytes, [0x1f, 0x8b, 0x08]);
    api.cerrar();
  });
}
