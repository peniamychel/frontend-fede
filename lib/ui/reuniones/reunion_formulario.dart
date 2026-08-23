import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Convocar una reunión.
///
/// El tipo se elige primero porque decide todo lo demás: de qué nivel hay que
/// elegir al convocante, y a quiénes va a llamar la lista.
class ReunionFormulario extends StatefulWidget {
  const ReunionFormulario({super.key});

  @override
  State<ReunionFormulario> createState() => _ReunionFormularioState();
}

class _ReunionFormularioState extends State<ReunionFormulario> {
  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _lugar = TextEditingController();
  final _observaciones = TextEditingController();

  TipoReunion _tipo = TipoReunion.sindicato;
  DateTime _fecha = DateTime.now();
  int? _convocanteId;
  bool _guardando = false;
  bool _vetosHabilitados = false;

  /// Los convocantes posibles del nivel elegido. Se recarga al cambiar el tipo.
  late Future<List<_Opcion>> _convocantes;

  @override
  void initState() {
    super.initState();
    _recargarConvocantes();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _lugar.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  void _recargarConvocantes() {
    final padron = PadronScope.of(context);
    setState(() {
      _convocanteId = null;
      _convocantes = switch (_tipo.convoca) {
        Ambito.sindicato => padron.sindicatos.listar().then((l) => l
            .map((s) => _Opcion(s.id, s.nombre, 'Central ${s.centralNombre}'))
            .toList()),
        Ambito.central => padron.centrales.listar().then((l) => l
            .map((c) =>
                _Opcion(c.id, c.nombre, 'Federación ${c.federacionNombre}'))
            .toList()),
        Ambito.federacion => padron.federaciones
            .listar()
            .then((l) => l.map((f) => _Opcion(f.id, f.nombre, null)).toList()),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Convocar reunión')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tipo de reunión', style: tema.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    // Se muestran los cuatro con su explicación en vez de un
                    // desplegable: quién asiste es lo que distingue a una de
                    // otra, y elegir mal significa pasar lista contra la lista
                    // equivocada.
                    RadioGroup<TipoReunion>(
                      groupValue: _tipo,
                      // El guardado se filtra acá adentro y no anulando el
                      // callback: RadioGroup no admite null.
                      onChanged: (v) {
                        if (_guardando || v == null) return;
                        setState(() => _tipo = v);
                        _recargarConvocantes();
                      },
                      child: Column(
                        children: [
                          for (final t in TipoReunion.values)
                            RadioListTile<TipoReunion>(
                              value: t,
                              title: Text(t.etiqueta),
                              subtitle: Text(t.detalle,
                                  style: tema.textTheme.bodySmall?.copyWith(
                                      color: tema.colorScheme.outline)),
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Quién convoca — ${_tipo.convoca.etiqueta.toLowerCase()}',
                        style: tema.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    CargaAsync<List<_Opcion>>(
                      futuro: _convocantes,
                      alReintentar: _recargarConvocantes,
                      constructor: (context, opciones) {
                        if (opciones.isEmpty) {
                          return Text(
                            'No hay ${_tipo.convoca.etiqueta.toLowerCase()}es '
                            'cargadas.',
                            style: TextStyle(color: tema.colorScheme.error),
                          );
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: _convocanteId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '${_tipo.convoca.etiqueta} *',
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final o in opciones)
                              DropdownMenuItem(
                                value: o.id,
                                child: Text(
                                  o.detalle == null
                                      ? o.nombre
                                      : '${o.nombre} — ${o.detalle}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _guardando
                              ? null
                              : (v) => setState(() => _convocanteId = v),
                          validator: (v) =>
                              v == null ? 'Elegí quién convoca' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titulo,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ampliado ordinario de agosto',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Poné un título'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: tema.colorScheme.outline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Fecha'),
                      subtitle: Text(_fechaCorta),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: _guardando ? null : _elegirFecha,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lugar,
                      decoration: const InputDecoration(
                        labelText: 'Lugar',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _observaciones,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Apagado por omisión: la mayoría de las asambleas son
                    // informativas, y ofrecer el veto en todas invita a usarlo
                    // donde no corresponde. Igual se puede activar después,
                    // desde la propia reunión.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _vetosHabilitados,
                      onChanged: (v) => setState(() => _vetosHabilitados = v),
                      secondary: const Icon(Icons.gavel_outlined),
                      title: const Text('Se pueden decidir vetos'),
                      subtitle: Text(
                        'Solo si en esta asamblea se va a tratar alguna '
                        'sanción. Hace falta el acta igual.',
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('Convocar'),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _fechaCorta {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(_fecha.day)}/${dos(_fecha.month)}/${_fecha.year}';
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      // Un año para atrás para poder registrar una reunión que ya pasó, y dos
      // para adelante para convocarlas con tiempo.
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      final creada = await PadronScope.of(context).reuniones.crear(
            ReunionRequest(
              tipo: _tipo,
              convocanteId: _convocanteId!,
              titulo: _titulo.text.trim(),
              fecha: _fecha,
              lugar: _texto(_lugar),
              observaciones: _texto(_observaciones),
              vetosHabilitados: _vetosHabilitados,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(creada);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarError(context, e);
    }
  }

  String? _texto(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }
}

/// Una opción del desplegable de convocantes.
class _Opcion {
  const _Opcion(this.id, this.nombre, this.detalle);

  final int id;
  final String nombre;
  final String? detalle;
}
