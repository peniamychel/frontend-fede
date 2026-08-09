import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/boton_tema.dart';
import '../widgets/descargas.dart';
import '../widgets/dialogo_nombre_numero.dart';
import '../widgets/dialogo_texto.dart';
import '../widgets/estados.dart';
import '../widgets/marca_estado.dart';
import 'directorio_pagina.dart';
import 'sindicato_productores_pagina.dart';
import 'ubicacion_sindicato_pagina.dart';

/// Navegación por la jerarquía: Federación › Central › Sindicato.
///
/// En pantallas anchas los tres niveles van en columnas simultáneas; en móvil
/// se colapsa a un solo panel con miga de pan, porque tres columnas de 120 px
/// no las lee nadie.
class JerarquiaPagina extends StatefulWidget {
  const JerarquiaPagina({super.key});

  @override
  State<JerarquiaPagina> createState() => _JerarquiaPaginaState();
}

class _JerarquiaPaginaState extends State<JerarquiaPagina> {
  Federacion? _federacion;
  Central? _central;

  late Future<List<Federacion>> _federaciones;
  Future<List<Central>>? _centrales;
  Future<List<Sindicato>>? _sindicatos;

  @override
  void initState() {
    super.initState();
    _recargarFederaciones();
  }

  void _recargarFederaciones() {
    setState(() {
      _federaciones = PadronScope.of(context).federaciones.listar();
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

  void _recargarSindicatos() {
    final c = _central;
    setState(() {
      _sindicatos =
          c == null ? null : PadronScope.of(context).centrales.sindicatos(c.id);
    });
  }

  void _elegirFederacion(Federacion f) {
    setState(() {
      _federacion = f;
      _central = null;
      _sindicatos = null;
    });
    _recargarCentrales();
  }

  void _elegirCentral(Central c) {
    setState(() => _central = c);
    _recargarSindicatos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jerarquía'),
        actions: [
          const BotonTema(),
          IconButton(
            tooltip: 'Recargar',
            onPressed: () {
              _recargarFederaciones();
              _recargarCentrales();
              _recargarSindicatos();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, restricciones) {
          if (restricciones.maxWidth >= 900) return _tresColumnas();
          return _unaColumna();
        },
      ),
    );
  }

  Widget _tresColumnas() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _panelFederaciones()),
        const VerticalDivider(width: 1),
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
    } else if (_federacion != null) {
      panel = _panelCentrales();
    } else {
      panel = _panelFederaciones();
    }

    return Column(
      children: [
        if (_federacion != null) _migaDePan(),
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
              onPressed: () => setState(() {
                if (_central != null) {
                  _central = null;
                  _sindicatos = null;
                } else {
                  _federacion = null;
                  _centrales = null;
                }
              }),
            ),
            Expanded(
              child: Text(
                [
                  _federacion?.nombre,
                  _central?.nombre,
                ].whereType<String>().join('  ›  '),
                style: tema.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Federaciones ----------

  Widget _panelFederaciones() {
    return _Panel(
      titulo: 'Federaciones',
      alAgregar: _crearFederacion,
      hijo: CargaAsync<List<Federacion>>(
        futuro: _federaciones,
        alReintentar: _recargarFederaciones,
        constructor: (context, lista) {
          if (lista.isEmpty) {
            return const SinResultados(
              icono: Icons.account_balance_outlined,
              mensaje: 'No hay federaciones.',
              detalle: 'Creá la primera con el botón de arriba.',
            );
          }
          return ListView(
            children: [
              for (final f in lista)
                ListTile(
                  selected: _federacion?.id == f.id,
                  leading: const Icon(Icons.account_balance_outlined),
                  title: TituloConEstado(
                      nombre: f.nombre, habilitado: f.habilitado),
                  onTap: () => _elegirFederacion(f),
                  trailing: _menu(
                    alEditar: () => _editarFederacion(f),
                    alVerDirectorio: () => _verDirectorio(
                        DirectorioPagina.deFederacion(f)),
                    habilitado: f.habilitado,
                    alCambiarEstado: () => cambiarEstadoConAviso(
                      context,
                      nombre: f.nombre,
                      habilitado: f.habilitado,
                      accion: (estado) => PadronScope.of(context)
                          .federaciones
                          .cambiarEstado(f.id, estado),
                    ).then((cambio) {
                      if (cambio) _recargarFederaciones();
                    }),
                    alEliminar: () => _eliminar(
                      nombre: f.nombre,
                      tipo: 'la federación',
                      accion: () => PadronScope.of(context)
                          .federaciones
                          .eliminar(f.id),
                      alTerminar: () {
                        if (_federacion?.id == f.id) {
                          setState(() {
                            _federacion = null;
                            _central = null;
                            _centrales = null;
                            _sindicatos = null;
                          });
                        }
                        _recargarFederaciones();
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _crearFederacion() async {
    final nombre = await _pedirNombre(titulo: 'Nueva federación');
    if (nombre == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context)
          .federaciones
          .crear(FederacionRequest(nombre: nombre)),
      _recargarFederaciones,
    );
  }

  Future<void> _editarFederacion(Federacion f) async {
    final nombre =
        await _pedirNombre(titulo: 'Editar federación', inicial: f.nombre);
    if (nombre == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context)
          .federaciones
          .actualizar(f.id, FederacionRequest(nombre: nombre)),
      _recargarFederaciones,
    );
  }

  // ---------- Centrales ----------

  Widget _panelCentrales() {
    final f = _federacion;
    if (f == null) {
      return const _Panel(
        titulo: 'Centrales',
        hijo: SinResultados(
          icono: Icons.arrow_back,
          mensaje: 'Elegí una federación',
          detalle: 'Sus centrales aparecen acá.',
        ),
      );
    }

    return _Panel(
      titulo: 'Centrales de ${f.nombre}',
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
          return ListView(
            children: [
              for (final c in lista)
                ListTile(
                  selected: _central?.id == c.id,
                  leading: const Icon(Icons.hub_outlined),
                  title: TituloConEstado(
                      nombre: c.nombre, habilitado: c.habilitado),
                  subtitle: _numero(c.numero),
                  onTap: () => _elegirCentral(c),
                  trailing: _menu(
                    alEditar: () => _editarCentral(c),
                    alVerDirectorio: () =>
                        _verDirectorio(DirectorioPagina.deCentral(c)),
                    habilitado: c.habilitado,
                    alCambiarEstado: () => cambiarEstadoConAviso(
                      context,
                      nombre: c.nombre,
                      habilitado: c.habilitado,
                      accion: (estado) => PadronScope.of(context)
                          .centrales
                          .cambiarEstado(c.id, estado),
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
                            _sindicatos = null;
                          });
                        }
                        _recargarCentrales();
                      },
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
    );
    if (datos == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context).centrales.crear(CentralRequest(
            nombre: datos.nombre,
            numero: datos.numero,
            federacionId: f.id,
          )),
      _recargarCentrales,
    );
  }

  Future<void> _editarCentral(Central c) async {
    final datos = await DialogoNombreNumero.mostrar(
      context,
      titulo: 'Editar central',
      etiquetaNombre: 'Nombre de la central',
      nombreInicial: c.nombre,
      numeroInicial: c.numero,
    );
    if (datos == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context).centrales.actualizar(
            c.id,
            CentralRequest(
              nombre: datos.nombre,
              numero: datos.numero,
              federacionId: c.federacionId,
            ),
          ),
      _recargarCentrales,
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

    return _Panel(
      titulo: 'Sindicatos de ${c.nombre}',
      alAgregar: () => _crearSindicato(c),
      hijo: CargaAsync<List<Sindicato>>(
        futuro: _sindicatos!,
        alReintentar: _recargarSindicatos,
        constructor: (context, lista) {
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
                  leading: const Icon(Icons.groups_outlined),
                  title: TituloConEstado(
                      nombre: s.nombre, habilitado: s.habilitado),
                  subtitle: Row(
                    children: [
                      if (s.numero != null) ...[
                        Text(
                          'N° ${s.numero}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Text(' · '),
                      ],
                      Icon(
                        s.tieneUbicacion
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        size: 14,
                        color: s.tieneUbicacion
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s.tieneUbicacion
                              ? s.coordenadas
                              : 'Ver sus productores · sin ubicación',
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
                        tooltip: 'Directorio: presidente y secretario',
                        onPressed: () =>
                            _verDirectorio(DirectorioPagina.deSindicato(s)),
                        icon: const Icon(Icons.groups_2_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: s.tieneUbicacion
                            ? 'Ver o mover la ubicación'
                            : 'Marcar la ubicación en el mapa',
                        onPressed: () => _ubicar(s),
                        icon: Icon(
                          s.tieneUbicacion
                              ? Icons.edit_location_alt_outlined
                              : Icons.add_location_alt_outlined,
                          size: 20,
                        ),
                      ),
                      _menu(
                        alEditar: () => _editarSindicato(s),
                        habilitado: s.habilitado,
                        alCambiarEstado: () => cambiarEstadoConAviso(
                          context,
                          nombre: s.nombre,
                          habilitado: s.habilitado,
                          accion: (estado) => PadronScope.of(context)
                              .sindicatos
                              .cambiarEstado(s.id, estado),
                        ).then((cambio) {
                          if (cambio) _recargarSindicatos();
                        }),
                        alDescargarInforme: () =>
                            descargarInformeSindicato(context, s),
                        alDescargarCredenciales: () =>
                            descargarCredencialesSindicato(context, s),
                        alEliminar: () => _eliminar(
                          nombre: s.nombre,
                          tipo: 'el sindicato',
                          accion: () =>
                              PadronScope.of(context).sindicatos.eliminar(s.id),
                          alTerminar: _recargarSindicatos,
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

  void _verProductores(Sindicato s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SindicatoProductoresPagina(sindicato: s),
      ),
    );
  }

  /// Abre el directorio de cualquiera de los tres niveles.
  Future<void> _verDirectorio(DirectorioPagina pagina) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => pagina),
    );
    if (mounted) _recargarSindicatos();
  }

  Future<void> _ubicar(Sindicato s) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UbicacionSindicatoPagina(sindicato: s),
      ),
    );
    if (cambio == true) _recargarSindicatos();
  }

  Future<void> _crearSindicato(Central c) async {
    final datos = await DialogoNombreNumero.mostrar(
      context,
      titulo: 'Nuevo sindicato',
      etiquetaNombre: 'Nombre del sindicato',
    );
    if (datos == null || !mounted) return;
    await _ejecutar(
      () => PadronScope.of(context).sindicatos.crear(SindicatoRequest(
            nombre: datos.nombre,
            numero: datos.numero,
            centralId: c.id,
          )),
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

  /// Subtítulo con el número, o nada si todavía no se lo asignaron. Se devuelve
  /// null y no un texto tipo «sin número» para no llenar la lista de ruido:
  /// hoy casi ninguna central lo tiene.
  Widget? _numero(String? numero) {
    if (numero == null) return null;
    return Text(
      'N° $numero',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(fontWeight: FontWeight.w600),
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
              title: Text('Imprimir credenciales'),
            ),
          ),
        const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
      ],
    );
  }

  /// Pide un nombre con [DialogoTexto].
  ///
  /// El diálogo administra su propio controlador. Crearlo acá y desecharlo tras
  /// `await showDialog` es lo que rompía la pantalla al editar: cuando
  /// showDialog devuelve, la ruta sigue animando su salida y el campo todavía
  /// usa el controlador.
  Future<String?> _pedirNombre({
    required String titulo,
    String inicial = '',
  }) {
    return DialogoTexto.mostrar(context, titulo: titulo, inicial: inicial);
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
  const _Panel({required this.titulo, required this.hijo, this.alAgregar});

  final String titulo;
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
                child: Text(
                  titulo,
                  style: tema.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
