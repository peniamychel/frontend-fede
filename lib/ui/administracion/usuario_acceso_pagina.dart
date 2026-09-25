import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Configuración individual; los permisos personalizados no alteran el rol.
class UsuarioAccesoPagina extends StatefulWidget {
  const UsuarioAccesoPagina({super.key, this.usuarioId});
  final int? usuarioId;
  @override
  State<UsuarioAccesoPagina> createState() => _UsuarioAccesoPaginaState();
}

class _UsuarioAccesoPaginaState extends State<UsuarioAccesoPagina> {
  static const _permisosCentral = {
    'PRODUCTORES_VER',
    'FOTOS_PRODUCTORES_EDITAR',
    'PRODUCTORES_OBSERVAR',
    'NUMERO_LOTE_EDITAR',
  };
  final _nombre = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<Map<String, dynamic>> _roles = [],
      _permisos = [],
      _centrales = [],
      _sindicatos = [];
  final _rolesIds = <int>{}, _sindicatoIds = <int>{};
  final _permisosElegidos = <String>{};
  int? _centralId;
  bool _limitado = false,
      _todos = true,
      _personalizados = false,
      _activo = true;
  bool _cargando = true, _guardando = false, _cargandoSindicatos = false;
  String? _error, _errorSindicatos;
  int _consultaSindicatos = 0;
  bool _administradorGuardado = false;

