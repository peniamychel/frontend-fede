import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

void main() {
  test('interpreta el resumen y los conflictos guardados por el backend', () {
    final conciliacion = ConciliacionUdestro.desdeJson({
      'id': 15,
      'estado': 'BORRADOR',
      'archivo': 'udestro.xlsx',
      'sha256': 'abc',
      'federacionId': 1,
      'federacion': 'CARRASCO TROPICAL',
      'filasExcel': 3,
      'altasSistema': 1,
      'cambiosASistema': 1,
      'observadosPorIdentidad': 1,
      'cambiosABlanco': 1,
      'conservados': 0,
      'conflictos': 1,
      'conflictosPendientes': 1,
      'errores': 0,
      'sindicatosNuevos': [
        {'central': 'IVIRGARZAMA', 'sindicato': 'NUEVO'},
      ],
      'listaParaAplicar': false,
      'creadaEn': '2026-09-09T12:00:00',
      'aplicadaEn': null,
    });

    expect(conciliacion.id, 15);
    expect(conciliacion.estado, EstadoConciliacionUdestro.borrador);
    expect(conciliacion.cambiosTotales, 4);
    expect(conciliacion.observadosPorIdentidad, 1);
    expect(conciliacion.conflictosPendientes, 1);
    expect(conciliacion.sindicatosNuevos.single.sindicato, 'NUEVO');
    expect(conciliacion.listaParaAplicar, isFalse);
  });

  test('interpreta una fila con ambas identidades para decidir', () {
    final pagina = paginaFilasUdestro({
      'content': [
        {
          'id': 22,
          'numeroFila': 8,
          'central': '13 DE JUNIO',
          'sindicato': '1RO DE MAYO',
          'nombresUdestro': 'MACARIO',
          'apellidosUdestro': 'RAMIREZ PEREZ',
          'ci': '123456',
          'sindicatoNuevo': false,
          'accion': 'CONFLICTO_IDENTIDAD',
          'motivo': 'La cédula coincide pero la identidad es diferente.',
          'productorId': null,
          'clasificacionAnterior': null,
          'decision': 'PENDIENTE',
          'productorSeleccionadoId': null,
          'candidatos': [
            {
              'id': 9,
              'nombres': 'JUAN',
              'apellidos': 'RAMOS CORONADO',
              'nombreCompleto': 'JUAN RAMOS CORONADO',
              'ci': '123456',
              'central': '13 DE JUNIO',
              'sindicato': '1RO DE MAYO',
              'clasificacion': 'BLANCO',
              'fotoUrl': '/api/v1/imagenes/9',
            },
          ],
        },
      ],
      'page': {'size': 50, 'number': 0, 'totalElements': 1, 'totalPages': 1},
    });

    final fila = pagina.contenido.single;
    expect(fila.accion, AccionConciliacionUdestro.conflictoIdentidad);
    expect(fila.decision, DecisionConflictoUdestro.pendiente);
    expect(fila.nombreCompleto, 'MACARIO RAMIREZ PEREZ');
    expect(fila.candidatos.single.nombreCompleto, 'JUAN RAMOS CORONADO');
    expect(fila.candidatos.single.clasificacion, EstadoLote.blanco);
  });

  test('interpreta una diferencia automática con su porcentaje', () {
    final pagina = paginaFilasUdestro({
      'content': [
        {
          'id': 23,
          'numeroFila': 9,
          'central': '13 DE JUNIO',
          'sindicato': '1RO DE MAYO',
          'nombresUdestro': 'MARIA',
          'apellidosUdestro': 'CONDORI',
          'ci': '222',
          'sindicatoNuevo': false,
          'accion': 'OBSERVAR_Y_CAMBIAR_A_SISTEMA',
          'motivo': 'El nombre solo tiene 12% de similitud.',
          'productorId': 2,
          'clasificacionAnterior': 'BLANCO',
          'similitudNombre': 12,
          'decision': null,
          'productorSeleccionadoId': null,
          'candidatos': [
            {
              'id': 2,
              'nombres': 'JUAN',
              'apellidos': 'RAMOS',
              'nombreCompleto': 'JUAN RAMOS',
              'ci': '222',
              'central': '13 DE JUNIO',
              'sindicato': '1RO DE MAYO',
              'clasificacion': 'BLANCO',
              'fotoUrl': null,
            },
          ],
        },
      ],
      'page': {'size': 50, 'number': 0, 'totalElements': 1, 'totalPages': 1},
    });

    final fila = pagina.contenido.single;
    expect(fila.accion, AccionConciliacionUdestro.observarYCambiarASistema);
    expect(fila.similitudNombre, 12);
    expect(fila.candidatos.single.nombreCompleto, 'JUAN RAMOS');
  });
}
