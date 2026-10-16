import 'package:flutter/material.dart';

import '../padron_scope.dart';
import '../widgets/estados.dart';

class OperadoresResenaPagina extends StatefulWidget {
  const OperadoresResenaPagina({super.key});

  @override
  State<OperadoresResenaPagina> createState() => _OperadoresResenaPaginaState();
}

class _OperadoresResenaPaginaState extends State<OperadoresResenaPagina> {
  final _resena = TextEditingController();
  final _formulario = GlobalKey<FormState>();
  bool _cargando = true;
  bool _guardando = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _resena.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resena = await PadronScope.of(
        context,
      ).credencialesOperadores.resena();
      if (mounted) _resena.text = resena;
    } catch (error) {
      if (mounted) _error = error;
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Scaffold(
      appBar: AppBar(title: const Text('Reseña común de autorización')),
      body: _cargando
          ? const Cargando()
          : _error != null
          ? FalloCarga(error: _error!, alReintentar: _cargar)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formulario,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Esta reseña se imprime en el reverso de todas las '
                          'credenciales del personal operador. La firma se '
                          'obtiene del ejecutivo vigente en el directorio de '
                          'la Federación Carrasco Tropical.',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _resena,
                          enabled: !_guardando,
                          minLines: 5,
                          maxLines: 12,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Reseña de autorización',
                            alignLabelWithHint: true,
                          ),
                          validator: (valor) =>
                              valor == null || valor.trim().isEmpty
                              ? 'Ingresá la reseña de autorización'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _guardando ? null : _guardar,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _guardando ? 'Guardando…' : 'Guardar reseña',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await PadronScope.of(
        context,
      ).credencialesOperadores.guardarResena(_resena.text);
      if (!mounted) return;
      setState(() => _guardando = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
