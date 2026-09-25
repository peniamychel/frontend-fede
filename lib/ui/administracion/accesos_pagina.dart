import 'package:flutter/material.dart';
import 'usuario_acceso_pagina.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

class AccesosPagina extends StatefulWidget {
  const AccesosPagina({super.key});
  @override
  State<AccesosPagina> createState() => _AccesosPaginaState();
}

class _AccesosPaginaState extends State<AccesosPagina>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> _usuarios = const [],
      _roles = const [],
      _permisos = const [];
  bool _cargando = true;
  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final repo = PadronScope.of(context).accesos;
      final datos = await Future.wait([
        repo.usuarios(),
        repo.roles(),
        repo.permisos(),
      ]);
      if (mounted) {
        setState(() {
          _usuarios = datos[0];
          _roles = datos[1];
          _permisos = datos[2];
        });
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Usuarios, roles y permisos'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Usuarios'),
          Tab(text: 'Roles y permisos'),
        ],
      ),
      actions: [
        IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _tabs.index == 0 ? _usuario() : _rol(),
      icon: const Icon(Icons.add),
      label: Text(_tabs.index == 0 ? 'Nuevo usuario' : 'Nuevo rol'),
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabs,
            children: [
              ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _usuarios.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final u = _usuarios[i];
                  final activo = u['activo'] == true;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(activo ? Icons.person : Icons.person_off),
                      ),
                      title: Text('${u['nombreCompleto']}'),
                      subtitle: Text(
                        '${u['centralNombre'] ?? 'Acceso general'} · ${(u['roles'] as List? ?? []).join(', ')}\n'
                        '${u['codigoConfigurado'] == true ? 'Código de acceso configurado' : 'Sin código de acceso'}',
                      ),
                      isThreeLine: true,
                      onTap: () => _usuario(usuario: u),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
              ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _roles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = _roles[i];
                  final activo = r['activo'] != false;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        activo
                            ? Icons.admin_panel_settings_outlined
                            : Icons.disabled_by_default_outlined,
                      ),
                      title: Text('${r['nombre']}'),
                      subtitle: Text(
                        '${(r['permisos'] as List? ?? []).length} permisos${activo ? '' : ' · Deshabilitado'}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _rol(rol: r),
                    ),
                  );
                },
              ),
            ],
          ),
  );

  Future<void> _usuario({Map<String, dynamic>? usuario}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            UsuarioAccesoPagina(usuarioId: (usuario?['id'] as num?)?.toInt()),
      ),
    );
    if (mounted) await _cargar();
  }

  Future<void> _rol({Map<String, dynamic>? rol}) async {
    final repo = PadronScope.of(context).accesos;
    final nombre = TextEditingController(text: rol?['nombre'] as String? ?? '');
    final descripcion = TextEditingController(
      text: rol?['descripcion'] as String? ?? '',
    );
    final elegidos = (rol?['permisos'] as List? ?? const [])
        .map((e) => '$e')
        .toSet();
    bool activo = rol?['activo'] != false;
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(rol == null ? 'Nuevo rol' : 'Editar rol'),
          content: SizedBox(
            width: 560,
            height: 520,
            child: Column(
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del rol',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descripcion,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                if (rol != null)
                  SwitchListTile(
                    value: activo,
                    title: const Text('Rol habilitado'),
                    onChanged: rol['codigo'] == 'ADMIN'
                        ? null
                        : (v) => setLocal(() => activo = v),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final p in _permisos)
                        CheckboxListTile(
                          dense: true,
                          value: elegidos.contains(p['codigo']),
                          title: Text('${p['nombre']}'),
                          subtitle: Text('${p['grupo']}'),
                          onChanged: (v) => setLocal(
                            () => v == true
                                ? elegidos.add('${p['codigo']}')
                                : elegidos.remove('${p['codigo']}'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (guardar != true || nombre.text.trim().isEmpty || elegidos.isEmpty) {
      return;
    }
    try {
      if (rol == null) {
        await repo.crearRol(
          nombre.text.trim(),
          descripcion.text.trim().isEmpty ? null : descripcion.text.trim(),
          elegidos.toList(),
        );
      } else {
        await repo.editarRol(
          (rol['id'] as num).toInt(),
          nombre.text.trim(),
          descripcion.text.trim().isEmpty ? null : descripcion.text.trim(),
          elegidos.toList(),
          activo,
        );
      }
      await _cargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }
}
