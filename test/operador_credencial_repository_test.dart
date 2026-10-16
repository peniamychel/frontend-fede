import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fede/repositories/padron.dart';

void main() {
  const registro = {
    'id': 9,
    'nombres': 'ANA',
    'apellidos': 'PEREZ',
    'ci': '123456',
    'cargo': 'OPERADORA',
    'telefono': '77712345',
  };

  test(
    'CRUD de operadores usa su propia API y conserva los cinco datos',
    () async {
      final peticiones = <http.Request>[];
      final api = ApiClient(
        cliente: MockClient((peticion) async {
          peticiones.add(peticion);
          if (peticion.method == 'DELETE') return http.Response('', 204);
          return http.Response(
            jsonEncode(peticion.method == 'GET' ? [registro] : registro),
            peticion.method == 'POST' ? 201 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..usarToken('sesion-prueba');
      final repo = OperadorCredencialRepository(api);
      final operadores = await repo.listar(buscar: '  ANA  ');
      expect(operadores.single.nombreCompleto, 'ANA PEREZ');
      expect(peticiones.last.url.queryParameters['buscar'], 'ANA');

      const nuevo = OperadorCredencial(
        id: 0,
        nombres: ' ANA ',
        apellidos: ' PEREZ ',
        ci: ' 123456 ',
        cargo: ' OPERADORA ',
        telefono: ' 77712345 ',
      );
      final creado = await repo.guardar(nuevo);
      expect(creado.id, 9);
      expect(peticiones.last.method, 'POST');
      expect(jsonDecode(peticiones.last.body), {
        'nombres': 'ANA',
        'apellidos': 'PEREZ',
        'ci': '123456',
        'cargo': 'OPERADORA',
        'telefono': '77712345',
      });
      await repo.guardar(creado);
      expect(peticiones.last.method, 'PUT');
      expect(peticiones.last.url.path, '/api/v1/credenciales-operadores/9');
      await repo.eliminar(9);
      expect(peticiones.last.method, 'DELETE');
      expect(
        peticiones.every(
          (p) => p.headers['authorization'] == 'Bearer sesion-prueba',
        ),
        isTrue,
      );
      api.cerrar();
    },
  );

  test(
    'la reseña es común y el PDF se descarga autenticado sin URL externa',
    () async {
      final peticiones = <http.Request>[];
      final api = ApiClient(
        cliente: MockClient((peticion) async {
          peticiones.add(peticion);
          if (peticion.url.path.endsWith('.pdf')) {
            return http.Response.bytes(
              [37, 80, 68, 70],
              200,
              headers: {
                'content-type': 'application/pdf',
                'content-disposition': 'attachment; filename="operador-9.pdf"',
              },
            );
          }
          return http.Response(
            jsonEncode({'resena': 'Autorizado por Carrasco'}),
            200,
          );
        }),
      )..usarToken('token');
      final repo = OperadorCredencialRepository(api);
      expect(await repo.resena(), 'Autorizado por Carrasco');
      await repo.guardarResena('  Reseña nueva  ');
      expect(
        peticiones.last.url.path,
        '/api/v1/credenciales-operadores/configuracion',
      );
      expect(jsonDecode(peticiones.last.body), {'resena': 'Reseña nueva'});
      final pdf = await repo.pdf(9, cara: 'REVERSO');
      expect(peticiones.last.url.queryParameters, {'cara': 'REVERSO'});
      expect(peticiones.last.headers['authorization'], 'Bearer token');
      expect(pdf.nombreArchivo, 'operador-9.pdf');
      expect(pdf.bytes, [37, 80, 68, 70]);
      api.cerrar();
    },
  );

  test('la vista previa reutiliza firma ejecutiva sin datos de productor', () {
    final previa = OperadorCredencialPrevia.desdeJson({
      ...registro,
      'resena': 'Autorización común',
      'federacion': 'CARRASCO TROPICAL',
      'ejecutivo': {
        'nombre': 'EJECUTIVO',
        'cargo': 'SECRETARIO EJECUTIVO',
        'firmaUrl': '/archivos/firma.png',
      },
    });
    expect(previa.tarjeta.ejecutivoFederacion?.firmaUrl, '/archivos/firma.png');
    expect(previa.tarjeta.lotes, isEmpty);
    expect(previa.tarjeta.fotoUrl, isNull);
    expect(previa.valores, {
      'CARGO': 'OPERADORA',
      'TELEFONO': '77712345',
      'RESENA': 'Autorización común',
    });
  });
}
