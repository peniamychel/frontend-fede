import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../sesion_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/boton_tema.dart';
import '../credenciales/pliego_previa_pagina.dart';
import '../credenciales/informe_impresion_central_pagina.dart';
import '../credenciales/informe_impresion_sindicato_pagina.dart';
import '../credenciales/informe_impresion_federacion_pagina.dart';
import '../lotes/lotes_sindicato_pagina.dart';
import '../vetos/vetados_pagina.dart';
import '../widgets/dialogo_nombre_numero.dart';
import '../widgets/estados.dart';
import '../widgets/marca_estado.dart';
import 'directorio_pagina.dart';
import 'editar_telefono_directorio.dart';
import 'lista_fisica_sindicato_pagina.dart';
import 'sindicato_productores_pagina.dart';
import 'edicion_productores_sindicato_pagina.dart';
import 'edicion_fotos_sindicato_pagina.dart';

/// Navegación por la jerarquía de CARRASCO TROPICAL: Central › Sindicato.
///
/// La federación se resuelve internamente para conservar sus relaciones, pero
/// no se ofrece como nivel editable porque la aplicación trabaja únicamente
/// con CARRASCO TROPICAL.
class JerarquiaControlador extends ChangeNotifier {
  _JerarquiaPaginaState? _estado;

  bool get fichaAbierta => _estado?._productorId != null;

  void _notificarFicha() => notifyListeners();

  /// Intenta volver un nivel dentro de Central › Sindicato.
  /// Devuelve false cuando la jerarquía ya está en la lista de centrales.
  bool retroceder() => _estado?._retroceder() ?? false;

  /// Sincroniza los totales al volver desde otras secciones del padrón.
  void refrescarConteos() {
    _estado?._recargarCentrales();
    _estado?._recargarSindicatos();
    _estado?._controladorProductores.refrescarTotal();
  }

  void _conectar(_JerarquiaPaginaState estado) => _estado = estado;

  void _desconectar(_JerarquiaPaginaState estado) {
    if (identical(_estado, estado)) _estado = null;
  }
}

class JerarquiaPagina extends StatefulWidget {
  const JerarquiaPagina({super.key, this.controlador});

  final JerarquiaControlador? controlador;

  @override
  State<JerarquiaPagina> createState() => _JerarquiaPaginaState();
}

class _JerarquiaPaginaState extends State<JerarquiaPagina> {
  static const _claveCentralFijada = 'jerarquia.central_fijada.carrasco';
  static const _claveOrdenCodigo = 'jerarquia.orden_codigo.carrasco';
  final _controladorProductores = SindicatoProductoresControlador();
  final _controladorFicha = ProductorDetalleControlador();
  GlobalKey _claveListaProductores = GlobalKey();
  GlobalKey _claveFicha = GlobalKey();
  int? _productorId;
  bool _cambiandoFicha = false;
  bool _ordenPorCodigo = false;

  Federacion? _federacion;
  Central? _central;
  Sindicato? _sindicato;
  int? _centralSeleccionadaId;
  int? _sindicatoSeleccionadoId;
  List<int> _centralesFijadasIds = const [];

  late Future<Federacion> _federacionFija;
  Future<List<Central>>? _centrales;
  Future<_DatosSindicatos>? _sindicatos;

  @override
  void initState() {
    super.initState();
    widget.controlador?._conectar(this);
    _federacionFija = _cargarFederacionFija();
    _cargarCentralFijada();
  }

