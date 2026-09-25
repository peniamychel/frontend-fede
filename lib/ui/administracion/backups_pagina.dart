import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../sesion_scope.dart';
import '../widgets/boton_tema.dart';
import '../widgets/estados.dart';

class BackupsPagina extends StatefulWidget {
  const BackupsPagina({super.key});

  @override
  State<BackupsPagina> createState() => _BackupsPaginaState();
}

class _BackupsPaginaState extends State<BackupsPagina> {
  List<Backup> _respaldos = const [];
  bool _iniciada = false;
  bool _cargando = false;
  bool _creando = false;
  Timer? _consulta;

  Padron get _padron => PadronScope.of(context);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    if (SesionScope.of(context).puede('RESPALDOS_ADMINISTRAR')) {
      _recargar();
    }
  }

  @override
  void dispose() {
    _consulta?.cancel();
    super.dispose();
  }

  Future<void> _recargar({bool silencioso = false}) async {
    _consulta?.cancel();
    if (!silencioso) setState(() => _cargando = true);
    try {
      final respaldos = await _padron.backups.listar();
      if (!mounted) return;
      setState(() {
        _respaldos = respaldos;
      });
      if (respaldos.any((b) => b.enProceso)) {
        _consulta = Timer(
          const Duration(seconds: 2),
          () => _recargar(silencioso: true),
        );
      }
    } catch (e) {
      if (!mounted) return;
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
    final permitido = SesionScope.of(context).puede('RESPALDOS_ADMINISTRAR');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Copias de seguridad'),
        actions: const [BotonTema()],
      ),
      body: permitido ? _contenido() : _sinPermiso(),
    );
  }

  Widget _sinPermiso() {
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
            const Text(
              'Tu cuenta no tiene permiso para administrar respaldos.',
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
