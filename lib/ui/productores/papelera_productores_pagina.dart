import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

class PapeleraProductoresPagina extends StatefulWidget {
  const PapeleraProductoresPagina({super.key});

  @override
  State<PapeleraProductoresPagina> createState() =>
      _PapeleraProductoresPaginaState();
}

class _PapeleraProductoresPaginaState extends State<PapeleraProductoresPagina> {
  late Future<List<ProductorPapelera>> _futuro;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() => _futuro = PadronScope.of(context).productores.papelera());
  }

  Future<void> _restaurar(ProductorPapelera productor) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Restaurar productor'),
        content: Text(
          '¿Devolver a ${productor.nombre} al padrón de '
          '${productor.sindicato}? Se conservarán su ficha, fotos e historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _procesando = true);
    try {
      await PadronScope.of(context).productores.restaurar(productor.id);
      if (!mounted) return;
      mostrarExito(context, '${productor.nombre} volvió al padrón');
      _recargar();
    } catch (e) {
      if (mounted) {
        mostrarError(context, e);
        _recargar();
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminarDefinitivamente(ProductorPapelera productor) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Eliminar definitivamente'),
        content: Text(
          '¿Eliminar definitivamente a ${productor.nombre} '
          '(CI ${productor.ci ?? 'sin cédula'})?\n\n'
          'Se borrarán su ficha, fotografías e historial asociado, incluidas '
          'asistencias y registros de impresión. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _procesando = true);
    try {
      await PadronScope.of(
        context,
      ).productores.eliminarDefinitivamente(productor.id);
      if (!mounted) return;
      mostrarExito(
        context,
        '${productor.nombre} fue eliminado definitivamente',
      );
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Papelera de productores'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _recargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: CargaAsync<List<ProductorPapelera>>(
      futuro: _futuro,
      alReintentar: _recargar,
      constructor: (context, productores) {
        if (productores.isEmpty) {
          return const SinResultados(
            icono: Icons.delete_outline,
            mensaje: 'La papelera está vacía.',
          );
        }
        return ListView.separated(
          itemCount: productores.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = productores[i];
            final fecha = p.eliminadoEn;
            final fechaTexto =
                '${fecha.day.toString().padLeft(2, '0')}/'
                '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (p.ci != null && p.ci!.isNotEmpty) Text('CI ${p.ci}'),
                      Text('${p.central} › ${p.sindicato}'),
                      Text('En papelera desde $fechaTexto'),
                      if (!p.restaurable)
                        Text(
                          p.impedimento ?? 'No se puede restaurar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: p.restaurable && !_procesando
                                ? () => _restaurar(p)
                                : null,
                            icon: const Icon(Icons.restore),
                            label: const Text('Restaurar'),
                          ),
                          TextButton.icon(
                            onPressed: _procesando
                                ? null
                                : () => _eliminarDefinitivamente(p),
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Eliminar definitivamente'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
