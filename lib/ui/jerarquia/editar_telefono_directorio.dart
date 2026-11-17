import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

Future<Directorio?> mostrarEditorTelefonoDirectorio(
  BuildContext context, {
  required Ambito ambito,
  required int id,
  required String nombre,
  Directorio? directorio,
}) async {
  final repo = PadronScope.of(context).directorios;
  late final consulta = repo.obtener(ambito, id);
  Widget editar(Directorio datos) => _EditarTelefono(
    nombre: nombre,
    telefono: datos.telefono,
    alGuardar: (telefono) => repo.actualizarTelefono(ambito, id, telefono),
  );

  final actualizado = await showDialog<Directorio>(
    context: context,
    builder: (context) {
      if (directorio != null) return editar(directorio);
      return FutureBuilder<Directorio>(
        future: consulta,
        builder: (context, estado) {
          final datos = estado.data;
          if (datos != null) return editar(datos);
          final error = estado.error;
          return AlertDialog(
            title: const Text('Editar teléfono'),
            content: error == null
                ? const SizedBox(
                    height: 96,
                    child: Cargando(mensaje: 'Cargando teléfono…'),
                  )
                : Text(
                    error is ApiException
                        ? error.mensaje
                        : 'No se pudo consultar el teléfono.',
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );
    },
  );
  if (context.mounted && actualizado != null) {
    mostrarExito(context, 'Teléfono actualizado');
  }
  return actualizado;
}

class _EditarTelefono extends StatefulWidget {
  const _EditarTelefono({
    required this.nombre,
    required this.telefono,
    required this.alGuardar,
  });

  final String nombre;
  final String? telefono;
  final Future<Directorio> Function(String telefono) alGuardar;

  @override
  State<_EditarTelefono> createState() => _EditarTelefonoState();
}

class _EditarTelefonoState extends State<_EditarTelefono> {
  static final _formato = RegExp(r'^\+?[0-9() .-]*[0-9][0-9() .-]*$');
  final _formulario = GlobalKey<FormState>();
  late String _telefono = widget.telefono ?? '';
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actualizado = await widget.alGuardar(_telefono.trim());
      if (mounted) Navigator.of(context).pop(actualizado);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error is ApiException
            ? error.mensaje
            : 'No se pudo guardar el teléfono. Volvé a intentarlo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertDialog(
      scrollable: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Editar teléfono'),
          Text(widget.nombre, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      content: Form(
        key: _formulario,
        child: TextFormField(
          initialValue: _telefono,
          autofocus: true,
          enabled: !_guardando,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: 'Número de teléfono',
            errorText: _error,
            errorMaxLines: 3,
          ),
          validator: (valor) {
            final numero = valor?.trim() ?? '';
            if (numero.isEmpty || _formato.hasMatch(numero)) return null;
            return 'Ingresá un número de teléfono válido.';
          },
          onChanged: (valor) {
            _telefono = valor;
            if (_error != null) setState(() => _error = null);
          },
          onFieldSubmitted: (_) => _guardar(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
