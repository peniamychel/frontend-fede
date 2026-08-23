import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/estados.dart';

/// Cédulas asignadas a más de una persona.
///
/// El backend devuelve solo las cédulas repetidas, no los productores: hay que
/// pedir por separado quiénes comparten cada una. Por eso la lista se despliega
/// bajo demanda, y no de golpe.
///
/// Antes esta pantalla servía también para los carnés de productor, y por eso
/// venía parametrizada. Ese dato se eliminó del padrón, y con un solo caso la
/// parametrización solo agregaba ruido.
class DuplicadosPagina extends StatefulWidget {
  const DuplicadosPagina({super.key});

  @override
  State<DuplicadosPagina> createState() => _DuplicadosPaginaState();
}

class _DuplicadosPaginaState extends State<DuplicadosPagina> {
  late Future<List<String>> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).productores;
    setState(() {
      _futuro = repo.cedulasDuplicadas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cédulas duplicadas'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<List<String>>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, cedulas) {
          if (cedulas.isEmpty) {
            return const SinResultados(
              icono: Icons.check_circle_outline,
              mensaje: 'No hay cédulas repetidas.',
              detalle: 'Cada cédula corresponde a una sola persona.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: cedulas.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _FilaDuplicado(cedula: cedulas[i]),
          );
        },
      ),
    );
  }
}

class _FilaDuplicado extends StatefulWidget {
  const _FilaDuplicado({required this.cedula});

  final String cedula;

  @override
  State<_FilaDuplicado> createState() => _FilaDuplicadoState();
}

class _FilaDuplicadoState extends State<_FilaDuplicado> {
  Future<List<Productor>>? _futuro;

  void _cargarSiHaceFalta(bool abierto) {
    if (!abierto || _futuro != null) return;
    final repo = PadronScope.of(context).productores;
    setState(() {
      _futuro = repo.porCedula(widget.cedula);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.badge_outlined),
      title: Text(
        widget.cedula,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
      ),
      subtitle: const Text('Tocá para ver quiénes comparten esta cédula'),
      onExpansionChanged: _cargarSiHaceFalta,
      children: [
        if (_futuro == null)
          const SizedBox(height: 4)
        else
          CargaAsync<List<Productor>>(
            futuro: _futuro!,
            constructor: (context, productores) {
              if (productores.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No se encontraron productores.'),
                );
              }
              return Column(
                children: [
                  for (final p in productores)
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: 56, right: 16),
                      leading: const Icon(Icons.person_outline, size: 20),
                      title: Text(
                        p.nombreCompleto.isEmpty
                            ? p.nombres
                            : p.nombreCompleto,
                      ),
                      subtitle: Text(p.ruta),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductorDetallePagina(productorId: p.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
