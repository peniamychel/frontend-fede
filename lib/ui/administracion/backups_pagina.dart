import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/boton_tema.dart';
import '../widgets/estados.dart';

class BackupsPagina extends StatefulWidget {
  const BackupsPagina({super.key});

  @override
  State<BackupsPagina> createState() => _BackupsPaginaState();
}

class _BackupsPaginaState extends State<BackupsPagina> {
  final _usuario = TextEditingController(text: 'admin');
  final _contrasena = TextEditingController();
  Sesion? _sesion;
  List<Backup> _respaldos = const [];
  bool _iniciando = true;
  bool _autenticando = false;
  bool _cargando = false;
  bool _creando = false;
  Object? _error;
  Timer? _consulta;

  Padron get _padron => PadronScope.of(context);

  @override
  void initState() {
    super.initState();
    _restaurarSesion();
  }

  @override
  void dispose() {
    _consulta?.cancel();
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _restaurarSesion() async {
    try {
      final sesion = await _padron.autenticacion.restaurar();
      if (!mounted) return;
      setState(() {
        _sesion = sesion;
        _iniciando = false;
      });
      if (sesion?.esAdministrador == true) await _recargar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _iniciando = false;
        _error = e;
      });
    }
  }

  Future<void> _iniciarSesion() async {
    if (_usuario.text.trim().isEmpty || _contrasena.text.isEmpty) {
      mostrarAviso(context, 'Ingresá el usuario y la contraseña.');
      return;
    }
    setState(() => _autenticando = true);
    try {
      final sesion = await _padron.autenticacion.iniciarSesion(
        _usuario.text,
        _contrasena.text,
      );
      if (!mounted) return;
      _contrasena.clear();
      setState(() => _sesion = sesion);
      if (sesion.esAdministrador) await _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _autenticando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    _consulta?.cancel();
    await _padron.autenticacion.cerrarSesion();
    if (!mounted) return;
    setState(() {
      _sesion = null;
      _respaldos = const [];
      _error = null;
    });
  }

  Future<void> _recargar({bool silencioso = false}) async {
    _consulta?.cancel();
    if (!silencioso) setState(() => _cargando = true);
    try {
      final respaldos = await _padron.backups.listar();
      if (!mounted) return;
      setState(() {
        _respaldos = respaldos;
        _error = null;
      });
      if (respaldos.any((b) => b.enProceso)) {
        _consulta = Timer(
          const Duration(seconds: 2),
          () => _recargar(silencioso: true),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      if (!silencioso) mostrarError(context, e);
    } finally {
      if (mounted && !silencioso) setState(() => _cargando = false);
    }
  }

  Future<void> _crear() async {
    setState(() => _creando = true);
    try {
      await _padron.backups.crear();
      if (!mounted) return;
      mostrarExito(context, 'El respaldo comenzó en segundo plano.');
      await _recargar(silencioso: true);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  Future<void> _descargar(Backup backup) async {
    try {
      final descarga = await _padron.backups.descargar(backup.id);
      await guardarArchivo(
        descarga.bytes,
        descarga.nombreArchivo,
        descarga.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Respaldo descargado.');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _eliminar(Backup backup) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar respaldo'),
        content: Text(
          'Se eliminará ${backup.archivo}. Esta acción no se puede deshacer.',
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
    if (confirmar != true) return;

    try {
      await _padron.backups.eliminar(backup.id);
      if (!mounted) return;
      mostrarExito(context, 'Respaldo eliminado.');
      await _recargar(silencioso: true);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Copias de seguridad'),
        actions: [
          if (_sesion != null)
            IconButton(
              tooltip: 'Cerrar sesión administrativa',
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
            ),
          const BotonTema(),
        ],
      ),
      body: switch ((_iniciando, _sesion)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (false, null) => _formularioLogin(),
        (false, final sesion?) when !sesion.esAdministrador => _sinPermiso(
          sesion,
        ),
        _ => _contenido(),
      },
    );
  }

  Widget _formularioLogin() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Acceso administrativo',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Los respaldos contienen todo el padrón. Iniciá sesión con una cuenta administradora.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usuario,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contrasena,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _iniciarSesion(),
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'No se pudo comprobar la sesión: $_error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _autenticando ? null : _iniciarSesion,
                      icon: _autenticando
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Ingresar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sinPermiso(Sesion sesion) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'La cuenta ${sesion.usuario} no tiene permiso de administrador.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _cerrarSesion,
              child: const Text('Cambiar cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    final hayActivo = _respaldos.any((b) => b.enProceso);
    final ultimoCorrecto = _respaldos.where((b) => b.completado).firstOrNull;

    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hayActivo
                            ? 'Respaldo en ejecución'
                            : 'Sistema disponible',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ultimoCorrecto == null
                            ? 'Todavía no existe un respaldo completado.'
                            : 'Último correcto: ${_fecha(ultimoCorrecto.iniciadoEn)}',
                      ),
                      const Text('Automático todos los días a las 02:00.'),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: hayActivo || _creando ? null : _crear,
                    icon: _creando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.backup_outlined),
                    label: const Text('Crear respaldo ahora'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historial',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Recargar',
                onPressed: _cargando ? null : _recargar,
                icon: _cargando
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_respaldos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('No hay respaldos registrados.')),
            )
          else
            for (final backup in _respaldos) _tarjetaBackup(backup),
        ],
      ),
    );
  }

  Widget _tarjetaBackup(Backup backup) {
    final esquema = Theme.of(context).colorScheme;
    final (etiqueta, icono, color) = switch (backup.estado) {
      EstadoBackup.enProceso => ('En proceso', Icons.sync, esquema.primary),
      EstadoBackup.completado => (
        'Completado',
        Icons.check_circle_outline,
        esquema.primary,
      ),
      EstadoBackup.fallido => ('Fallido', Icons.error_outline, esquema.error),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono, color: color),
        title: Text(
          '${backup.tipo == TipoBackup.manual ? 'Manual' : 'Automático'} · $etiqueta',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_fecha(backup.iniciadoEn)} · ${backup.solicitadoPor}'),
            if (backup.tamanoBytes != null)
              Text('${pesoLegible(backup.tamanoBytes!)} · ${backup.archivo}'),
            if (backup.sha256 != null)
              Tooltip(
                message: backup.sha256!,
                child: Text(
                  'SHA-256: ${backup.sha256!.substring(0, 16)}…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (backup.error != null)
              Text(backup.error!, style: TextStyle(color: esquema.error)),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (backup.completado)
              IconButton(
                tooltip: 'Descargar',
                onPressed: () => _descargar(backup),
                icon: const Icon(Icons.download_outlined),
              ),
            if (!backup.enProceso)
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => _eliminar(backup),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }

  String _fecha(DateTime fecha) {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }
}
