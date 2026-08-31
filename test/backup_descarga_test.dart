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

  test('prefiere filename UTF-8 y conserva la extensión PDF', () async {
    final cliente = MockClient(
      (_) async => http.Response.bytes(
        [0x25, 0x50, 0x44, 0x46],
        200,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition':
              'attachment; filename="=?UTF-8?Q?informe?="; '
              "filename*=UTF-8''informe-nominal-impresi%C3%B3n.pdf",
        },
      ),
    );
    final api = ApiClient(cliente: cliente);

    final descarga = await api.obtenerBytes('/informe.pdf');

    expect(descarga.tipoMime, 'application/pdf');
    expect(descarga.nombreArchivo, 'informe-nominal-impresión.pdf');
    api.cerrar();
  });

  test(
    'usa una extensión PDF aunque no se exponga Content-Disposition',
    () async {
      final cliente = MockClient(
        (_) async => http.Response.bytes(
          [0x25, 0x50, 0x44, 0x46],
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      );
      final api = ApiClient(cliente: cliente);

      final descarga = await api.obtenerBytes('/informe.pdf');

      expect(descarga.nombreArchivo, 'descarga.pdf');
      api.cerrar();
    },
  );
}