  @override
  void didUpdateWidget(covariant JerarquiaPagina oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controlador, widget.controlador)) {
      oldWidget.controlador?._desconectar(this);
      widget.controlador?._conectar(this);
    }
  }

  @override
  void dispose() {
    widget.controlador?._desconectar(this);
    super.dispose();
  }

  Future<Federacion> _cargarFederacionFija() async {
    final padron = PadronScope.of(context);
    final federacion = await padron.federaciones.deTrabajo();
    _federacion = federacion;
    _centrales = padron.federaciones.centrales(federacion.id);
    return federacion;
  }

  Future<void> _recargarTodo() async {
    if (!await _cerrarFichaActual() || !mounted) return;
    setState(() {
      _federacion = null;
      _central = null;
      _sindicato = null;
      _centrales = null;
      _sindicatos = null;
      _federacionFija = _cargarFederacionFija();
    });
  }

  void _recargarCentrales() {
    final f = _federacion;
    setState(() {
      _centrales = f == null
          ? null
          : PadronScope.of(context).federaciones.centrales(f.id);
    });
  }

  Future<void> _cargarCentralFijada() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final guardado = preferencias.get(_claveCentralFijada);
      final ids = switch (guardado) {
        final int id => [id],
        final List<String> valores =>
          valores.map(int.tryParse).whereType<int>().toList(growable: false),
        _ => const <int>[],
      };
      if (mounted) {
        setState(() {
          _centralesFijadasIds = ids;
          _ordenPorCodigo = preferencias.getBool(_claveOrdenCodigo) ?? false;
        });
      }
    } catch (_) {
      // La lista sigue alfabética si el dispositivo no permite guardar la
      // preferencia. Esta comodidad no debe impedir usar la jerarquía.
    }
  }

  Future<void> _fijarCentral(Central central) async {
    final ids = [..._centralesFijadasIds];
    if (ids.contains(central.id)) {
      ids.remove(central.id);
    } else {
      ids.add(central.id);
    }
    setState(() => _centralesFijadasIds = List.unmodifiable(ids));
    await _guardarCentralesFijadas();
  }

  Future<void> _ordenarCentralesAlfabeticamente() async {
    setState(() {
      _centralesFijadasIds = const [];
      _ordenPorCodigo = false;
    });
    await _guardarCentralesFijadas();
  }

  Future<void> _cambiarOrdenCentrales(String orden) async {
    if (orden == 'restaurar') {
      await _ordenarCentralesAlfabeticamente();
      return;
    }
    setState(() => _ordenPorCodigo = orden == 'codigo');
    await _guardarCentralesFijadas();
  }

  Future<void> _guardarCentralesFijadas() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setBool(_claveOrdenCodigo, _ordenPorCodigo);
      if (_centralesFijadasIds.isEmpty) {
        await preferencias.remove(_claveCentralFijada);
      } else {
        await preferencias.setStringList(
          _claveCentralFijada,
          _centralesFijadasIds.map((id) => '$id').toList(growable: false),
        );
      }
    } catch (_) {
      // El cambio ya se ve durante esta ejecución aunque no pueda persistirse.
    }
  }

  List<Central> _centralesOrdenadas(List<Central> centrales) {
    final resultado = [...centrales];
    resultado.sort((a, b) {
      final posicionA = _centralesFijadasIds.indexOf(a.id);
      final posicionB = _centralesFijadasIds.indexOf(b.id);
      if (posicionA >= 0 && posicionB >= 0) {
        return posicionA.compareTo(posicionB);
      }
      if (posicionA >= 0) return -1;
      if (posicionB >= 0) return 1;
      if (_ordenPorCodigo) {
        final codigoA = (a.abreviatura ?? '').trim().toUpperCase();
        final codigoB = (b.abreviatura ?? '').trim().toUpperCase();
        if (codigoA.isEmpty != codigoB.isEmpty) return codigoA.isEmpty ? 1 : -1;
        final numeroA = int.tryParse(codigoA);
        final numeroB = int.tryParse(codigoB);
        if ((numeroA == null) != (numeroB == null)) {
          return numeroA == null ? 1 : -1;
        }
        final comparacion = numeroA != null && numeroB != null
            ? numeroA.compareTo(numeroB)
            : codigoA.compareTo(codigoB);
        if (comparacion != 0) return comparacion;
      }
      return a.nombre.toUpperCase().compareTo(b.nombre.toUpperCase());
    });
    return resultado;
  }

  void _recargarSindicatos() {
    final c = _central;
    setState(() {
      _sindicatos = c == null ? null : _cargarSindicatos(c);
    });
  }

  Future<_DatosSindicatos> _cargarSindicatos(Central central) async {
    final repositorio = PadronScope.of(context).centrales;
    final sindicatosFuturo = repositorio.sindicatos(central.id);
    final avanceFuturo = repositorio.informeImpresion(central.id);
    final sindicatos = await sindicatosFuturo;
    final avance = await avanceFuturo;
    final porId = {for (final fila in avance.detalle) fila.sindicatoId: fila};
    return _DatosSindicatos(
      sindicatos: [
        for (final sindicato in sindicatos)
          sindicato.conResumenImpresion(
            totalProductores: porId[sindicato.id]?.total ?? 0,
            porcentajeImpresion: porId[sindicato.id]?.porcentajeAvance ?? 0,
            datosCompletos: porId[sindicato.id]?.datosCompletos ?? 0,
            huboFaseImpresion: avance.tieneFasesImpresion,
            estadoImpresionFase: porId[sindicato.id]?.estadoImpresionFase,
          ),
      ],
      totalProductores: avance.total,
    );
  }

  void _marcarCentral(Central central) {
    setState(() {
      if (_centralSeleccionadaId != central.id) _sindicatoSeleccionadoId = null;
      _centralSeleccionadaId = central.id;
    });
  }

  void _marcarSindicato(Sindicato sindicato) {
    setState(() => _sindicatoSeleccionadoId = sindicato.id);
  }

  Future<void> _elegirCentral(Central c) async {
    if (!await _cerrarFichaActual() || !mounted) return;
    setState(() {
      if (_centralSeleccionadaId != c.id) _sindicatoSeleccionadoId = null;
      _centralSeleccionadaId = c.id;
      _central = c;
      _sindicato = null;
    });
    _recargarSindicatos();
  }

  bool _retroceder() {
    if (_productorId != null) {
      _controladorFicha.cerrar();
      return true;
    }
    if (_sindicato != null) {
      setState(() => _sindicato = null);
      return true;
    }
    if (_central != null) {
      setState(() {
        _central = null;
        _sindicatos = null;
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jerarquía'),
        actions: [
          if (context.puede('INFORMES_DESCARGAR'))
            IconButton(
              tooltip: 'Avance general de impresión',
              onPressed: _federacion == null
                  ? null
                  : _verInformeImpresionFederacion,
              icon: const Icon(Icons.assessment_outlined),
            ),
          const BotonTema(),
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargarTodo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<Federacion>(
        futuro: _federacionFija,
        alReintentar: _recargarTodo,
        constructor: (context, _) => LayoutBuilder(
          builder: (context, restricciones) {
            if (_permiteMesaDeTrabajo(restricciones.maxWidth)) {
              return _columnasAnchas(restricciones.maxWidth);
            }
            return _unaColumna();
          },
        ),
      ),
    );
  }

  bool _permiteMesaDeTrabajo(double ancho) => ancho >= 600;

  Widget _columnasAnchas(double ancho) {
    final sindicato = _sindicato;
    // En tablets estrechas se conservan los niveles seleccionados en franjas
    // verticales y se reserva el resto del ancho para un solo panel legible.
    if (ancho < 780 || (ancho < 900 && _productorId != null)) {
      final central = _central;
      if (central == null) return _unaColumna();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnaColapsada(
            icono: Icons.hub_outlined,
            nombre: central.nombre,
            ayuda: 'Cambiar central',
            alTocar: _volverACentrales,
          ),
          const VerticalDivider(width: 1),
          if (sindicato != null) ...[
            _ColumnaColapsada(
              icono: Icons.groups_outlined,
              nombre: sindicato.nombre,
              ayuda: 'Cambiar sindicato',
              alTocar: _volverASindicatos,
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: _productorId != null
                ? _fichaProductor()
                : sindicato != null
                ? _listaProductores(enMesaDeTrabajo: true)
                : _panelSindicatos(enMesaDeTrabajo: true),
          ),
        ],
      );
    }
    if (sindicato != null && _productorId != null) {
      final sindicatosVisibles = ancho >= 1250;
      final anchoLista = (ancho * 0.28).clamp(340.0, 420.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnaColapsada(
            icono: Icons.hub_outlined,
            nombre: _central!.nombre,
            ayuda: 'Cambiar central',
            alTocar: _volverASindicatos,
          ),
          const VerticalDivider(width: 1),
          if (sindicatosVisibles)
            SizedBox(width: 300, child: _panelSindicatos(enMesaDeTrabajo: true))
          else
            _ColumnaColapsada(
              icono: Icons.groups_outlined,
              nombre: sindicato.nombre,
              ayuda: 'Cambiar sindicato',
              alTocar: () => _controladorFicha.cerrar(),
            ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: anchoLista,
            child: _listaProductores(enMesaDeTrabajo: true),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _fichaProductor()),
        ],
      );
    }
    if (sindicato != null && _permiteMesaDeTrabajo(ancho)) {
      final anchoSindicatos = (ancho * 0.30).clamp(300.0, 440.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnaColapsada(
            icono: Icons.hub_outlined,
            nombre: _central!.nombre,
            ayuda: 'Cambiar central',
            alTocar: _volverASindicatos,
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: anchoSindicatos,
            child: _panelSindicatos(enMesaDeTrabajo: true),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _listaProductores(enMesaDeTrabajo: true)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _panelCentrales()),
        const VerticalDivider(width: 1),
        Expanded(
          child: _panelSindicatos(
            enMesaDeTrabajo: _permiteMesaDeTrabajo(ancho),
          ),
        ),
      ],
    );
  }

  Widget _unaColumna() {
    final Widget panel;
    final sindicato = _sindicato;
    if (_productorId != null) {
      panel = _fichaProductor();
    } else if (sindicato != null) {
      // Conserva el sindicato visible al reducir una mesa de trabajo abierta.
      panel = _listaProductores(enMesaDeTrabajo: false);
    } else if (_central != null) {
      panel = _panelSindicatos(enMesaDeTrabajo: false);
    } else {
      panel = _panelCentrales();
    }

    return Column(
      children: [
        if (_central != null) _migaDePan(),
        Expanded(child: panel),
      ],
    );
  }

  Widget _listaProductores({required bool enMesaDeTrabajo}) =>
      SindicatoProductoresPagina(
        key: _claveListaProductores,
        sindicato: _sindicato!,
        controlador: _controladorProductores,
        alCambiarProductores: _recargarSindicatos,
        alAbrirProductor: enMesaDeTrabajo ? _abrirProductor : null,
        antesDeEditarLista: _cerrarFichaActual,
      );

  Widget _fichaProductor() => ProductorDetallePagina(
    key: _claveFicha,
    productorId: _productorId!,
    controlador: _controladorFicha,
    alCerrar: _alCerrarFicha,
    alActualizar: _controladorProductores.actualizarProductor,
  );

  Future<bool> _abrirProductor(Productor productor) async {
    if (_productorId == productor.id) return true;
    if (_cambiandoFicha) return false;
    _cambiandoFicha = true;
    try {
      if (!await _cerrarFichaActual() || !mounted) return false;
      setState(() {
        _claveFicha = GlobalKey();
        _productorId = productor.id;
      });
      widget.controlador?._notificarFicha();
      return true;
    } finally {
      _cambiandoFicha = false;
    }
  }

  Future<bool> _cerrarFichaActual() async =>
      _productorId == null || await _controladorFicha.cerrar();

  Future<void> _alCerrarFicha(bool huboCambios) async {
    if (!mounted) return;
    setState(() => _productorId = null);
    widget.controlador?._notificarFicha();
    if (huboCambios) {
      await _controladorProductores.refrescar();
      if (mounted) _recargarSindicatos();
    }
  }

  Future<void> _volverASindicatos() async {
    if (!await _cerrarFichaActual() || !mounted) return;
    setState(() => _sindicato = null);
  }

  Future<void> _volverACentrales() async {
    if (!await _cerrarFichaActual() || !mounted) return;
    setState(() {
      _sindicato = null;
      _central = null;
      _sindicatos = null;
    });
  }

  Widget _migaDePan() {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              onPressed: _retroceder,
            ),
            Expanded(
              child: Text(
                _central?.nombre ?? '',
                style: tema.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Centrales ----------

  Widget _panelCentrales() {
    final f = _federacion;
    if (f == null) return const SizedBox.shrink();

    return _Panel(
      titulo: 'Centrales de ${f.nombre}',
      detalleTitulo: _centralesFijadasIds.isEmpty
          ? (_ordenPorCodigo
                ? 'Orden por código membretado'
                : 'Orden alfabético')
          : '${_centralesFijadasIds.length} '
                '${_centralesFijadasIds.length == 1 ? 'central fijada' : 'centrales fijadas'} arriba',
      acciones: [
        PopupMenuButton<String>(
          tooltip: 'Ordenar centrales',
          initialValue: _ordenPorCodigo ? 'codigo' : 'nombre',
          onSelected: _cambiarOrdenCentrales,
          icon: const Icon(Icons.sort_by_alpha),
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'nombre',
              checked: !_ordenPorCodigo,
              child: const Text('Orden alfabético'),
            ),
            CheckedPopupMenuItem(
              value: 'codigo',
              checked: _ordenPorCodigo,
              child: const Text('Código membretado'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'restaurar',
              child: Text('Restablecer orden alfabético'),
            ),
          ],
        ),
      ],
      alAgregar: context.puede('JERARQUIA_EDITAR')
          ? () => _crearCentral(f)
          : null,
      hijo: CargaAsync<List<Central>>(
        futuro: _centrales!,
        alReintentar: _recargarCentrales,
        constructor: (context, lista) {
          if (lista.isEmpty) {
            return const SinResultados(
              icono: Icons.hub_outlined,
              mensaje: 'Esta federación no tiene centrales.',
            );
          }
          final ordenadas = _centralesOrdenadas(lista);
          return ListView(
            key: const PageStorageKey<String>('jerarquia-centrales'),
            children: [
              for (final c in ordenadas)
                _DetalleAvanceTooltip(
                  key: ValueKey('avance-central-${c.id}'),
                  revision: _centrales!,
                  cargar: () async {
                    final informe = await PadronScope.of(
                      context,
                    ).centrales.informeImpresion(c.id);
                    final completos = informe.detalle.fold<int>(
                      0,
                      (total, fila) => total + fila.datosCompletos,
                    );
                    final porcentaje = informe.total == 0
                        ? 0
                        : (completos * 100 / informe.total).round();
                    return 'Datos completos: $porcentaje% ($completos/${informe.total})\n'
                        'Avance de impresión: ${informe.porcentajeAvance.round()}%';
                  },
                  child: ListTile(
                    key: ValueKey('central-${c.id}'),
                    selected: _centralSeleccionadaId == c.id,
                    selectedTileColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                    shape: _bordeSeleccion(_centralSeleccionadaId == c.id),
                    leading: IconButton(
                      tooltip: _centralesFijadasIds.contains(c.id)
                          ? 'Quitar de arriba'
                          : 'Fijar arriba',
                      onPressed: () => _fijarCentral(c),
                      icon: Icon(
                        _centralesFijadasIds.contains(c.id)
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: _centralesFijadasIds.contains(c.id)
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    title: TituloConEstado(
                      nombre: c.nombre,
                      habilitado: c.habilitado,
                      etiqueta: c.faseImpresionActivaNumero == null &&
                              c.ultimaFaseImpresionNumero > 0
                          ? _etiquetaEstadoImpresion(
                              'f${c.ultimaFaseImpresionNumero} Impreso',
                              impreso: true,
                            )
                          : null,
                    ),
                    subtitle: _subtituloCentral(c),
                    onTap: () => _elegirCentral(c),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (context.puede('INFORMES_DESCARGAR'))
                          IconButton(
                            tooltip: 'Informes y reportes central',
                            onPressed: () => _verInformeImpresionCentral(c),
                            icon: const Icon(
                              Icons.analytics_outlined,
                              size: 20,
                            ),
                          ),
                        _menu(
                          alAbrir: () => _marcarCentral(c),
                          alEditar: () => _editarCentral(c),
                          alEditarTelefono: () =>
                              _editarTelefonoEnLista(
                                ambito: Ambito.central,
                                id: c.id,
                                nombre: c.nombre,
                              ),
                          alVerDirectorio: () =>
                              _verDirectorio(DirectorioPagina.deCentral(c)),
                          habilitado: c.habilitado,
                          alCambiarEstado: () =>
                              cambiarEstadoConAviso(
                                context,
                                nombre: c.nombre,
                                habilitado: c.habilitado,
                                accion: (estado) => PadronScope.of(
                                  context,
                                ).centrales.cambiarEstado(c.id, estado),
                              ).then((cambio) {
                                if (cambio) _recargarCentrales();
                              }),
                          alEliminar: () => _eliminar(
                            nombre: c.nombre,
                            tipo: 'la central',
                            accion: () => PadronScope.of(
                              context,
                            ).centrales.eliminar(c.id),
                            alTerminar: () {
                              if (_central?.id == c.id) {
                                setState(() {
                                  _central = null;
                                  _sindicato = null;
                                  _sindicatos = null;
                                });
                              }
                              _recargarCentrales();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _crearCentral(Federacion f) async {
    final datos = await DialogoNombreNumero.mostrar(
      context,
      titulo: 'Nueva central',
      etiquetaNombre: 'Nombre de la central',
      segundo: SegundoCampo.abreviatura,
    );
    if (datos == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context).centrales.crear(
        CentralRequest(
          nombre: datos.nombre,
          abreviatura: datos.numero,
          federacionId: f.id,
        ),
      ),
      _recargarCentrales,
    );
  }

  Future<void> _editarCentral(Central c) async {
    final datos = await DialogoNombreNumero.mostrar(
      context,
      titulo: 'Editar central',
      etiquetaNombre: 'Nombre de la central',
      nombreInicial: c.nombre,
      numeroInicial: c.abreviatura,
      segundo: SegundoCampo.abreviatura,
    );
    if (datos == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context).centrales.actualizar(
        c.id,
        CentralRequest(
          nombre: datos.nombre,
          abreviatura: datos.numero,
          federacionId: c.federacionId,
        ),
      ),
      _recargarCentrales,
    );
  }

  Future<void> _verInformeImpresionCentral(Central central) async {
    _marcarCentral(central);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InformeImpresionCentralPagina(central: central),
      ),
    );
    if (mounted) {
      _recargarCentrales();
      _recargarSindicatos();
    }
  }

  Future<void> _verInformeImpresionFederacion() async {
    final federacion = _federacion;
    if (federacion == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            InformeImpresionFederacionPagina(federacion: federacion),
      ),
    );
  }

  // ---------- Sindicatos ----------

  Widget _panelSindicatos({required bool enMesaDeTrabajo}) {
    final c = _central;
    if (c == null) {
      return const _Panel(
        titulo: 'Sindicatos',
        hijo: SinResultados(
          icono: Icons.arrow_back,
          mensaje: 'Elegí una central',
          detalle: 'Sus sindicatos aparecen acá.',
        ),
      );
    }

    return FutureBuilder<_DatosSindicatos>(
      future: _sindicatos!,
      builder: (context, resumen) => _Panel(
        titulo: 'Sindicatos de ${c.nombre}',
        detalleTitulo: resumen.hasData
            ? '${resumen.data!.sindicatos.length} sindicatos · '
                  '${resumen.data!.totalProductores} productores'
            : null,
        alAgregar: context.puede('JERARQUIA_EDITAR')
            ? () => _crearSindicato(c)
            : null,
        hijo: CargaAsync<_DatosSindicatos>(
          futuro: _sindicatos!,
          alReintentar: _recargarSindicatos,
          constructor: (context, datos) {
            final lista = datos.sindicatos;
            if (lista.isEmpty) {
              return const SinResultados(
                icono: Icons.groups_outlined,
                mensaje: 'Esta central no tiene sindicatos.',
              );
            }
            return ListView(
              key: PageStorageKey<String>('jerarquia-sindicatos-${c.id}'),
              children: [
                for (final s in lista)
                  Tooltip(
                    waitDuration: const Duration(milliseconds: 700),
                    message:
                        'Datos completos: ${s.porcentajeDatosCompletos.round()}% '
                        '(${s.datosCompletos ?? 0}/${s.totalProductores ?? 0})\n'
                        'Avance de impresión: ${(s.porcentajeImpresion ?? 0).round()}%',
                    child: ListTile(
                      key: ValueKey('sindicato-${s.id}'),
                      selected: _sindicatoSeleccionadoId == s.id,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                      shape: _bordeSeleccion(_sindicatoSeleccionadoId == s.id),
                      leading: const Icon(Icons.groups_outlined),
                      title: TituloConEstado(
                        nombre: s.nombre,
                        habilitado: s.habilitado,
                        etiqueta: switch (s.estadoImpresionFase) {
                          EstadoImpresionFase.imprimiendo =>
                            _etiquetaEstadoImpresion('Imprimiendo', impreso: false),
                          EstadoImpresionFase.impreso =>
                            _etiquetaEstadoImpresion('Impreso', impreso: true),
                          null => null,
                        },
                      ),
                      subtitle: Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (s.numero != null) ...[
                            Text(
                              'N° ${s.numero}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Text('·'),
                          ],
                          Text('Total: ${s.totalProductores ?? 0}'),
                          if (s.telefono case final telefono?)
                            Text('($telefono)'),
                        ],
                      ),
                      onTap: () =>
                          _verProductores(s, enMesaDeTrabajo: enMesaDeTrabajo),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (context.puede('INFORMES_DESCARGAR'))
                            IconButton(
                              tooltip: 'Informes y reportes del sindicato',
                              onPressed: () => _verInformesSindicato(s),
                              icon: const Icon(
                                Icons.analytics_outlined,
                                size: 20,
                              ),
                            ),
                          _menu(
                            alAbrir: () => _marcarSindicato(s),
                            alEditar: () => _editarSindicato(s),
                            alEditarTelefono: () =>
                                _editarTelefonoEnLista(
                                  ambito: Ambito.sindicato,
                                  id: s.id,
                                  nombre: s.nombre,
                                ),
                            alEditarProductores: () => _editarProductores(s),
                            alEditarFotos: () => _editarFotos(s),
                            alVerDirectorio: () =>
                                _verDirectorio(DirectorioPagina.deSindicato(s)),
                            alVerListaFisica: () => _verListaFisica(s),
                            habilitado: s.habilitado,
                            alCambiarEstado: () =>
                                cambiarEstadoConAviso(
                                  context,
                                  nombre: s.nombre,
                                  habilitado: s.habilitado,
                                  accion: (estado) => PadronScope.of(
                                    context,
                                  ).sindicatos.cambiarEstado(s.id, estado),
                                ).then((cambio) {
                                  if (cambio) _recargarSindicatos();
                                }),
                            alVerLotes: () => _verLotes(s),
                            alVerVetados: () => _verVetados(s),
                            alDescargarCredenciales: () => _verImpresionSindicato(s),
                            alEliminar: () => _eliminar(
                              nombre: s.nombre,
                              tipo: 'el sindicato',
                              accion: () => PadronScope.of(
                                context,
                              ).sindicatos.eliminar(s.id),
                              alTerminar: () {
                                if (_sindicato?.id == s.id) {
                                  setState(() => _sindicato = null);
                                }
                                _recargarSindicatos();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _verProductores(
    Sindicato s, {
    required bool enMesaDeTrabajo,
  }) async {
    if (!await _cerrarFichaActual() || !mounted) return;
    setState(() => _sindicatoSeleccionadoId = s.id);
    // Usa el mismo criterio del LayoutBuilder: el menú lateral ocupa parte
    // del ancho de la ventana y puede dejar espacio para una sola columna.
    if (enMesaDeTrabajo) {
      setState(() {
        if (_sindicato?.id != s.id) _claveListaProductores = GlobalKey();
        _sindicato = s;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SindicatoProductoresPagina(
          sindicato: s,
          alCambiarProductores: _recargarSindicatos,
        ),
      ),
    );
    if (mounted) _recargarSindicatos();
  }

  Future<void> _verInformesSindicato(Sindicato sindicato) async {
    _marcarSindicato(sindicato);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InformeImpresionSindicatoPagina(sindicato: sindicato),
      ),
    );
    if (mounted) _recargarSindicatos();
  }

  Future<void> _verImpresionSindicato(Sindicato sindicato) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PliegoPreviaPagina(sindicato: sindicato)),
    );
    if (!mounted) return;
    _recargarCentrales();
    _recargarSindicatos();
    await _controladorProductores.refrescar();
  }

  Future<void> _editarProductores(Sindicato sindicato) async {
    if (!context.mostrarEdicionRapidaProductores) return;
    if (!await _cerrarFichaActual() || !mounted) return;
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EdicionProductoresSindicatoPagina(sindicato: sindicato),
      ),
    );
    if (cambio == true && mounted) {
      await _controladorProductores.refrescar();
      if (mounted) _recargarSindicatos();
    }
  }

  Future<void> _editarFotos(Sindicato sindicato) async {
    if (SesionScope.maybeOf(context)?.sesion?.esAdministrador != true) return;
    if (!await _cerrarFichaActual() || !mounted) return;
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EdicionFotosSindicatoPagina(sindicato: sindicato),
      ),
    );
    if (cambio == true && mounted) await _controladorProductores.refrescar();
  }

  ShapeBorder? _bordeSeleccion(bool seleccionado) => seleccionado
      ? RoundedRectangleBorder(
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        )
      : null;

  /// Abre el directorio de cualquiera de los tres niveles.
  Future<void> _verDirectorio(DirectorioPagina pagina) async {
    if (!context.mostrarDirectorios) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
    if (!mounted) return;
    if (pagina.ambito == Ambito.central) _recargarCentrales();
    _recargarSindicatos();
  }

  Future<void> _editarTelefonoEnLista({
    required Ambito ambito,
    required int id,
    required String nombre,
  }) async {
    final actualizado = await mostrarEditorTelefonoDirectorio(
      context,
      ambito: ambito,
      id: id,
      nombre: nombre,
    );
    if (!mounted || actualizado == null) return;
    if (ambito == Ambito.central) {
      _recargarCentrales();
    } else {
      _recargarSindicatos();
    }
  }

  Future<void> _verLotes(Sindicato s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LotesSindicatoPagina(sindicato: s)),
    );
    if (mounted) _recargarSindicatos();
  }

  Future<void> _verVetados(Sindicato sindicato) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VetadosPagina(sindicato: sindicato)),
    );
    if (!mounted) return;

    // En escritorio la lista sigue abierta a la derecha. Se refresca sin
    // perder el scroll para que el vetado desaparezca de inmediato.
    await _controladorProductores.refrescar();
    if (!mounted) return;

    final central = _central;
    if (central == null) return;
    final futuro = _cargarSindicatos(central);
    setState(() => _sindicatos = futuro);
    final datos = await futuro;
    if (!mounted || _sindicato?.id != sindicato.id) return;
    final actualizado = datos.sindicatos
        .where((elemento) => elemento.id == sindicato.id)
        .firstOrNull;
    if (actualizado != null) setState(() => _sindicato = actualizado);
  }

  Future<void> _verListaFisica(Sindicato s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ListaFisicaSindicatoPagina(sindicato: s),
      ),
    );
  }

  Future<void> _crearSindicato(Central c) async {
    final datos = await DialogoNombreNumero.mostrar(
      context,
      titulo: 'Nuevo sindicato',
      etiquetaNombre: 'Nombre del sindicato',
    );
    if (datos == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context).sindicatos.crear(
        SindicatoRequest(
          nombre: datos.nombre,
          numero: datos.numero,
          centralId: c.id,
        ),
      ),
      _recargarSindicatos,
    );
  }

  Future<void> _editarSindicato(Sindicato s) async {
    final datos = await DialogoNombreNumero.mostrar(
      context,
      titulo: 'Editar sindicato',
      etiquetaNombre: 'Nombre del sindicato',
      nombreInicial: s.nombre,
      numeroInicial: s.numero,
    );
    if (datos == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context).sindicatos.actualizar(
        s.id,
        SindicatoRequest(
          nombre: datos.nombre,
          numero: datos.numero,
          centralId: s.centralId,
        ),
      ),
      _recargarSindicatos,
    );
  }

  // ---------- Auxiliares ----------

  /// Subtítulo con la sigla de la central, o nada si todavía no se la
  /// asignaron. Se devuelve null y no un texto tipo «sin abreviatura» para no
  /// llenar la lista de ruido: hoy casi ninguna la tiene.
  ///
  /// Va sola, sin etiqueta delante: tres letras en mayúsculas debajo del nombre
  /// completo ya se leen como lo que son.
  Widget? _subtituloCentral(Central central) {
    final abreviatura = central.abreviatura;
    final telefono = central.telefono;
    final fase = central.faseImpresionActivaNumero;
    if (abreviatura == null && telefono == null && fase == null) return null;
    final estilo = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        if (abreviatura != null || telefono != null)
          Text(
            [
              ?abreviatura,
              if (telefono != null) '($telefono)',
            ].join(' '),
            style: estilo?.copyWith(fontWeight: FontWeight.w600),
          ),
        if (fase != null)
          Text(
            '${ordinalFase(fase)} fase impresión habilitada',
            style: estilo?.copyWith(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Widget _etiquetaEstadoImpresion(String texto, {required bool impreso}) {
    final tema = Theme.of(context);
    final oscuro = tema.brightness == Brightness.dark;
    final tono = impreso ? Colors.green : Colors.orange;
    final color = oscuro ? tono.shade200 : tono.shade900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: oscuro ? tono.shade900.withValues(alpha: 0.34) : tono.shade100,
        border: Border.all(color: oscuro ? tono.shade400 : tono.shade700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: tema.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Menú de acciones de una fila.
  ///
  /// Los carnets solo se imprimen desde el sindicato.
  Widget _menu({
    required VoidCallback alAbrir,
    required VoidCallback alEditar,
    required VoidCallback alEditarTelefono,
    required VoidCallback alEliminar,
    required bool habilitado,
    required VoidCallback alCambiarEstado,
    VoidCallback? alVerDirectorio,
    VoidCallback? alEditarProductores,
    VoidCallback? alEditarFotos,
    VoidCallback? alVerListaFisica,
    VoidCallback? alVerLotes,
    VoidCallback? alVerVetados,
    VoidCallback? alDescargarCredenciales,
  }) {
    final puedeEditar = context.puede('JERARQUIA_EDITAR');
    final puedeEditarFotos = alEditarFotos != null &&
        SesionScope.maybeOf(context)?.sesion?.esAdministrador == true;
    if (context.accesoCentral || context.soloFotosObservaciones) {
      final acciones = <PopupMenuEntry<String>>[
        if (context.mostrarEdicionRapidaProductores &&
            alEditarProductores != null &&
            (context.puedeRegistrarProductores ||
                context.puede('NUMERO_LOTE_EDITAR') ||
                context.puede('PRODUCTORES_OBSERVAR') ||
                context.puede('SIE_REVISAR') ||
                context.puede('LOTES_EDITAR')))
          PopupMenuItem(
            value: 'editarProductores',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.table_view_outlined),
              title: Text('Edición rápida de productores'),
            ),
          ),
        if (alVerLotes != null && context.puede('LOTES_EDITAR'))
          const PopupMenuItem(
            value: 'lotes',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.crop_landscape_outlined),
              title: Text('Parcelas'),
            ),
          ),
        if (alVerListaFisica != null && context.puede('IMAGENES_EDITAR'))
          const PopupMenuItem(
            value: 'listaFisica',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.document_scanner_outlined),
              title: Text('Lista física del sindicato'),
            ),
          ),
      ];
      if (acciones.isEmpty) return const SizedBox.shrink();
      return PopupMenuButton<String>(
        tooltip: 'Acciones',
        onOpened: alAbrir,
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (opcion) => switch (opcion) {
          'editarProductores' => alEditarProductores?.call(),
          'lotes' => alVerLotes?.call(),
          'listaFisica' => alVerListaFisica?.call(),
          _ => null,
        },
        itemBuilder: (_) => acciones,
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      onOpened: alAbrir,
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) => switch (v) {
        'editar' => alEditar(),
        'editarTelefono' => alEditarTelefono(),
        'editarProductores' => alEditarProductores?.call(),
        'editarFotos' => alEditarFotos?.call(),
        'estado' => alCambiarEstado(),
        'directorio' => alVerDirectorio?.call(),
        'listaFisica' => alVerListaFisica?.call(),
        'lotes' => alVerLotes?.call(),
        'vetados' => alVerVetados?.call(),
        'credenciales' => alDescargarCredenciales?.call(),
        _ => alEliminar(),
      },
      itemBuilder: (context) => [
        if (context.mostrarDirectorios && context.puede('DIRECTORIOS_EDITAR'))
          const PopupMenuItem(
            value: 'editarTelefono',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_outlined),
              title: Text('Editar teléfono'),
            ),
          ),
        if (puedeEditarFotos)
          const PopupMenuItem(
            value: 'editarFotos',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Editar fotos de productores'),
            ),
          ),
        if (context.mostrarEdicionRapidaProductores &&
            alEditarProductores != null &&
            (context.puede('PRODUCTORES_EDITAR') ||
                context.puede('NUMERO_LOTE_EDITAR') ||
                context.puede('LOTES_EDITAR') ||
                context.puede('SIE_REVISAR') ||
                context.puede('PRODUCTORES_OBSERVAR')))
          const PopupMenuItem(
            value: 'editarProductores',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.table_view_outlined),
              title: Text('Edición rápida de productores'),
            ),
          ),
        if (puedeEditar)
          const PopupMenuItem(value: 'editar', child: Text('Editar')),
        if (context.mostrarDirectorios && alVerDirectorio != null)
          const PopupMenuItem(
            value: 'directorio',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.groups_2_outlined),
              title: Text('Directorio'),
            ),
          ),
        if (alVerListaFisica != null)
          const PopupMenuItem(
            value: 'listaFisica',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.document_scanner_outlined),
              title: Text('Lista física del sindicato'),
            ),
          ),
        if (puedeEditar) itemCambiarEstado(habilitado),
        if (alVerLotes != null)
          const PopupMenuItem(
            value: 'lotes',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.crop_landscape_outlined),
              title: Text('Parcelas'),
            ),
          ),
        if (alVerVetados != null)
          const PopupMenuItem(
            value: 'vetados',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_off_outlined),
              title: Text('Productores vetados'),
            ),
          ),
        if (alDescargarCredenciales != null)
          const PopupMenuItem(
            value: 'credenciales',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.badge_outlined),
              title: Text('Estado e impresión de Carnets'),
            ),
          ),
        if (puedeEditar)
          const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
      ],
    );
  }

  Future<void> _eliminar({
    required String nombre,
    required String tipo,
    required Future<void> Function() accion,
    required VoidCallback alTerminar,
  }) async {
    if (!await _cerrarFichaActual() || !mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar $tipo?'),
        content: Text(
          'Se va a borrar «$nombre». Si tiene registros dependientes, el '
          'backend va a rechazar la operación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _ejecutar(accion, alTerminar);
  }

  Future<void> _ejecutar(
    Future<void> Function() accion,
    VoidCallback alTerminar,
  ) async {
    try {
      await accion();
      if (!mounted) return;
      alTerminar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.titulo,
    required this.hijo,
    this.detalleTitulo,
    this.acciones = const [],
    this.alAgregar,
  });

  final String titulo;
  final String? detalleTitulo;
  final List<Widget> acciones;
  final Widget hijo;
  final VoidCallback? alAgregar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: tema.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detalleTitulo != null)
                      Text(
                        detalleTitulo!,
                        style: tema.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              ...acciones,
              if (alAgregar != null)
                IconButton(
                  tooltip: 'Agregar',
                  onPressed: alAgregar,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: hijo),
      ],
    );
  }
}

