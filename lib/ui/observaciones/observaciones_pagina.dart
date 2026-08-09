import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/boton_tema.dart';
import '../widgets/estados.dart';
import '../widgets/lista_paginada.dart';

/// Bandeja de trabajo: qué falta revisar del padrón.
///
/// Nota sobre el backend: `ObservacionResponse` trae `productorId` pero no el
/// nombre del productor, así que las filas muestran el id. Agregar
/// `productorNombre` al DTO ahorraría una consulta por fila y haría la bandeja
/// legible de un vistazo.
class ObservacionesPagina extends StatefulWidget {
  const ObservacionesPagina({super.key});

  @override
  State<ObservacionesPagina> createState() => _ObservacionesPaginaState();
}

class _ObservacionesPaginaState extends State<ObservacionesPagina> {
  final TextEditingController _buscador = TextEditingController();
  final GlobalKey<ListaPaginadaState<Observacion>> _lista = GlobalKey();

  Timer? _rebote;
  String _texto = '';
  bool _soloPendientes = true;

  @override
  void dispose() {
    _rebote?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  void _alEscribir(String valor) {
    _rebote?.cancel();
    _rebote = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _texto = valor.trim());
    });
  }

  String get _clave => '$_texto|$_soloPendientes';

  @override
  Widget build(BuildContext context) {
    final padron = PadronScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Observaciones'),
        actions: [
          const BotonTema(),
          IconButton(
            tooltip: 'Recargar',
            onPressed: () => _lista.currentState?.refrescar(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscador,
                    onChanged: _alEscribir,
                    decoration: InputDecoration(
                      hintText: 'Buscar en el texto de la observación',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buscador.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _buscador.clear();
                                setState(() => _texto = '');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Solo pendientes'),
                  selected: _soloPendientes,
                  onSelected: (v) => setState(() => _soloPendientes = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListaPaginada<Observacion>(
              key: _lista,
              clave: _clave,
              cargar: (paginacion) => padron.observaciones.listar(
                texto: _texto.isEmpty ? null : _texto,
                soloPendientes: _soloPendientes ? true : null,
                paginacion: paginacion,
              ),
              vacio: SinResultados(
                icono: _soloPendientes
                    ? Icons.task_alt
                    : Icons.flag_outlined,
                mensaje: _soloPendientes
                    ? 'No queda nada pendiente.'
                    : 'No hay observaciones.',
                detalle: _soloPendientes
                    ? 'Todas las observaciones están resueltas.'
                    : 'Se crean desde la ficha de cada productor.',
              ),
              constructor: (context, o) => _FilaObservacion(
                observacion: o,
                alAlternar: () => _alternar(o),
                alAbrirProductor: () => _abrirProductor(o.productorId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _alternar(Observacion o) async {
    final repo = PadronScope.of(context).observaciones;
    try {
      if (o.resuelta) {
        await repo.reabrir(o.id);
      } else {
        await repo.resolver(o.id);
      }
      if (!mounted) return;
      _lista.currentState?.refrescar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _abrirProductor(int id) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorDetallePagina(productorId: id),
      ),
    );
    if (cambio == true) _lista.currentState?.refrescar();
  }
}

class _FilaObservacion extends StatelessWidget {
  const _FilaObservacion({
    required this.observacion,
    required this.alAlternar,
    required this.alAbrirProductor,
  });

  final Observacion observacion;
  final VoidCallback alAlternar;
  final VoidCallback alAbrirProductor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      onTap: alAbrirProductor,
      leading: Icon(
        observacion.resuelta
            ? Icons.check_circle_outline
            : Icons.error_outline,
        color: observacion.resuelta
            ? tema.colorScheme.primary
            : tema.colorScheme.error,
      ),
      title: Text(
        observacion.mensaje,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: observacion.resuelta ? TextDecoration.lineThrough : null,
          color: observacion.resuelta ? tema.colorScheme.outline : null,
        ),
      ),
      subtitle: Text(
        'Productor #${observacion.productorId}'
        '${observacion.resueltaEn != null ? '  ·  resuelta el ${_fecha(observacion.resueltaEn!)}' : ''}',
        style: tema.textTheme.bodySmall,
      ),
      trailing: TextButton(
        onPressed: alAlternar,
        child: Text(observacion.resuelta ? 'Reabrir' : 'Resolver'),
      ),
    );
  }

  static String _fecha(DateTime d) {
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    return '$dd/$mm/${l.year}';
  }
}
