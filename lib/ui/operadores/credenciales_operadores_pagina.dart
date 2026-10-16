import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../credenciales/editor_credencial_pagina.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../widgets/estados.dart';
import 'operador_credencial_previa_pagina.dart';
import 'operador_formulario_pagina.dart';
import 'operadores_resena_pagina.dart';

class CredencialesOperadoresPagina extends StatefulWidget {
  const CredencialesOperadoresPagina({super.key});

  @override
  State<CredencialesOperadoresPagina> createState() =>
      _CredencialesOperadoresPaginaState();
}

class _CredencialesOperadoresPaginaState
    extends State<CredencialesOperadoresPagina> {
  final _busqueda = TextEditingController();
  Timer? _espera;
  List<OperadorCredencial> _operadores = const [];
  bool _cargando = true;
  Object? _error;
  int _consulta = 0;

  bool get _permitido =>
      context.puede('CREDENCIALES_OPERADORES_GESTIONAR') &&
      !context.accesoCentral;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted || !_permitido) return;
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final operadores = await PadronScope.of(
        context,
      ).credencialesOperadores.listar(buscar: _busqueda.text);
      if (mounted && consulta == _consulta) {
        setState(() => _operadores = operadores);
      }
    } catch (error) {
      if (mounted && consulta == _consulta) setState(() => _error = error);
    } finally {
      if (mounted && consulta == _consulta) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_permitido) {
      return const Scaffold(
        body: SinResultados(
          mensaje: 'Sin acceso a las credenciales del personal operador',
          icono: Icons.lock_outline,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credenciales del personal operador'),
        actions: [
          IconButton(
            tooltip: 'Reseña común del reverso',
            onPressed: () => _abrir(const OperadoresResenaPagina()),
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            tooltip: 'Diseño de las credenciales de operadores',
            onPressed: () =>
                _abrir(const EditorCredencialPagina(operadores: true)),
            icon: const Icon(Icons.design_services_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo operador'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _busqueda,
              decoration: InputDecoration(
                labelText: 'Buscar por nombres, apellidos, CI o cargo',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busqueda.clear();
                          _espera?.cancel();
                          _cargar();
                        },
                      ),
              ),
              onChanged: (_) {
                _espera?.cancel();
                setState(() {});
                _espera = Timer(const Duration(milliseconds: 300), _cargar);
              },
              onSubmitted: (_) {
                _espera?.cancel();
                _cargar();
              },
            ),
          ),
          Expanded(
            child: _cargando
                ? const Cargando()
                : _error != null
                ? FalloCarga(error: _error!, alReintentar: _cargar)
                : _operadores.isEmpty
                ? SinResultados(
                    mensaje: _busqueda.text.trim().isEmpty
                        ? 'Todavía no hay operadores registrados'
                        : 'No se encontraron operadores',
                    detalle:
                        'Los registros de este módulo son independientes '
                        'del padrón y de las cuentas de acceso.',
                    icono: Icons.badge_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: _operadores.length,
                    itemBuilder: (context, indice) {
                      final operador = _operadores[indice];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: operador.fotoUrl == null
                                ? const Icon(Icons.badge_outlined)
                                : ClipOval(
                                    child: Image.network(
                                      ApiConfig.urlAbsoluta(operador.fotoUrl!),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.badge_outlined),
                                    ),
                                  ),
                          ),
                          title: Text(operador.nombreCompleto),
                          subtitle: Text(
                            'CI: ${operador.ci} · ${operador.cargo}\n'
                            'Teléfono: ${operador.telefono}',
                          ),
                          isThreeLine: true,
                          onTap: () => _editar(operador),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Acciones del operador',
                            onSelected: (accion) => switch (accion) {
                              'editar' => _editar(operador),
                              'previa' => _abrir(
                                OperadorCredencialPreviaPagina(
                                  operadorId: operador.id,
                                ),
                              ),
                              'eliminar' => _eliminar(operador),
                              _ => null,
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'editar',
                                child: Text('Editar datos'),
                              ),
                              PopupMenuItem(
                                value: 'previa',
                                child: Text('Vista previa y PDF'),
                              ),
                              PopupMenuItem(
                                value: 'eliminar',
                                child: Text('Eliminar operador'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrir(Widget pagina) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => pagina));

  Future<void> _editar([OperadorCredencial? operador]) async {
    final guardado = await Navigator.of(context).push<OperadorCredencial>(
      MaterialPageRoute(
        builder: (_) => OperadorFormularioPagina(operador: operador),
      ),
    );
    if (guardado != null && mounted) {
      mostrarExito(context, 'Datos del operador guardados');
      await _cargar();
    }
  }

  Future<void> _eliminar(OperadorCredencial operador) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar operador?'),
        content: Text(
          'Se eliminará el registro para la credencial de '
          '${operador.nombreCompleto}. Esta acción no se puede deshacer. '
          'No afecta cuentas de acceso ni productores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await PadronScope.of(
        context,
      ).credencialesOperadores.eliminar(operador.id);
      if (mounted) {
        mostrarExito(context, 'Operador eliminado');
        await _cargar();
      }
    } catch (error) {
      if (mounted) mostrarError(context, error);
    }
  }
}
