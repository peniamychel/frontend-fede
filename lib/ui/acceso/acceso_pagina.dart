import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../sesion_scope.dart';
import '../widgets/boton_tema.dart';
import '../widgets/estados.dart';

class AccesoPagina extends StatefulWidget {
  const AccesoPagina({super.key});
  @override
  State<AccesoPagina> createState() => _AccesoPaginaState();
}

class _AccesoPaginaState extends State<AccesoPagina> {
  final _codigo = TextEditingController();
  bool _enviando = false;
  bool _oculto = true;
  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_codigo.text.trim().isEmpty) {
      mostrarAviso(context, 'Ingresá tu código de acceso.');
      return;
    }
    setState(() => _enviando = true);
    try {
      await SesionScope.of(context).acceder(_codigo.text);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: const [BotonTema()]),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 58,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'PADRÓN FEDERACIÓN\nCARRASCO TROPICAL',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ingresá el código entregado por el administrador.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codigo,
                      autofocus: true,
                      obscureText: _oculto,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9-]'),
                        ),
                        LengthLimitingTextInputFormatter(100),
                      ],
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) {
                        if (!_enviando) _entrar();
                      },
                      decoration: InputDecoration(
                        labelText: 'Código de acceso',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _oculto = !_oculto),
                          icon: Icon(
                            _oculto
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _enviando ? null : _entrar,
                        icon: _enviando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Entrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
