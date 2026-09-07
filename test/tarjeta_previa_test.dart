import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/models/credencial_previa.dart';
import 'package:fede/models/diseno_credencial.dart';
import 'package:fede/ui/credenciales/tarjeta_previa.dart';

/// La tarjeta de la vista previa tiene que verse como el PDF.
///
/// Esta es la prueba de un error real: los cuerpos de letra del dibujo estaban
/// elegidos a ojo y salían bastante más chicos que en el papel. Una vista
/// previa que no coincide con lo que se imprime no sirve para nada, así que acá
/// se fija la única regla que lo impide: **cada medida del dibujo es una medida
/// del generador multiplicada por una sola escala**.
///
/// Los textos fijos están rasterizados en las dos plantillas. Esta prueba fija
/// los cuerpos de los únicos textos variables que se dibujan encima.
void main() {
  /// El doble de la tarjeta real: la escala da 2 justo y las cuentas se leen.
  const anchoDelDoble = TarjetaPrevia.anchoPt * 2;

  CredencialPrevia previa({
    String? codigoPadron = '2-IVI-1',
    String apellidos = 'COLQUECHAMBI MAMANI',
    FirmantePrevio? ejecutivoFederacion = const FirmantePrevio(
      nombre: 'ANA QUISPE',
      cargo: 'EJECUTIVO',
      organizacion: 'FEDERACIÓN CARRASCO',
      tieneFirma: true,
    ),
    FirmantePrevio? secretarioGeneralCentral = const FirmantePrevio(
      nombre: 'BRUNO LIMACHI',
      cargo: 'SECRETARIO GENERAL',
      organizacion: 'IVIRGARZAMA',
      tieneFirma: false,
    ),
    FirmantePrevio? secretarioGeneralSindicato = const FirmantePrevio(
      nombre: 'CARLA MAMANI',
      cargo: 'SECRETARIO GENERAL',
      organizacion: 'ALTO SAN SALVADOR',
      tieneFirma: true,
    ),
  }) => CredencialPrevia(
    productorId: 1,
    nombreCompleto: 'CANDIDO $apellidos',
    federacion: 'FEDERACIÓN CARRASCO',
    central: 'IVIRGARZAMA',
    sindicato: 'ALTO SAN SALVADOR',
    nombres: 'CANDIDO',
    apellidos: apellidos,
    ci: '3692655',
    lotes: '12-A',
    codigoPadron: codigoPadron,
    codigoQr: 'AB12CD34EF',
    // Sin foto: cargar una imagen de red en una prueba de widget fallaría.
    fotoUrl: null,
    ejecutivoFederacion: ejecutivoFederacion,
    secretarioGeneralCentral: secretarioGeneralCentral,
    secretarioGeneralSindicato: secretarioGeneralSindicato,
    faltantes: const [],
    completa: true,
  );

  Widget banco({
    required bool reverso,
    CredencialPrevia? datos,
    DisenoCredencial? diseno,
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: TarjetaPrevia(
          previa: datos ?? previa(),
          reverso: reverso,
          ancho: anchoDelDoble,
          diseno: diseno,
        ),
      ),
    ),
  );

  final cuerposDelGenerador = <double>[
    TarjetaPrevia.rotuloPt,
    TarjetaPrevia.valorPt,
    TarjetaPrevia.numeroPlantillaPt,
    TarjetaPrevia.firmaNombrePt,
    TarjetaPrevia.firmaCargoPt,
    TarjetaPrevia.firmaOrganizacionPt,
  ].map((pt) => pt * 2).toSet();

  Iterable<Text> textosDe(WidgetTester tester) => tester.widgetList<Text>(
    find.descendant(
      of: find.byType(TarjetaPrevia),
      matching: find.byType(Text),
    ),
  );

  testWidgets('la tarjeta mide lo que una cédula', (tester) async {
    await tester.pumpWidget(banco(reverso: false));

    final caja = tester.getSize(find.byType(TarjetaPrevia));
    expect(caja.width, anchoDelDoble);
    expect(caja.height, closeTo(TarjetaPrevia.altoPt * 2, 0.01));
    // 85,6 × 54 mm: la proporción de una cédula.
    expect(caja.width / caja.height, closeTo(1.586, 0.005));
  });

  for (final reverso in [false, true]) {
    for (final anchoPantalla in [320.0, 390.0, 740.0]) {
      testWidgets(
        'escala toda la tarjeta en pantalla $anchoPantalla, reverso $reverso',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          Future<List<Rect>> dibujar(
            double anchoPantalla,
            double escalaTexto,
          ) async {
            tester.view.physicalSize = Size(anchoPantalla, 1000);
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MediaQuery(
                          data: MediaQueryData(
                            textScaler: TextScaler.linear(escalaTexto),
                          ),
                          child: TarjetaPrevia(
                            previa: previa(),
                            reverso: reverso,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final tarjetaFinder = find.byType(TarjetaPrevia);
            final tarjeta = tester.getRect(tarjetaFinder);
            final esperado = (anchoPantalla - 48).clamp(0.0, 420.0);
            expect(tarjeta.width, closeTo(esperado, .01));
            expect(
              tarjeta.height,
              closeTo(
                esperado * TarjetaPrevia.altoPt / TarjetaPrevia.anchoPt,
                .01,
              ),
            );

            // Medidas proyectadas en pantalla de todos los objetos del diseño:
            // foto, textos, QR, sellos, firmas y plantilla. Cada uno debe mantener
            // las mismas coordenadas relativas, no solo el fondo de la tarjeta.
            final rectangulos = <Rect>[];
            for (final elemento
                in find
                    .descendant(
                      of: tarjetaFinder,
                      matching: find.byType(Positioned),
                    )
                    .evaluate()) {
              final caja = elemento.findRenderObject()! as RenderBox;
              final inicio = caja.localToGlobal(Offset.zero) - tarjeta.topLeft;
              final fin =
                  caja.localToGlobal(
                    Offset(caja.size.width, caja.size.height),
                  ) -
                  tarjeta.topLeft;
              rectangulos.add(
                Rect.fromLTRB(
                  inicio.dx / tarjeta.width,
                  inicio.dy / tarjeta.height,
                  fin.dx / tarjeta.width,
                  fin.dy / tarjeta.height,
                ),
              );
            }
            for (final elemento
                in find
                    .descendant(of: tarjetaFinder, matching: find.byType(Text))
                    .evaluate()) {
              expect(MediaQuery.textScalerOf(elemento), TextScaler.noScaling);
            }
            expect(tester.takeException(), isNull);
            return rectangulos;
          }

          final grande = await dibujar(1000, 1);
          final movil = await dibujar(anchoPantalla, 1.6);
          expect(movil.length, grande.length);
          expect(movil, isNotEmpty);
          for (var i = 0; i < grande.length; i++) {
            expect(movil[i].left, closeTo(grande[i].left, .0001));
            expect(movil[i].top, closeTo(grande[i].top, .0001));
            expect(movil[i].width, closeTo(grande[i].width, .0001));
            expect(movil[i].height, closeTo(grande[i].height, .0001));
          }
        },
      );
    }
  }

  testWidgets('ningún texto del anverso usa un cuerpo inventado', (
    tester,
  ) async {
    await tester.pumpWidget(banco(reverso: false));

    final textos = textosDe(tester).toList();
    expect(textos, isNotEmpty);
    for (final texto in textos) {
      expect(
        cuerposDelGenerador,
        contains(texto.style?.fontSize),
        reason:
            '«${texto.data}» usa un cuerpo que no está en el generador; '
            'toda medida del dibujo tiene que salir de ahí',
      );
    }
  });

  testWidgets('ningún texto del reverso usa un cuerpo inventado', (
    tester,
  ) async {
    await tester.pumpWidget(banco(reverso: true));

    final textos = textosDe(tester).toList();
    expect(textos, isNotEmpty);
    for (final texto in textos) {
      expect(
        cuerposDelGenerador,
        contains(texto.style?.fontSize),
        reason: '«${texto.data}» usa un cuerpo que no está en el generador',
      );
    }
  });

  testWidgets('el número y los datos usan los cuerpos del nuevo generador', (
    tester,
  ) async {
    await tester.pumpWidget(banco(reverso: false));

    Text texto(String cual) => tester.widget<Text>(
      find.descendant(
        of: find.byType(TarjetaPrevia),
        matching: find.text(cual),
      ),
    );

    expect(
      texto('CANDIDO COLQUECHAMBI MAMANI').style?.fontSize,
      TarjetaPrevia.valorPt * 2,
    );
    expect(
      texto('2-IVI-1').style?.fontSize,
      TarjetaPrevia.numeroPlantillaPt * 2,
    );
  });

  testWidgets('el anverso lleva lo mismo que imprime el PDF', (tester) async {
    await tester.pumpWidget(banco(reverso: false));

    for (final esperado in [
      'CANDIDO COLQUECHAMBI MAMANI',
      'CARRASCO',
      'IVIRGARZAMA',
      'ALTO SAN SALVADOR',
      '12-A',
      '2-IVI-1',
    ]) {
      expect(find.text(esperado), findsOneWidget, reason: 'falta «$esperado»');
    }
  });

  testWidgets('la vista previa aplica la fuente elegida al texto', (
    tester,
  ) async {
    final base = DisenoCredencial.predeterminado();
    final editado = DisenoCredencial(
      ancho: base.ancho,
      alto: base.alto,
      elementos: [
        for (final elemento in base.elementos)
          elemento.campo == 'NOMBRE_COMPLETO'
              ? elemento.copiar(fuente: FuenteCredencial.merriweather)
              : elemento,
      ],
    );

    await tester.pumpWidget(banco(reverso: false, diseno: editado));

    final nombre = tester.widget<Text>(
      find.text('CANDIDO COLQUECHAMBI MAMANI'),
    );
    expect(nombre.style?.fontFamily, 'CredencialMerriweather');
  });

  testWidgets('sin código del padrón el hueco se marca, no se deja en blanco', (
    tester,
  ) async {
    await tester.pumpWidget(
      banco(reverso: false, datos: previa(codigoPadron: null)),
    );

    expect(find.text('FALTA'), findsOneWidget);
  });

  testWidgets('el reverso muestra los tres niveles y sus pies automáticos', (
    tester,
  ) async {
    await tester.pumpWidget(banco(reverso: true));

    expect(find.text('EJECUTIVO'), findsOneWidget);
    expect(find.text('SECRETARIO GENERAL'), findsNWidgets(2));
    expect(find.text('BRUNO LIMACHI'), findsOneWidget);
    expect(find.text('CARLA MAMANI'), findsOneWidget);
  });

  testWidgets('la imagen de pie de firma reemplaza el texto automático', (
    tester,
  ) async {
    const url = '/api/v1/archivos/pies-firma/ejecutivo.png';
    await tester.pumpWidget(
      banco(
        reverso: true,
        datos: previa(
          ejecutivoFederacion: const FirmantePrevio(
            nombre: 'ANA QUISPE',
            cargo: 'EJECUTIVO',
            organizacion: 'FEDERACIÓN CARRASCO',
            firmaUrl: '/api/v1/archivos/firmas/ejecutivo.png',
            pieFirmaUrl: url,
          ),
        ),
      ),
    );

    expect(find.text('ANA QUISPE'), findsNothing);
    expect(find.text('EJECUTIVO'), findsNothing);
    final imagenesDeRed = tester
        .widgetList<Image>(find.byType(Image))
        .where((imagen) => imagen.image is NetworkImage);
    expect(
      imagenesDeRed
          .map((imagen) => (imagen.image as NetworkImage).url)
          .where((direccion) => direccion.endsWith(url)),
      hasLength(1),
    );
  });

  testWidgets('la firma opcional del sindicato no se marca como faltante', (
    tester,
  ) async {
    await tester.pumpWidget(
      banco(reverso: true, datos: previa(secretarioGeneralSindicato: null)),
    );

    expect(find.text('SIN FIRMANTE'), findsNothing);
  });

  testWidgets('todo se dibuja dentro de la tarjeta, nada se sale', (
    tester,
  ) async {
    // El PDF recorta lo que se pase del borde y no se ve; acá pasaría lo mismo.
    for (final reverso in [false, true]) {
      await tester.pumpWidget(banco(reverso: reverso));
      final tarjeta = tester.getRect(find.byType(TarjetaPrevia));

      for (final texto
          in find
              .descendant(
                of: find.byType(TarjetaPrevia),
                matching: find.byType(Text),
              )
              .evaluate()) {
        final caja = tester.getRect(find.byWidget(texto.widget));
        expect(
          tarjeta.contains(caja.topLeft),
          isTrue,
          reason:
              '«${(texto.widget as Text).data}» empieza fuera de la '
              'tarjeta (reverso: $reverso)',
        );
        expect(
          caja.bottom,
          lessThanOrEqualTo(tarjeta.bottom + 0.5),
          reason:
              '«${(texto.widget as Text).data}» se pasa por abajo '
              '(reverso: $reverso)',
        );
      }
    }
  });
}