class _DatosSindicatos {
  const _DatosSindicatos({
    required this.sindicatos,
    required this.totalProductores,
  });

  final List<Sindicato> sindicatos;
  final int totalProductores;
}

class _DetalleAvanceTooltip extends StatefulWidget {
  const _DetalleAvanceTooltip({
    super.key,
    required this.revision,
    required this.cargar,
    required this.child,
  });

  final Object revision;
  final Future<String> Function() cargar;
  final Widget child;

  @override
  State<_DetalleAvanceTooltip> createState() => _DetalleAvanceTooltipState();
}

class _DetalleAvanceTooltipState extends State<_DetalleAvanceTooltip> {
  Future<String>? _mensaje;

  @override
  void didUpdateWidget(_DetalleAvanceTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _mensaje = null;
  }

  void _cargar() {
    if (_mensaje != null) return;
    final mensaje = widget.cargar();
    setState(() {
      _mensaje = mensaje;
    });
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _cargar(),
    child: FutureBuilder<String>(
      key: ObjectKey(widget.revision),
      future: _mensaje,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return widget.child;
        return Tooltip(
          waitDuration: const Duration(milliseconds: 700),
          message: snapshot.data!,
          child: widget.child,
        );
      },
    ),
  );
}

/// Nivel seleccionado reducido a una franja vertical en la mesa de trabajo.
/// Al tocarlo vuelve a desplegar la jerarquía para cambiar la selección.
class _ColumnaColapsada extends StatelessWidget {
  const _ColumnaColapsada({
    required this.icono,
    required this.nombre,
    required this.ayuda,
    required this.alTocar,
  });

  final IconData icono;
  final String nombre;
  final String ayuda;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      width: 64,
      child: Material(
        color: tema.colorScheme.surfaceContainerLow,
        child: Tooltip(
          message: '$ayuda: $nombre',
          child: InkWell(
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icono, color: tema.colorScheme.primary),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
