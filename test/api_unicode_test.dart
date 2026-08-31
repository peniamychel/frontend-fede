import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fede/core/api_client.dart';

void main() {
  test('envía y recibe JSON UTF-8 conservando ñ y tildes', () async {
    late http.Request enviada;
    final cliente = MockClient((peticion) async {
      enviada = peticion;
      return http.Response.bytes(
        utf8.encode('{"nombre":"JOSÉ PEÑA MUÑOZ"}'),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiClient(cliente: cliente);

    final respuesta = await api.crear('/prueba-unicode', {
      'nombre': 'JOSÉ PEÑA MUÑOZ',
    });

    expect(enviada.headers['content-type'], contains('charset=utf-8'));
    expect(utf8.decode(enviada.bodyBytes), contains('JOSÉ PEÑA MUÑOZ'));
    expect((respuesta as Map<String, dynamic>)['nombre'], 'JOSÉ PEÑA MUÑOZ');
  });
}
