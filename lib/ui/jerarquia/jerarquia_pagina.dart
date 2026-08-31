import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/boton_tema.dart';
import '../credenciales/pliego_previa_pagina.dart';
import '../credenciales/informe_impresion_central_pagina.dart';
import '../credenciales/informe_impresion_federacion_pagina.dart';
import '../lotes/lotes_sindicato_pagina.dart';
import '../widgets/descargas.dart';
import '../widgets/dialogo_nombre_numero.dart';
import '../widgets/estados.dart';
import '../widgets/marca_estado.dart';
import 'directorio_pagina.dart';
import 'lista_fisica_sindicato_pagina.dart';
import 'sindicato_productores_pagina.dart';

/// Navegación por la jerarquía de CARRASCO TROPICAL: Central › Sindicato.
///
/// La federación se resuelve internamente para conservar sus relaciones, pero
/// no se ofrece como nivel editable porque la aplicación trabaja únicamente
/// con CARRASCO TROPICAL.
class JerarquiaControlador {
  _JerarquiaPaginaState? _estado;

  /// Intenta volver un nivel dentro de Central › Sindicato.
  /// Devuelve false cuando la jerarquía ya está en la lista de centrales.
  bool retroceder() => _estado?._retroceder() ?? false;

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

  Federacion? _federacion;
  Central? _central;
  Sindicato? _sindicato;
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
    final federaciones = await padron.federaciones.listar();
    final candidatas = federaciones.where(
      (federacion) =>
          federacion.nombre.trim().toUpperCase() == 'CARRASCO TROPICAL',
    );
    if (candidatas.length != 1) {
      throw StateError(
        'No se encontró una única federación llamada CARRASCO TROPICAL.',
      );
    }
    final federacion = candidatas.single;
    _federacion = federacion;
    _centrales = padron.federaciones.centrales(federacion.id);
    return federacion;
  }

  void _recargarTodo() {
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
      if (mounted) setState(() => _centralesFijadasIds = ids);
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
    if (_centralesFijadasIds.isEmpty) return;
    setState(() => _centralesFijadasIds = const []);
    await _guardarCentralesFijadas();
  }

  Future<void> _guardarCentralesFijadas() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
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
          ),
      ],
      totalProductores: avance.total,
    );
  }

  void _elegirCentral(Central c) {
    setState(() {
      _central = c;
      _sindicato = null;
    });
    _recargarSindicatos();
  }

  bool _retroceder() {
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
            if (restricciones.maxWidth >= 900) {
              return _columnasAnchas(restricciones.maxWidth);
            }
            return _unaColumna();
          },
        ),
      ),
    );
  }

  bool _permiteMesaDeTrabajo(double ancho) {
    if (ancho < 900) return false;
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Widget _columnasAnchas(double ancho) {
    final sindicato = _sindicato;
    if (sindicato != null && _permiteMesaDeTrabajo(ancho)) {
      final anchoSindicatos = (ancho * 0.30).clamp(300.0, 440.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnaColapsada(
            icono: Icons.hub_outlined,
            nombre: _central!.nombre,
            ayuda: 'Cambiar central',
            alTocar: () => setState(() => _sindicato = null),
          ),
          const VerticalDivider(width: 1),
          SizedBox(width: anchoSindicatos, child: _panelSindicatos()),
          const VerticalDivider(width: 1),
          Expanded(
            child: SindicatoProductoresPagina(
              key: ValueKey('productores-sindicato-${sindicato.id}'),
              sindicato: sindicato,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _panelCentrales()),
        const VerticalDivider(width: 1),
        Expanded(child: _panelSindicatos()),
      ],
    );
  }

  Widget _unaColumna() {
    final Widget panel;
    if (_central != null) {
      panel = _panelSindicatos();
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
          ? 'Orden alfabético'
          : '${_centralesFijadasIds.length} '
                '${_centralesFijadasIds.length == 1 ? 'central fijada' : 'centrales fijadas'} arriba',
      acciones: [
        IconButton(
          tooltip: 'Restablecer orden alfabético',
          onPressed: _centralesFijadasIds.isEmpty
              ? null
              : _ordenarCentralesAlfabeticamente,
          icon: const Icon(Icons.sort_by_alpha),
        ),
      ],
      alAgregar: () => _crearCentral(f),
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
            children: [
              for (final c in ordenadas)
                ListTile(
                  key: ValueKey('central-${c.id}'),
                  selected: _central?.id == c.id,
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
                  ),
                  subtitle: _abreviatura(c.abreviatura),
                  onTap: () => _elegirCentral(c),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Informe de impresión de la central',
                        onPressed: () => _verInformeImpresionCentral(c),
                        icon: const Icon(Icons.analytics_outlined, size: 20),
                      ),
                      _menu(
                        alEditar: () => _editarCentral(c),
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
                          accion: () =>
                              PadronScope.of(context).centrales.eliminar(c.id),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InformeImpresionCentralPagina(central: central),
      ),
    );
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

  Widget _panelSindicatos() {
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
        alAgregar: () => _crearSindicato(c),
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
              children: [
                for (final s in lista)
                  ListTile(
                    selected: _sindicato?.id == s.id,
                    leading: const Icon(Icons.groups_outlined),
                    title: TituloConEstado(
                      nombre: s.nombre,
                      habilitado: s.habilitado,
                    ),
                    subtitle: Row(
                      children: [
                        if (s.numero != null) ...[
                          Text(
                            'N° ${s.numero}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Text(' · '),
                        ],
                        Expanded(
                          child: Text(
                            'Total: ${s.totalProductores ?? 0} · '
                            '${(s.porcentajeImpresion ?? 0).round()}% Impresión',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _verProductores(s),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Directorio del sindicato',
                          onPressed: () =>
                              _verDirectorio(DirectorioPagina.deSindicato(s)),
                          icon: const Icon(Icons.groups_2_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Lista física del sindicato',
                          onPressed: () => _verListaFisica(s),
                          icon: const Icon(
                            Icons.document_scanner_outlined,
                            size: 20,
                          ),
                        ),
                        _menu(
                          alEditar: () => _editarSindicato(s),
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
                          alDescargarInforme: () =>
                              descargarInformeSindicato(context, s),
                          alVerLotes: () => _verLotes(s),
                          alDescargarCredenciales: () =>
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PliegoPreviaPagina(sindicato: s),
                                ),
                              ),
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
              ],
            );
          },
        ),
      ),
    );
  }

  void _verProductores(Sindicato s) {
    final ancho = MediaQuery.sizeOf(context).width;
    if (_permiteMesaDeTrabajo(ancho)) {
      setState(() => _sindicato = s);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SindicatoProductoresPagina(sindicato: s),
      ),
    );
  }

  /// Abre el directorio de cualquiera de los tres niveles.
  Future<void> _verDirectorio(DirectorioPagina pagina) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
    if (mounted) _recargarSindicatos();
  }

  Future<void> _verLotes(Sindicato s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LotesSindicatoPagina(sindicato: s)),
    );
    if (mounted) _recargarSindicatos();
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
  Widget? _abreviatura(String? abreviatura) {
    if (abreviatura == null) return null;
    return Text(
      abreviatura,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  /// Menú de acciones de una fila.
  ///
  /// Las dos descargas solo las pasan los sindicatos: son los únicos que tienen
  /// nómina que imprimir y productores a los que emitir credencial.
  Widget _menu({
    required VoidCallback alEditar,
    required VoidCallback alEliminar,
    required bool habilitado,
    required VoidCallback alCambiarEstado,
    VoidCallback? alVerDirectorio,
    VoidCallback? alVerLotes,
    VoidCallback? alDescargarInforme,
    VoidCallback? alDescargarCredenciales,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) => switch (v) {
        'editar' => alEditar(),
        'estado' => alCambiarEstado(),
        'directorio' => alVerDirectorio?.call(),
        'lotes' => alVerLotes?.call(),
        'informe' => alDescargarInforme?.call(),
        'credenciales' => alDescargarCredenciales?.call(),
        _ => alEliminar(),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'editar', child: Text('Editar')),
        // El sindicato no lo lleva en el menú: tiene su propio botón en la
        // fila, porque es el directorio que más se toca.
        if (alVerDirectorio != null)
          const PopupMenuItem(
            value: 'directorio',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.groups_2_outlined),
              title: Text('Directorio'),
            ),
          ),
        itemCambiarEstado(habilitado),
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
        if (alDescargarInforme != null)
          const PopupMenuItem(
            value: 'informe',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('Descargar nómina en PDF'),
            ),
          ),
        if (alDescargarCredenciales != null)
          const PopupMenuItem(
            value: 'credenciales',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.badge_outlined),
              title: Text('Estado e impresión de credenciales'),
            ),
          ),
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
