import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/texto_busqueda.dart';

void main() {
  test('busca nombres sin exigir ñ ni tildes', () {
    final nombre = textoParaBusqueda('José Ángel Peña Muñoz');

    expect(nombre, 'JOSE ANGEL PENA MUNOZ');
    expect(nombre, contains(textoParaBusqueda('pena munoz')));
    expect(nombre, contains(textoParaBusqueda('José Ángel')));
  });
}
