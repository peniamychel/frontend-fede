import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../credenciales/pliego_previa_pagina.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../productores/fila_productor.dart';
import '../productores/productor_detalle_pagina.dart';
import '../productores/productor_formulario.dart';
import '../widgets/estados.dart';
import '../widgets/lista_paginada.dart';
import 'edicion_productores_sindicato_pagina.dart';

/// Productores de un sindicato concreto.
///
/// Se llega desde la jerarquía, tocando el sindicato. Usa el mismo endpoint
/// paginado que el padrón completo, fijando el filtro `sindicatoId`.
class SindicatoProductoresControlador {
  _SindicatoProductoresPaginaState? _estado;

  /// Recarga las páginas visibles sin perder la posición de desplazamiento.
  Future<void> refrescar() async {
    await _estado?._lista.currentState?.refrescarConservandoPosicion();
    await _estado?._recargarTotal();
  }

  Future<void> refrescarTotal() async => _estado?._recargarTotal();

  void actualizarProductor(Productor productor) {
    final anterior = _estado?._lista.currentState?.actualizarElemento(
      productor,
      coincide: (fila) => fila.id == productor.id,
    );
    if (anterior != null &&
        (anterior.ci != productor.ci ||
            anterior.ciDuplicada != productor.ciDuplicada)) {
      _estado?._lista.currentState?.refrescarConservandoPosicion();
    }
  }

  void _conectar(_SindicatoProductoresPaginaState estado) => _estado = estado;

  void _desconectar(_SindicatoProductoresPaginaState estado) {
    if (identical(_estado, estado)) _estado = null;
  }
}

class SindicatoProductoresPagina extends StatefulWidget {
  const SindicatoProductoresPagina({
    super.key,
    required this.sindicato,
    this.controlador,
    this.alCambiarProductores,
    this.alAbrirProductor,
    this.antesDeEditarLista,
  });

  final Sindicato sindicato;
  final SindicatoProductoresControlador? controlador;
  final VoidCallback? alCambiarProductores;
  final Future<bool> Function(Productor productor)? alAbrirProductor;
  final Future<bool> Function()? antesDeEditarLista;

  @override
  State<SindicatoProductoresPagina> createState() =>
      _SindicatoProductoresPaginaState();
}

