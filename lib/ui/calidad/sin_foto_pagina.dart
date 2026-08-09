import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/estados.dart';
import '../widgets/lista_paginada.dart';

/// Productores sin rótulo de fotografía cargado.
class SinFotoPagina extends StatefulWidget {
  const SinFotoPagina({super.key});

  @override
  State<SinFotoPagina> createState() => _SinFotoPaginaState();
}

class _SinFotoPaginaState extends State<SinFotoPagina> {
  final GlobalKey<ListaPaginadaState<Productor>> _lista = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final padron = PadronScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Productores sin foto')),
      body: ListaPaginada<Productor>(
        key: _lista,
        clave: 'sin-foto',
        cargar: (paginacion) => padron.productores.sinFoto(
          paginacion: paginacion,
        ),
        vacio: const SinResultados(
          icono: Icons.photo_camera_outlined,
          mensaje: 'Todos tienen fotografía.',
          detalle: 'No queda ningún productor sin rótulo cargado.',
        ),
        constructor: (context, p) => ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person_off_outlined, size: 20),
          ),
          title: Text(
            p.nombreCompleto.isEmpty ? p.nombres : p.nombreCompleto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(p.ruta, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () async {
            final cambio = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => ProductorDetallePagina(productorId: p.id),
              ),
            );
            if (cambio == true) _lista.currentState?.refrescar();
          },
        ),
      ),
    );
  }
}
