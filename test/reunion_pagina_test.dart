import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/reuniones/reunion_pagina.dart';

/// La reunión en cuadros, con un servidor fingido.
///
/// Cada cuadro es un momento distinto de la asamblea —quién convoca, llamar
/// lista, el acta, los vetos— y lo que se verifica acá es que estén los cuatro
/// y que cada uno diga lo suyo sin invadir al de al lado. Antes era una sola
/// pantalla larga con el acta y los vetos enredados en el pase de lista.
void main() {
  Map<String, dynamic> reunion({
    bool cerrada = false,
    bool vetosHabilitados = false,
    List<Map<String, dynamic>> hojas = const [],
    String? codigoActa = '12/2026',
    int presentes = 0,
  }) =>
      {
        'id': 1,
        'tipo': 'AMPLIADO',
        'tipoEtiqueta': 'Ampliado de central',
        'tipoDetalle': 'Asisten todos los productores de la central.',
        'convoca': 'CENTRAL',
        'convocanteId': 9,
        'convocanteNombre': 'IVIRGARZAMA',
        'titulo': 'Ampliado ordinario de agosto',
        'fecha': '2026-08-15',
        'lugar': 'Sede de la central',
        'observaciones': null,
        'cerrada': cerrada,
        'convocados': 48,
        'presentes': presentes,
        'tieneActa': hojas.isNotEmpty,
        'codigoActa': hojas.isEmpty ? null : codigoActa,
        'vetosHabilitados': vetosHabilitados,
        'hojasActa': hojas,
        'auditoria': null,
      };

  Map<String, dynamic> llamada({
    required int id,
    required int numero,
    required String etiqueta,
    bool abierta = false,
    int presentes = 0,
    String? nota,
  }) =>
      {
        'id': id,
        'reunionId': 1,
        'numero': numero,
        'etiqueta': etiqueta,
        'abierta': abierta,
        'cerradaEn': abierta ? null : '2026-08-15T10:32:00',
        'nota': nota,
        'presentes': presentes,
      };

  Widget pantalla(_ApiPorRuta api) => TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: ReunionPagina(reunionId: 1)),
        ),
      );

  testWidgets('los cuatro cuadros aparecen y no revienta', (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Ampliado ordinario de agosto'), findsOneWidget);
    expect(find.text('15/08/2026'), findsOneWidget);
    expect(find.text('Llamar lista'), findsWidgets);
    expect(find.text('Acta'), findsOneWidget);
    expect(find.text('Vetos'), findsOneWidget);
  });

  testWidgets('sin llamadas invita a llamar por primera vez', (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(find.text('Todavía no se llamó lista.'), findsOneWidget);
    expect(find.text('Llamar lista'), findsWidgets);
    expect(find.text('Otra llamada'), findsNothing);
  });

  testWidgets('con varias vueltas muestra el resumen de cada una',
      (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(presentes: 33),
      '/reuniones/1/llamadas': [
        llamada(id: 5, numero: 1, etiqueta: 'Primera llamada', presentes: 31),
        llamada(
            id: 6,
            numero: 2,
            etiqueta: 'Segunda llamada',
            abierta: true,
            presentes: 12,
            nota: 'Después del cuarto intermedio'),
      ],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(find.text('Primera llamada'), findsOneWidget);
    expect(find.text('Segunda llamada'), findsOneWidget);
    // El resumen de la reunión cuenta a cada uno una sola vez, aunque haya
    // venido a las dos vueltas: 33 y no 43.
    expect(find.textContaining('33 estuvieron'), findsOneWidget);
    expect(find.textContaining('31 presentes'), findsOneWidget);
    expect(find.textContaining('Después del cuarto intermedio'), findsOneWidget);
    // Con una abierta no se ofrece abrir otra sin cerrarla.
    expect(find.textContaining('Cerrala antes de abrir otra'), findsOneWidget);
  });

  testWidgets('el acta se lista hoja por hoja', (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(hojas: [
        {
          'id': 11,
          'orden': 1,
          'nombre': 'cuaderno-1.jpg',
          'tipoMime': 'image/jpeg',
          'tamanoBytes': 820000,
        },
        {
          'id': 12,
          'orden': 2,
          'nombre': 'cuaderno-2.jpg',
          'tipoMime': 'image/jpeg',
          'tamanoBytes': 910000,
        },
      ]),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(find.text('2 hojas'), findsOneWidget);
    expect(find.text('cuaderno-1.jpg'), findsOneWidget);
    expect(find.text('cuaderno-2.jpg'), findsOneWidget);
    expect(find.text('Imagen · 801 KB'), findsOneWidget);
    expect(find.text('Agregar otra hoja'), findsOneWidget);
    // El número del acta, arriba de las hojas: es lo que permite volver al
    // libro a cotejar.
    expect(find.text('Acta N° 12/2026'), findsOneWidget);
    expect(find.text('Corregir'), findsOneWidget);
  });

  testWidgets('un acta sin número se marca y ofrece ponérselo', (tester) async {
    // Las que se cargaron antes de que el sistema lo pidiera quedaron así, y
    // el número no se puede inventar: hay que ir a mirarlo al libro.
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(codigoActa: null, hojas: [
        {
          'id': 11,
          'orden': 1,
          'nombre': 'acta.pdf',
          'tipoMime': 'application/pdf',
          'tamanoBytes': 40000,
        },
      ]),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(find.text('Sin número de acta'), findsOneWidget);
    expect(find.text('Ponerlo'), findsOneWidget);
    expect(find.textContaining('Acta N°'), findsNothing);
  });

  testWidgets('sin acta, subir empieza preguntando el número', (tester) async {
    // Se pregunta antes de abrir el selector: quien sube tiene el libro
    // abierto adelante en ese momento.
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    // El cuadro del acta es el tercero: en una pantalla de 600 px de alto hay
    // que bajar hasta él antes de tocarlo.
    await tester.ensureVisible(find.text('Subir la primera hoja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir la primera hoja'));
    await tester.pumpAndSettle();

    expect(find.text('Número del acta'), findsOneWidget);
    expect(find.text('N° de acta *'), findsOneWidget);
    expect(find.text('Elegir el archivo'), findsOneWidget);

    // Vacío no pasa: sin número la foto no se puede cotejar con el original.
    await tester.tap(find.text('Elegir el archivo'));
    await tester.pumpAndSettle();
    expect(find.text('Poné el número del acta'), findsOneWidget);
  });

  testWidgets('los vetos vienen apagados y no muestran nada abajo',
      (tester) async {
    // No toda asamblea es para sancionar: si estuviera abierto siempre,
    // invitaría a usarlo donde no corresponde.
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    final interruptor = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile));
    expect(interruptor.value, isFalse);
    expect(find.textContaining('Activalo solo si'), findsOneWidget);
    expect(find.textContaining('Todavía no se vetó'), findsNothing);
  });

  testWidgets('habilitados y sin acta, avisa que falta el documento',
      (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(vetosHabilitados: true),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(find.textContaining('Falta subir el acta'), findsOneWidget);
  });

  testWidgets('habilitados y con acta, lista lo que se decidió',
      (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(vetosHabilitados: true, hojas: [
        {
          'id': 11,
          'orden': 1,
          'nombre': 'acta.pdf',
          'tipoMime': 'application/pdf',
          'tamanoBytes': 40000,
        },
      ]),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': [
        {
          'id': 3,
          'productorId': 7,
          'productorNombre': 'JUAN MORALES',
          'motivo': 'Vendió fuera del cupo autorizado',
          'desde': '2026-08-15',
          'vigente': true,
        },
      ],
    })));
    await tester.pump();
    // Dos veces: la lista de vetos es una consulta aparte de la reunión.
    await tester.pump();

    expect(find.text('JUAN MORALES'), findsOneWidget);
    expect(find.text('Vetado · Vendió fuera del cupo autorizado'),
        findsOneWidget);
    expect(find.textContaining('Falta subir el acta'), findsNothing);
    // Las dos direcciones, con el mismo peso: en una asamblea se hacen las dos.
    expect(find.text('Vetar a alguien'), findsOneWidget);
    expect(find.text('Quitar un veto'), findsOneWidget);
  });

  testWidgets('sin acta no ofrece vetar, aunque estén habilitados',
      (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(vetosHabilitados: true),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(find.text('Vetar a alguien'), findsNothing);
    expect(find.text('Quitar un veto'), findsNothing);
  });

  testWidgets('el veto que esta reunión levantó se lee al revés',
      (tester) async {
    // Sin distinguirlo, «ANA QUISPE» aparecería igual habiendo sido sancionada
    // o habiendo sido perdonada, que es lo contrario.
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(vetosHabilitados: true, hojas: [
        {
          'id': 11,
          'orden': 1,
          'nombre': 'acta.pdf',
          'tipoMime': 'application/pdf',
          'tamanoBytes': 40000,
        },
      ]),
      '/reuniones/1/llamadas': const <Object>[],
      '/vetos/reunion/1': [
        {
          'id': 3,
          'productorId': 7,
          'productorNombre': 'ANA QUISPE',
          'motivo': 'Vendió fuera del cupo',
          'motivoLevantamiento': 'Cumplió la sanción y regularizó',
          'desde': '2026-03-12',
          'hasta': '2026-08-15',
          'vigente': false,
          'reunion': {
            'id': 2,
            'titulo': 'Asamblea de marzo',
            'fecha': '2026-03-12',
          },
          'reunionLevanta': {
            'id': 1,
            'titulo': 'Ampliado ordinario de agosto',
            'fecha': '2026-08-15',
          },
        },
      ],
    })));
    await tester.pump();
    await tester.pump();

    expect(find.text('ANA QUISPE'), findsOneWidget);
    expect(find.text('Sacado de la lista · Cumplió la sanción y regularizó'),
        findsOneWidget);
  });

  testWidgets('con la lista cerrada no se ofrece llamar', (tester) async {
    await tester.pumpWidget(pantalla(_ApiPorRuta({
      '/reuniones/1': reunion(cerrada: true),
      '/reuniones/1/llamadas': [
        llamada(id: 5, numero: 1, etiqueta: 'Primera llamada', presentes: 31),
      ],
      '/vetos/reunion/1': const <Object>[],
    })));
    await tester.pump();

    expect(find.text('Cerrada'), findsOneWidget);
    expect(find.text('Otra llamada'), findsNothing);
    expect(find.text('Reabrir'), findsOneWidget);
  });
}

/// Un ApiClient que responde según la ruta y no llama a ningún servidor.
class _ApiPorRuta extends ApiClient {
  _ApiPorRuta(this.respuestas);

  final Map<String, Object> respuestas;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    final respuesta = respuestas[ruta];
    if (respuesta == null) {
      throw StateError('La pantalla pidió $ruta, que la prueba no finge.');
    }
    return respuesta;
  }
}
