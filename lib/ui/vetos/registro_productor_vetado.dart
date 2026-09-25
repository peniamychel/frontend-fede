import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Abre el alta desde la lista de vetados o desde el buscador de productores.
Future<bool> registrarProductorVetado(
  BuildContext context,
  Sindicato sindicato, {
  String? ciInicial,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RegistroProductorVetadoPagina(
          sindicato: sindicato,
          ciInicial: ciInicial,
        ),
      ),
    ) ??
    false;

class _RegistroProductorVetadoPagina extends StatefulWidget {
  const _RegistroProductorVetadoPagina({
    required this.sindicato,
    this.ciInicial,
  });

  final Sindicato sindicato;
  final String? ciInicial;

  @override
  State<_RegistroProductorVetadoPagina> createState() =>
      _RegistroProductorVetadoPaginaState();
}

class _RegistroProductorVetadoPaginaState
    extends State<_RegistroProductorVetadoPagina> {
  final _formulario = GlobalKey<FormState>();
  final _ci = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _motivo = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _ci.text = widget.ciInicial ?? '';
  }

  @override
  void dispose() {
    _ci.dispose();
    _nombres.dispose();
    _apellidos.dispose();
    _motivo.dispose();
    super.dispose();
  }

  String? _obligatorio(String? valor) =>
      valor == null || valor.trim().isEmpty ? 'Este dato es obligatorio' : null;

  Future<void> _registrar() async {
    if (!_formulario.currentState!.validate() || _guardando) return;
    setState(() => _guardando = true);
    try {
      await PadronScope.of(context).vetos.registrarYVetar(
        RegistroProductorVetadoRequest(
          sindicatoId: widget.sindicato.id,
          ci: _ci.text.trim(),
          nombres: _nombres.text.trim(),
          apellidos: _apellidos.text.trim(),
          motivo: _motivo.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar y vetar')),
    body: Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sindicato: ${widget.sindicato.nombre}'),
          const SizedBox(height: 8),
          const Text(
            'Para una cédula que todavía no está registrada. Si ya existe, '
            'buscá al productor y vetalo desde su sindicato para no duplicarlo.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _ci,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Cédula de identidad *',
              border: OutlineInputBorder(),
            ),
            validator: _obligatorio,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nombres,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombres *',
              border: OutlineInputBorder(),
            ),
            validator: _obligatorio,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _apellidos,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Apellidos',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _motivo,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Motivo del veto *',
              border: OutlineInputBorder(),
            ),
            validator: _obligatorio,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _guardando ? null : _registrar,
            icon: _guardando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_off_outlined),
            label: Text(_guardando ? 'Registrando…' : 'Registrar y vetar'),
          ),
        ],
      ),
    ),
  );
}
