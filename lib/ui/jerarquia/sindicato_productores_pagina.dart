import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/fila_productor.dart';
import '../productores/productor_detalle_pagina.dart';
import '../productores/productor_formulario.dart';
import '../widgets/descargas.dart';
import '../widgets/estados.dart';
import '../widgets/lista_paginada.dart';

/// Productores de un sindicato concreto.
///
/// Se llega desde la jerarquía, tocando el sindicato. Usa el mismo endpoint
/// paginado que el padrón completo, fijando el filtro `sindicatoId`.
class SindicatoProductoresPagina extends StatefulWidget {
  const SindicatoProductoresPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<SindicatoProductoresPagina> createState() =>
      _SindicatoProductoresPaginaState();
}

class _SindicatoProductoresPaginaState
    extends State<SindicatoProductoresPagina> {
  final GlobalKey<ListaPaginadaState<Productor>> _lista = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final padron = PadronScope.of(context);
    final s = widget.sindicato;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Central ${s.centralNombre}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Descargar la nómina en PDF, lista para imprimir',
            onPressed: () => descargarInformeSindicato(context, s),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Imprimir las credenciales de todo el sindicato',
            onPressed: () => descargarCredencialesSindicato(context, s),
            icon: const Icon(Icons.badge_outlined),
          ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: () => _lista.currentState?.refrescar(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo'),
      ),
      body: ListaPaginada<Productor>(
        key: _lista,
        clave: 'sindicato-${s.id}',
        cargar: (paginacion) => padron.productores.listar(
          sindicatoId: s.id,
          paginacion: paginacion,
        ),
        vacio: SinResultados(
          icono: Icons.person_search_outlined,
          mensaje: 'Este sindicato no tiene productores.',
          detalle: 'Registrá el primero: va a quedar asignado a «${s.nombre}» '
              'sin que tengas que elegirlo.',
          accion: FilledButton.icon(
            onPressed: _crear,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Registrar productor'),
          ),
        ),
        // La ruta se oculta: acá todas las filas pertenecen al mismo sindicato,
        // así que repetirla en cada una solo gasta espacio.
        constructor: (context, p) => FilaProductor(
          productor: p,
          mostrarRuta: false,
          alTocar: () => _abrir(p),
        ),
      ),
    );
  }

  Future<void> _abrir(Productor p) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorDetallePagina(productorId: p.id),
      ),
    );
    if (cambio == true) _lista.currentState?.refrescar();
  }

  /// Abre el alta con el sindicato ya puesto: es el sentido de tener el botón
  /// acá y no mandar al usuario a la sección Productores.
  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorFormulario(sindicatoFijo: widget.sindicato),
      ),
    );
    if (creado == true) _lista.currentState?.refrescar();
  }
}
