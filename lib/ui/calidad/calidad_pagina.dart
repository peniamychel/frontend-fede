import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/boton_tema.dart';
import '../widgets/estados.dart';
import 'duplicados_pagina.dart';
import 'lotes_desconocidos_pagina.dart';
import 'sin_foto_pagina.dart';
import '../vetos/vetados_pagina.dart';

/// Panel de saneamiento del padrón.
///
/// Reúne los endpoints de diagnóstico que el backend expone y que ninguna otra
/// pantalla usa: duplicados de cédula y carné, productores sin foto y lotes con
/// estado sin reconocer.
class CalidadPagina extends StatefulWidget {
  const CalidadPagina({super.key});

  @override
  State<CalidadPagina> createState() => _CalidadPaginaState();
}

class _CalidadPaginaState extends State<CalidadPagina> {
  late Future<_Resumen> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    // Cuerpo de bloque y no de flecha: `() => _futuro = ...` devolvería el
    // Future de la asignación, y setState rechaza un callback que devuelva uno.
    setState(() {
      _futuro = _Resumen.cargar(PadronScope.of(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calidad de datos'),
        actions: [
          const BotonTema(),
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<_Resumen>(
        futuro: _futuro,
        alReintentar: _recargar,
        mensajeCarga: 'Analizando el padrón…',
        constructor: (context, resumen) => RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _Cabecera(total: resumen.totalProductores),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, restricciones) {
                  final columnas = switch (restricciones.maxWidth) {
                    >= 1100 => 3,
                    >= 700 => 2,
                    _ => 1,
                  };
                  return GridView.count(
                    crossAxisCount: columnas,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columnas == 1 ? 3.2 : 1.9,
                    children: [
                      _Tarjeta(
                        icono: Icons.block,
                        titulo: 'Vetados',
                        valor: resumen.vetados,
                        detalle: 'Su credencial no se emite',
                        alTocar: () => _ir(const VetadosPagina()),
                      ),
                      _Tarjeta(
                        icono: Icons.no_photography_outlined,
                        titulo: 'Productores sin foto',
                        valor: resumen.sinFoto,
                        detalle: resumen.totalProductores > 0
                            ? '${resumen.porcentajeSinFoto}% del padrón'
                            : 'Sin rótulo de fotografía',
                        alTocar: () => _ir(const SinFotoPagina()),
                      ),
                      _Tarjeta(
                        icono: Icons.badge_outlined,
                        titulo: 'Cédulas duplicadas',
                        valor: resumen.cedulasDuplicadas,
                        detalle: 'Asignadas a más de una persona',
                        alTocar: () => _ir(
                          const DuplicadosPagina(),
                        ),
                      ),
                      _Tarjeta(
                        icono: Icons.help_outline,
                        titulo: 'Lotes sin reconocer',
                        valor: resumen.lotesDesconocidos,
                        detalle: 'El estado de origen no se pudo normalizar',
                        alTocar: () => _ir(const LotesDesconocidosPagina()),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ir(Widget pagina) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pagina))
        .then((_) {
      if (mounted) _recargar();
    });
  }
}

/// Los contadores del panel, pedidos todos a la vez.
class _Resumen {
  const _Resumen({
    required this.totalProductores,
    required this.sinFoto,
    required this.cedulasDuplicadas,
    required this.lotesDesconocidos,
    required this.vetados,
  });

  final int totalProductores;
  final int sinFoto;
  final int cedulasDuplicadas;
  final int lotesDesconocidos;

  /// Cuántos están observados por decisión de asamblea.
  final int vetados;

  int get porcentajeSinFoto =>
      totalProductores == 0 ? 0 : (sinFoto * 100 / totalProductores).round();

  /// Las cinco consultas van en paralelo: son independientes entre sí y el
  /// panel no puede pintar nada hasta tenerlas todas.
  static Future<_Resumen> cargar(Padron padron) async {
    // Pedimos una sola fila: lo único que interesa es totalElements.
    const sonda = Paginacion(tamano: 1);

    final resultados = await Future.wait([
      padron.productores.listar(paginacion: sonda),
      padron.productores.sinFoto(paginacion: sonda),
      padron.productores.cedulasDuplicadas(),
      padron.lotes.estadoDesconocido(),
      padron.vetos.buscar(),
    ]);

    return _Resumen(
      totalProductores: (resultados[0] as Pagina<Productor>).totalElementos,
      sinFoto: (resultados[1] as Pagina<Productor>).totalElementos,
      cedulasDuplicadas: (resultados[2] as List<String>).length,
      lotesDesconocidos: (resultados[3] as List<Lote>).length,
      vetados: (resultados[4] as List<Veto>).length,
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      color: tema.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.fact_check_outlined,
                size: 32, color: tema.colorScheme.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == 0
                        ? 'El padrón está vacío'
                        : '$total productores en el padrón',
                    style: tema.textTheme.titleLarge?.copyWith(
                      color: tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'Los indicadores se llenan cuando se carguen datos.'
                        : 'Cada tarjeta abre la lista de lo que hay que corregir.',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final int valor;
  final String detalle;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final resaltado = valor > 0;
    final tinte = tema.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icono,
                      size: 20,
                      color: resaltado ? tinte : tema.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      style: tema.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (alTocar != null)
                    Icon(Icons.chevron_right,
                        size: 18, color: tema.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$valor',
                style: tema.textTheme.displaySmall?.copyWith(
                  color: resaltado ? tinte : tema.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detalle,
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