class _SindicatoProductoresPaginaState
    extends State<SindicatoProductoresPagina> {
  final GlobalKey<ListaPaginadaState<Productor>> _lista = GlobalKey();
  final TextEditingController _buscador = TextEditingController();
  Timer? _rebote;
  String _texto = '';
  OrdenProductores _orden = OrdenProductores.apellidos;
  int? _productorSeleccionadoId;
  int? _totalProductores;
  int _solicitudTotal = 0;

  @override
  void initState() {
    super.initState();
    widget.controlador?._conectar(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recargarTotal();
    });
  }

  @override
  void didUpdateWidget(covariant SindicatoProductoresPagina oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controlador, widget.controlador)) {
      oldWidget.controlador?._desconectar(this);
      widget.controlador?._conectar(this);
    }
    if (oldWidget.sindicato.id != widget.sindicato.id) {
      _totalProductores = null;
      _recargarTotal();
    }
  }

  @override
  void dispose() {
    widget.controlador?._desconectar(this);
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

  Future<void> _recargarTotal() async {
    final sindicatoId = widget.sindicato.id;
    final solicitud = ++_solicitudTotal;
    try {
      final pagina = await PadronScope.of(context).productores.listar(
        sindicatoId: sindicatoId,
        paginacion: const Paginacion(tamano: 1),
      );
      if (!mounted ||
          solicitud != _solicitudTotal ||
          widget.sindicato.id != sindicatoId) {
        return;
      }
      setState(() => _totalProductores = pagina.totalElementos);
    } catch (_) {
      // La lista muestra su propio error de red; se conserva el último total.
    }
  }

  @override
  Widget build(BuildContext context) {
    final padron = PadronScope.of(context);
    final s = widget.sindicato;
    final total = _totalProductores ?? s.totalProductores ?? 0;
    final ventana = MediaQuery.sizeOf(context);
    final movilVertical = ventana.width < 600 && ventana.height > ventana.width;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: movilVertical
            ? MediaQuery.textScalerOf(context).scale(64) + 8
            : null,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (movilVertical)
              _nombreCompletoMovil(context, s.nombre)
            else
              Text(s.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Central ${s.centralNombre} · '
              '$total ${total == 1 ? 'productor' : 'productores'}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (!movilVertical &&
              context.mostrarEdicionRapidaProductores &&
              (context.puedeRegistrarProductores ||
                  context.puede('NUMERO_LOTE_EDITAR') ||
                  context.puede('LOTES_EDITAR') ||
                  context.puede('SIE_REVISAR') ||
                  context.puede('PRODUCTORES_OBSERVAR')))
            IconButton(
              tooltip: 'Edición rápida de productores',
              onPressed: _editarLista,
              icon: const Icon(Icons.table_view_outlined),
            ),
          PopupMenuButton<OrdenProductores>(
            tooltip: 'Ordenar productores',
            initialValue: _orden,
            icon: const Icon(Icons.sort_by_alpha),
            onSelected: (orden) => setState(() => _orden = orden),
            itemBuilder: (context) => [
              for (final orden in OrdenProductores.values.where(
                (orden) => orden != OrdenProductores.recientes,
              ))
                PopupMenuItem(
                  value: orden,
                  child: Row(
                    children: [
                      Icon(
                        orden == _orden ? Icons.check : Icons.sort,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(orden.etiqueta),
                    ],
                  ),
                ),
            ],
          ),
          if (!movilVertical && !context.accesoCentral)
            IconButton(
              tooltip: 'Estado e impresión de carnets',
              onPressed: _abrirImpresionMasiva,
              icon: const Icon(Icons.badge_outlined),
            ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: () {
              _lista.currentState?.refrescar();
              _recargarTotal();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: context.puedeRegistrarProductores
          ? FloatingActionButton.extended(
              onPressed: _crear,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Nuevo'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _buscador,
              onChanged: _alEscribir,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, apellido, cédula o código',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscador.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _rebote?.cancel();
                          _buscador.clear();
                          setState(() => _texto = '');
                        },
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListaPaginada<Productor>(
              key: _lista,
              clave: 'sindicato-${s.id}-${_orden.name}-$_texto',
              cargar: (paginacion) => padron.productores.listar(
                sindicatoId: s.id,
                texto: _texto.isEmpty ? null : _texto,
                orden: _orden,
                paginacion: paginacion,
              ),
              vacio: SinResultados(
                icono: Icons.person_search_outlined,
                mensaje: _texto.isEmpty
                    ? 'Este sindicato no tiene productores.'
                    : 'Ningún productor coincide con la búsqueda.',
                detalle: _texto.isEmpty && context.puedeRegistrarProductores
                    ? 'Registrá el primero: va a quedar asignado a «${s.nombre}» '
                          'sin que tengas que elegirlo.'
                    : 'Probá con otro nombre, apellido, cédula o código.',
                accion: _texto.isEmpty && !context.puedeRegistrarProductores
                    ? null
                    : _texto.isEmpty
                    ? FilledButton.icon(
                        onPressed: _crear,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Registrar productor'),
                      )
                    : TextButton.icon(
                        onPressed: () {
                          _rebote?.cancel();
                          _buscador.clear();
                          setState(() => _texto = '');
                        },
                        icon: const Icon(Icons.search_off),
                        label: const Text('Quitar búsqueda'),
                      ),
              ),
              // La ruta se oculta: acá todas las filas pertenecen al mismo
              // sindicato, así que repetirla solo gasta espacio.
              constructor: (context, p) => FilaProductor(
                productor: p,
                mostrarRuta: false,
                seleccionado: p.id == _productorSeleccionadoId,
                alTocar: () => _abrir(p),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nombreCompletoMovil(BuildContext context, String nombre) => SizedBox(
    height: MediaQuery.textScalerOf(context).scale(48),
    child: LayoutBuilder(
      builder: (context, limites) {
        final estilo = DefaultTextStyle.of(context).style.copyWith(height: 1.1);
        var tamano = estilo.fontSize ?? 20;
        final medidor = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 3,
        );
        // Medir el nombre completo evita los puntos suspensivos. Se conservan
        // las palabras en varias líneas antes de reducir la letra.
        while (true) {
          medidor.text = TextSpan(
            text: nombre,
            style: estilo.copyWith(fontSize: tamano),
          );
          medidor.layout(maxWidth: limites.maxWidth);
          if ((!medidor.didExceedMaxLines &&
                  medidor.height <= limites.maxHeight) ||
              tamano <= 1) {
            break;
          }
          tamano -= 0.5;
        }
        medidor.dispose();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            nombre,
            maxLines: 3,
            softWrap: true,
            overflow: TextOverflow.clip,
            style: estilo.copyWith(fontSize: tamano),
          ),
        );
      },
    ),
  );

  Future<void> _abrir(Productor p) async {
    if (widget.alAbrirProductor case final abrir?) {
      final abierto = await abrir(p);
      if (abierto && mounted) {
        setState(() => _productorSeleccionadoId = p.id);
      }
      return;
    }
    setState(() => _productorSeleccionadoId = p.id);
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorDetallePagina(
          productorId: p.id,
          alActualizar: (productor) => _lista.currentState?.actualizarElemento(
            productor,
            coincide: (fila) => fila.id == productor.id,
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _productorSeleccionadoId = p.id);
    if (cambio == true) {
      await _lista.currentState?.refrescarConservandoPosicion();
      await _recargarTotal();
      if (mounted) widget.alCambiarProductores?.call();
    }
  }

  Future<void> _abrirImpresionMasiva() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PliegoPreviaPagina(sindicato: widget.sindicato),
      ),
    );
    if (mounted) {
      await _lista.currentState?.refrescarConservandoPosicion();
      if (mounted) widget.alCambiarProductores?.call();
    }
  }

  Future<void> _editarLista() async {
    if (!context.mostrarEdicionRapidaProductores) return;
    if (widget.antesDeEditarLista != null &&
        !await widget.antesDeEditarLista!()) {
      return;
    }
    if (!mounted) return;
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EdicionProductoresSindicatoPagina(sindicato: widget.sindicato),
      ),
    );
    if (cambio == true && mounted) {
      await _lista.currentState?.refrescarConservandoPosicion();
      await _recargarTotal();
      if (mounted) widget.alCambiarProductores?.call();
    }
  }

  /// Abre el alta con el sindicato ya puesto: es el sentido de tener el botón
  /// acá y no mandar al usuario a la sección Productores.
  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorFormulario(sindicatoFijo: widget.sindicato),
      ),
    );
    if (creado == true && mounted) {
      await _lista.currentState?.refrescar();
      await _recargarTotal();
      if (mounted) widget.alCambiarProductores?.call();
    }
  }
}
