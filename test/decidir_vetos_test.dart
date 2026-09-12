import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/reuniones/decidir_vetos.dart';

/// Poner y quitar vetos desde la reunión, con un servidor fingido.
///
/// Lo que se verifica es el camino que hace quien está en la asamblea: escribe
/// el nombre, la cédula o el código, elige a la persona de la lista, y recién
/// entonces escribe el motivo. Sin haber elegido a nadie no se puede aceptar, y
/// sin motivo tampoco: las dos cosas son lo que hace que el veto sea una
/// decisión y no una anotación.
void main() {
  final reunion = Reunion(
    id: 1,
    tipo: TipoReunion.ampliado,
    convocanteId: 9,
    convocanteNombre: 'IVIRGARZAMA',
    titulo: 'Ampliado ordinario de agosto',
    fecha: DateTime(2026, 8, 15),
    cerrada: false,
    tieneActa: true,
    vetosHabilitados: true,
    convocados: 48,
    presentes: 31,
  );

  Map<String, dynamic> productor({
    required int id,
    required String nombres,
    String apellidos = 'MORALES',
    String? ci,
    String? codigoPadron,
  }) => {
    'id': id,
    'nombres': nombres,
    'apellidos': apellidos,
    'nombreCompleto': '$nombres $apellidos',
    'ci': ci,
    'codigoPadron': codigoPadron,
    'sindicatoId': 16,
    'sindicatoNombre': 'LIBERTAD',
    'centralId': 20,
    'centralNombre': 'IVIRGARZAMA',
    'tieneFoto': false,
    'marcado': false,
  };

  Map<String, dynamic> pagina(List<Map<String, dynamic>> contenido) => {
    'content': contenido,
    'number': 0,
    'size': 20,
    'totalElements': contenido.length,
    'totalPages': 1,
  };

  /// Un botón que abre el diálogo, para poder tocarlo desde la prueba.
  Widget pantalla(_ApiEspia api, {required bool vetar}) => TemaScope(
    preferencia: PreferenciaTema(),
    child: PadronScope(
      padron: Padron(api: api),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => vetar
                    ? vetarEnLaReunion(context, reunion)
                    : levantarEnLaReunion(context, reunion),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> abrir(WidgetTester tester) async {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// Escribe en el buscador y espera a que pase el respiro de 350 ms.
  Future<void> buscar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextField).first, texto);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('la reunión ya está decidida: no se pregunta cuál', (
    tester,
  ) async {
    await tester.pumpWidget(pantalla(_ApiEspia(), vetar: true));
    await abrir(tester);

    // Antes había un desplegable de reuniones acá. Ahora la asamblea es esta.
    expect(
      find.text('Vetar en «Ampliado ordinario de agosto»'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<Reunion?>), findsNothing);
  });

  testWidgets('con menos de dos letras no busca nada', (tester) async {
    // Con el padrón entero detrás, una consulta por letra sería una consulta
    // por letra.
    final api = _ApiEspia();
    await tester.pumpWidget(pantalla(api, vetar: true));
    await abrir(tester);

    await buscar(tester, 'J');

    expect(api.rutasPedidas, isEmpty);
    expect(find.textContaining('al menos dos letras'), findsOneWidget);
  });

  testWidgets('busca por nombre, cédula o código y ofrece a quien encuentra', (
    tester,
  ) async {
    final api = _ApiEspia({
      '/productores': pagina([
        productor(id: 7, nombres: 'JUAN', ci: '3434', codigoPadron: '2IVI1'),
        productor(id: 8, nombres: 'JUANA', ci: '9090', codigoPadron: '2IVI4'),
      ]),
    });
    await tester.pumpWidget(pantalla(api, vetar: true));
    await abrir(tester);

    await buscar(tester, 'JUAN');

    expect(api.rutasPedidas, ['/productores']);
    expect(api.ultimoTexto, 'JUAN');
    expect(find.text('JUAN MORALES'), findsOneWidget);
    expect(find.text('JUANA MORALES'), findsOneWidget);
    // Cada línea trae con qué reconocerlo, que es de lo que se habla en la
    // asamblea cuando hay dos apellidos iguales.
    expect(find.text('CI 3434 · 2IVI1 · LIBERTAD'), findsOneWidget);
  });

  testWidgets('sin elegir a nadie no se puede aceptar', (tester) async {
    await tester.pumpWidget(pantalla(_ApiEspia(), vetar: true));
    await abrir(tester);

    final boton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Vetar'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('elegido a alguien, pide el motivo y lo exige', (tester) async {
    final api = _ApiEspia({
      '/productores': pagina([
        productor(id: 7, nombres: 'JUAN', ci: '3434', codigoPadron: '2IVI1'),
      ]),
    });
    await tester.pumpWidget(pantalla(api, vetar: true));
    await abrir(tester);
    await buscar(tester, 'JUAN');

    await tester.tap(find.text('JUAN MORALES'));
    await tester.pumpAndSettle();

    // La búsqueda se guarda y queda quien se eligió, con la salida para
    // cambiarlo.
    expect(find.text('Buscar a la persona'), findsNothing);
    expect(find.text('JUAN MORALES'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(find.text('Por qué se lo veta *'), findsOneWidget);

    // Aceptar sin motivo no guarda nada.
    await tester.tap(find.text('Vetar'));
    await tester.pumpAndSettle();
    expect(find.text('Hay que decir el motivo'), findsOneWidget);
    expect(api.creados, isEmpty);
  });

  testWidgets('con motivo, veta en esta reunión', (tester) async {
    final api = _ApiEspia({
      '/productores': pagina([
        productor(id: 7, nombres: 'JUAN', ci: '3434', codigoPadron: '2IVI1'),
      ]),
    });
    await tester.pumpWidget(pantalla(api, vetar: true));
    await abrir(tester);
    await buscar(tester, '2IVI1');
    await tester.tap(find.text('JUAN MORALES'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'Vendió fuera del cupo, según el acta',
    );
    await tester.tap(find.text('Vetar'));
    await tester.pumpAndSettle();

    expect(api.creados, hasLength(1));
    final enviado = api.creados.single;
    expect(enviado.ruta, '/vetos');
    expect(enviado.cuerpo['productorId'], 7);
    expect(enviado.cuerpo['reunionId'], 1, reason: 'la reunión es esta');
    expect(enviado.cuerpo['motivo'], contains('cupo'));
  });

  testWidgets('para quitar, busca entre los vetados igual que para poner', (
    tester,
  ) async {
    final api = _ApiEspia({
      '/vetos': [
        {
          'id': 3,
          'productorId': 7,
          'productorNombre': 'JUAN MORALES',
          'ci': '3434',
          'codigoPadron': '2IVI1',
          'motivo': 'Vendió fuera del cupo',
          'desde': '2026-03-12',
          'vigente': true,
          'reunion': {
            'id': 2,
            'titulo': 'Asamblea de marzo',
            'fecha': '2026-03-12',
          },
        },
      ],
    });
    await tester.pumpWidget(pantalla(api, vetar: false));
    await abrir(tester);

    expect(
      find.text('Sacar de la lista en «Ampliado ordinario de agosto»'),
      findsOneWidget,
    );

    await buscar(tester, '3434');

    expect(api.rutasPedidas, ['/vetos']);
    expect(find.text('JUAN MORALES'), findsOneWidget);
    // Se ve por qué está vetado y quién lo vetó: es lo que se lee en el acta.
    expect(
      find.textContaining('vetado en «Asamblea de marzo»'),
      findsOneWidget,
    );
    expect(find.text('Vendió fuera del cupo'), findsOneWidget);
  });

  testWidgets('no se ofrece levantar lo que esta misma reunión vetó', (
    tester,
  ) async {
    // La asamblea que vetó no puede desdecirse en el mismo acto.
    final api = _ApiEspia({
      '/vetos': [
        {
          'id': 3,
          'productorId': 7,
          'productorNombre': 'JUAN MORALES',
          'motivo': 'Vendió fuera del cupo',
          'desde': '2026-08-15',
          'vigente': true,
          'reunion': {
            'id': 1,
            'titulo': 'Ampliado ordinario de agosto',
            'fecha': '2026-08-15',
          },
        },
      ],
    });
    await tester.pumpWidget(pantalla(api, vetar: false));
    await abrir(tester);

    await buscar(tester, 'JUAN');

    expect(find.text('JUAN MORALES'), findsNothing);
    expect(find.textContaining('Nadie vetado con ese nombre'), findsOneWidget);
  });

  testWidgets('con motivo, levanta el veto en esta reunión', (tester) async {
    final api = _ApiEspia({
      '/vetos': [
        {
          'id': 3,
          'productorId': 7,
          'productorNombre': 'JUAN MORALES',
          'motivo': 'Vendió fuera del cupo',
          'desde': '2026-03-12',
          'vigente': true,
          'reunion': {
            'id': 2,
            'titulo': 'Asamblea de marzo',
            'fecha': '2026-03-12',
          },
        },
      ],
    });
    await tester.pumpWidget(pantalla(api, vetar: false));
    await abrir(tester);
    await buscar(tester, 'JUAN');
    await tester.tap(find.text('JUAN MORALES'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'Cumplió la sanción, según el acta',
    );
    await tester.tap(find.text('Levantar'));
    await tester.pumpAndSettle();

    expect(api.reemplazados, hasLength(1));
    final enviado = api.reemplazados.single;
    expect(enviado.ruta, '/vetos/3/levantar');
    expect(enviado.cuerpo['reunionId'], 1, reason: 'la reunión es esta');
    expect(enviado.cuerpo['motivo'], contains('Cumplió'));
  });
}

class _Llamada {
  const _Llamada(this.ruta, this.cuerpo);

  final String ruta;
  final Map<String, dynamic> cuerpo;
}

/// Un ApiClient que responde por ruta y anota lo que le mandaron.
class _ApiEspia extends ApiClient {
  _ApiEspia([this.respuestas = const {}]);

  final Map<String, Object> respuestas;

  final List<String> rutasPedidas = [];
  final List<_Llamada> creados = [];
  final List<_Llamada> reemplazados = [];

  /// El último texto buscado, para verificar que llegó tal cual se escribió.
  String? ultimoTexto;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    rutasPedidas.add(ruta);
    ultimoTexto = query?['texto'] as String?;
    return respuestas[ruta] ?? const <Object>[];
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    creados.add(_Llamada(ruta, cuerpo as Map<String, dynamic>));
    return {'id': 3, 'productorId': 7, 'productorNombre': 'JUAN MORALES'};
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    reemplazados.add(_Llamada(ruta, cuerpo as Map<String, dynamic>));
    return {'id': 3, 'productorId': 7, 'productorNombre': 'JUAN MORALES'};
  }
}