  bool get _admin =>
      _roles.any((r) => _rolesIds.contains(r['id']) && r['codigo'] == 'ADMIN');
  Set<String> get _heredados => {
    for (final r in _roles)
      if (_rolesIds.contains(r['id']) && r['activo'] != false)
        for (final p in (r['permisos'] as List? ?? []))
          if (!_limitado || _permisosCentral.contains(p)) '$p',
  };
  bool _rolPermitido(Map<String, dynamic> r) => _limitado
      ? r['codigo'] != 'ADMIN' &&
            (r['permisos'] as List? ?? []).every(_permisosCentral.contains)
      : r['codigo'] != 'REGISTRO_CENTRAL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = PadronScope.of(context).accesos;
      final datos = await Future.wait([
        repo.roles(),
        repo.permisos(),
        repo.centrales(),
      ]);
      final u = widget.usuarioId == null
          ? <String, dynamic>{}
          : await repo.usuario(widget.usuarioId!);
      if (!mounted) return;
      setState(() {
        _roles = datos[0];
        _permisos = datos[1];
        _centrales = datos[2];
        _nombre.text = u['nombreCompleto'] as String? ?? '';
        _administradorGuardado = (u['roles'] as List? ?? []).any(
          (r) => '$r'.toUpperCase() == 'ADMIN',
        );
        _activo = u['activo'] != false;
        _centralId = (u['centralId'] as num?)?.toInt();
        _limitado = _centralId != null;
        _todos = u['todosSindicatos'] != false;
        _personalizados = u['permisosPersonalizados'] == true;
        _rolesIds.clear();
        for (final r in _roles) {
          if ((u['roles'] as List? ?? []).contains(r['codigo'])) {
            _rolesIds.add((r['id'] as num).toInt());
          }
        }
        _sindicatoIds
          ..clear()
          ..addAll(
            (u['sindicatoIds'] as List? ?? []).map((e) => (e as num).toInt()),
          );
        _permisosElegidos
          ..clear()
          ..addAll((u['permisos'] as List? ?? []).cast<String>());
      });
      if (_centralId != null) await _cargarSindicatos();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar la configuración. $e');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarSindicatos() async {
    final central = _centralId, consulta = ++_consultaSindicatos;
    if (central == null) return;
    setState(() {
      _cargandoSindicatos = true;
      _errorSindicatos = null;
    });
    try {
      final lista = await PadronScope.of(context).accesos.sindicatos(central);
      if (!mounted ||
          consulta != _consultaSindicatos ||
          central != _centralId) {
        return;
      }
      setState(() => _sindicatos = lista);
    } catch (e) {
      if (mounted && consulta == _consultaSindicatos) {
        setState(
          () => _errorSindicatos = 'No se pudieron cargar los sindicatos. $e',
        );
      }
    } finally {
      if (mounted && consulta == _consultaSindicatos) {
        setState(() => _cargandoSindicatos = false);
      }
    }
  }

  void _cambiarAlcance(bool valor) {
    setState(() {
      _limitado = valor;
      _centralId = null;
      _todos = true;
      _consultaSindicatos++;
      _cargandoSindicatos = false;
      _errorSindicatos = null;
      _sindicatos = [];
      _sindicatoIds.clear();
      _rolesIds.clear();
      _personalizados = false;
      _permisosElegidos.clear();
      if (valor) {
        for (final r in _roles) {
          if (r['codigo'] == 'REGISTRO_CENTRAL' && r['activo'] != false) {
            _rolesIds.add((r['id'] as num).toInt());
          }
        }
      }
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    String? error;
    if (_rolesIds.isEmpty) error = 'Seleccioná al menos un rol.';
    if (_limitado && _centralId == null) error = 'Seleccioná una central.';
    if (_limitado &&
        !_todos &&
        (_sindicatoIds.isEmpty ||
            _errorSindicatos != null ||
            _cargandoSindicatos)) {
      error = 'Seleccioná al menos un sindicato de la central.';
    }
    if (error != null) {
      mostrarError(context, error);
      return;
    }
    setState(() => _guardando = true);
    try {
      final repo = PadronScope.of(context).accesos;
      final ids = _todos ? <int>[] : _sindicatoIds.toList();
      if (widget.usuarioId == null) {
        final creado = await repo.crearUsuario(
          _nombre.text.trim(),
          _rolesIds.toList(),
          centralId: _centralId,
          todosSindicatos: _todos,
          sindicatoIds: ids,
          permisosPersonalizados: _personalizados,
          permisos: _permisosElegidos.toList(),
        );
        if (!mounted) return;
        await _mostrarCodigo('${creado['codigoAcceso']}');
      } else {
        await repo.editarUsuario(
          widget.usuarioId!,
          _nombre.text.trim(),
          _rolesIds.toList(),
          _activo,
          centralId: _centralId,
          todosSindicatos: _todos,
          sindicatoIds: ids,
          permisosPersonalizados: _personalizados,
          permisos: _permisosElegidos.toList(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarCodigo({required bool manual}) async {
    var codigoManual = '';
    final formulario = GlobalKey<FormState>();
    final valor = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          manual ? 'Cambiar código de acceso' : 'Generar código de acceso',
        ),
        content: Form(
          key: formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'El código anterior y las sesiones abiertas dejarán de funcionar.',
              ),
              if (manual)
                TextFormField(
                  onChanged: (v) => codigoManual = v,
                  autofocus: true,
                  maxLength: 5,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Código de 5 letras',
                    helperText: 'Distingue mayúsculas y minúsculas.',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                  ],
                  validator: (v) => RegExp(r'^[A-Za-z]{5}$').hasMatch(v ?? '')
                      ? null
                      : 'Ingresá exactamente 5 letras.',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formulario.currentState!.validate()) {
                Navigator.pop(c, manual ? codigoManual : '');
              }
            },
            child: Text(manual ? 'Guardar código' : 'Generar'),
          ),
        ],
      ),
    );
    if (valor == null || !mounted) return;
    setState(() => _guardando = true);
    try {
      final repo = PadronScope.of(context).accesos;
      final codigo = manual
          ? await repo.establecerCodigo(widget.usuarioId!, valor)
          : await repo.regenerarCodigo(widget.usuarioId!);
      if (mounted) await _mostrarCodigo(codigo);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.usuarioId == null
            ? 'Nuevo usuario'
            : 'Configuración del usuario',
      ),
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _cargar, child: const Text('Reintentar')),
              ],
            ),
          )
        : AbsorbPointer(
            absorbing: _guardando,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextFormField(
                        controller: _nombre,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresá el nombre.'
                            : null,
                      ),
                      if (widget.usuarioId != null)
                        SwitchListTile(
                          title: const Text('Acceso habilitado'),
                          value: _activo,
                          onChanged: (v) => setState(() => _activo = v),
                        ),
                      const Divider(height: 32),
                      Text(
                        'Central y sindicatos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SwitchListTile(
                        title: const Text('Acceso solo a una central'),
                        value: _limitado,
                        onChanged: _cambiarAlcance,
                      ),
                      if (_limitado) ...[
                        DropdownButtonFormField<int>(
                          key: ValueKey(_centralId),
                          initialValue: _centralId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Central asignada',
                          ),
                          items: [
                            for (final c in _centrales)
                              DropdownMenuItem(
                                value: (c['id'] as num).toInt(),
                                child: Text('${c['nombre']}'),
                              ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _centralId = v;
                              _todos = true;
                              _sindicatoIds.clear();
                              _sindicatos = [];
                            });
                            _cargarSindicatos();
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Solo podrá consultar y trabajar en los sindicatos autorizados. No podrá cambiar la clasificación ni usar SIE.',
                        ),
                        if (_centralId != null) ...[
                          SwitchListTile(
                            title: const Text('Todos los sindicatos'),
                            subtitle: const Text(
                              'Incluye los sindicatos que se creen después en esta central.',
                            ),
                            value: _todos,
                            onChanged: (v) => setState(() => _todos = v),
                          ),
                          if (!_todos) ...[
                            Text('Seleccionados: ${_sindicatoIds.length}'),
                            if (_cargandoSindicatos)
                              const LinearProgressIndicator(),
                            if (_errorSindicatos != null) ...[
                              Text(_errorSindicatos!),
                              TextButton(
                                onPressed: _cargarSindicatos,
                                child: const Text('Reintentar sindicatos'),
                              ),
                            ] else if (!_cargandoSindicatos &&
                                _sindicatos.isEmpty)
                              const Text(
                                'Esta central todavía no tiene sindicatos.',
                              ),
                            for (final s in _sindicatos)
                              CheckboxListTile(
                                title: Text('${s['nombre']}'),
                                value: _sindicatoIds.contains(s['id']),
                                onChanged: (v) => setState(() {
                                  final id = (s['id'] as num).toInt();
                                  v == true
                                      ? _sindicatoIds.add(id)
                                      : _sindicatoIds.remove(id);
                                }),
                              ),
                          ],
                        ],
                      ],
                      const Divider(height: 32),
                      Text(
                        'Roles y permisos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final r in _roles.where(_rolPermitido))
                        CheckboxListTile(
                          title: Text('${r['nombre']}'),
                          subtitle: r['activo'] == false
                              ? const Text('Rol deshabilitado')
                              : null,
                          value: _rolesIds.contains(r['id']),
                          onChanged:
                              r['activo'] == false &&
                                  !_rolesIds.contains(r['id'])
                              ? null
                              : (v) => setState(() {
                                  final id = (r['id'] as num).toInt();
                                  v == true
                                      ? _rolesIds.add(id)
                                      : _rolesIds.remove(id);
                                  if (_admin) {
                                    _personalizados = false;
                                    _permisosElegidos.clear();
                                  }
                                }),
                        ),
                      SwitchListTile(
                        title: const Text(
                          'Personalizar permisos de este usuario',
                        ),
                        subtitle: Text(
                          _admin
                              ? 'El administrador conserva todos sus permisos.'
                              : 'Reemplaza los permisos del rol solo para este usuario.',
                        ),
                        value: _personalizados,
                        onChanged: _admin
                            ? null
                            : (v) => setState(() {
                                _personalizados = v;
                                if (v) {
                                  _permisosElegidos
                                    ..clear()
                                    ..addAll(_heredados);
                                }
                              }),
                      ),
                      for (final p in _permisos)
                        if (!_limitado ||
                            _permisosCentral.contains(p['codigo']))
                          CheckboxListTile(
                            dense: true,
                            title: Text('${p['nombre']}'),
                            subtitle: Text('${p['grupo']}'),
                            value:
                                (_personalizados
                                        ? _permisosElegidos
                                        : _heredados)
                                    .contains(p['codigo']),
                            onChanged: !_personalizados
                                ? null
                                : (v) => setState(() {
                                    v == true
                                        ? _permisosElegidos.add(
                                            '${p['codigo']}',
                                          )
                                        : _permisosElegidos.remove(p['codigo']);
                                  }),
                          ),
                      if (_personalizados && _permisosElegidos.isEmpty)
                        const Text(
                          'Sin permisos seleccionados, este usuario no podrá trabajar en el sistema.',
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Al guardar los cambios se cerrarán las sesiones de este usuario; deberá ingresar nuevamente.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _guardando ? 'Guardando…' : 'Guardar configuración',
                        ),
                      ),
                      if (widget.usuarioId != null) ...[
                        const Divider(height: 32),
                        OutlinedButton.icon(
                          onPressed: _administradorGuardado || _guardando
                              ? null
                              : _eliminar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar usuario'),
                        ),
                        if (_administradorGuardado)
                          const Text(
                            'No se puede eliminar a un administrador.',
                          ),
                        const Divider(height: 32),
                        Text(
                          'Código de acceso',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Por seguridad, el código actual no se muestra. Podés reemplazarlo aquí.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _cambiarCodigo(manual: true),
                              icon: const Icon(Icons.key),
                              label: const Text('Ingresar código manualmente'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _cambiarCodigo(manual: false),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Generar código de 5 letras'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
  );

  Future<void> _eliminar() async {
    if (_guardando || _administradorGuardado || widget.usuarioId == null) {
      return;
    }
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Eliminar a "${_nombre.text}"? Su código y sus sesiones dejarán de funcionar. '
          'Esta acción no se puede deshacer. No se eliminarán productores, fotos ni sindicatos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _guardando = true);
    try {
      await PadronScope.of(context).accesos.eliminarUsuario(widget.usuarioId!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _mostrarCodigo(String codigo) => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Código de acceso guardado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Copialo ahora. Por seguridad no volverá a mostrarse.'),
          const SizedBox(height: 12),
          SelectableText(
            codigo,
            style: Theme.of(
              c,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: codigo));
          },
          child: const Text('Copiar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Listo'),
        ),
      ],
    ),
  );
}
