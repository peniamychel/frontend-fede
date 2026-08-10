import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Alta y edición de una parcela.
///
/// El sindicato viene fijado y no se puede cambiar: la tierra no se muda. Al
/// crear se puede indicar quién la tiene, y eso abre su primer período de
/// tenencia; al editar ese campo no aparece, porque cambiar de manos es un
/// traspaso con fecha y motivo, no una corrección de datos.
class LoteFormulario extends StatefulWidget {
  const LoteFormulario({super.key, required this.sindicato, this.lote});

  final Sindicato sindicato;

  /// Null para crear una parcela nueva.
  final Lote? lote;

  bool get esEdicion => lote != null;

  @override
  State<LoteFormulario> createState() => _LoteFormularioState();
}

class _LoteFormularioState extends State<LoteFormulario> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _numero =
      TextEditingController(text: widget.lote?.numero ?? '');
  late final TextEditingController _superficie = TextEditingController(
      text: widget.lote?.superficie == null ? '' : '${widget.lote!.superficie}');
  late final TextEditingController _estado =
      TextEditingController(text: widget.lote?.estadoOriginal ?? '');

  late ExtensionLote? _extension = widget.lote?.extension;
  late Mercado? _mercado = widget.lote?.mercado;
  int? _tenedorId;
  bool _guardando = false;

  /// Candidatos a tenedor: los productores del sindicato. Solo al crear.
  late Future<List<Productor>> _productores;

  @override
  void initState() {
    super.initState();
    _productores = widget.esEdicion
        ? Future.value(const <Productor>[])
        : PadronScope.of(context)
            .productores
            .listar(
                sindicatoId: widget.sindicato.id,
                paginacion: const Paginacion(tamano: 300))
            .then((p) => p.contenido);
  }

  @override
  void dispose() {
    _numero.dispose();
    _superficie.dispose();
    _estado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar parcela' : 'Nueva parcela'),
      ),
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
                    _Fijo(
                      etiqueta: 'Sindicato',
                      valor: widget.sindicato.nombre,
                      nota: 'La tierra no se muda de sindicato.',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _numero,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Número de lote',
                              hintText: '74',
                              helperText: 'Puede repetirse: se anota, no se bloquea',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ExtensionLote?>(
                            initialValue: _extension,
                            decoration: const InputDecoration(
                              labelText: 'Ext.',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('—')),
                              for (final e in ExtensionLote.values)
                                DropdownMenuItem(
                                    value: e, child: Text(e.valor)),
                            ],
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => _extension = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _superficie,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Superficie (hectáreas)',
                        hintText: '12.5',
                        helperText: 'Dejalo vacío si todavía no se midió',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final texto = (v ?? '').trim().replaceAll(',', '.');
                        if (texto.isEmpty) return null;
                        final n = double.tryParse(texto);
                        if (n == null || n <= 0) {
                          return 'Escribí un número mayor que cero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _estado,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Estado del lote',
                        hintText: 'C-S',
                        helperText: 'Como lo escribe la planilla; el servidor '
                            'lo normaliza',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Mercado?>(
                      initialValue: _mercado,
                      decoration: const InputDecoration(
                        labelText: 'Mercado',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        for (final m in Mercado.values)
                          DropdownMenuItem(value: m, child: Text(m.etiqueta)),
                      ],
                      onChanged:
                          _guardando ? null : (v) => setState(() => _mercado = v),
                    ),
                    if (!widget.esEdicion) ...[
                      const SizedBox(height: 24),
                      Text('Quién la tiene', style: tema.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Se puede dejar sin tenedor: una parcela registrada sin '
                        'dueño conocido es mejor que una parcela sin registrar.',
                        style: tema.textTheme.bodySmall
                            ?.copyWith(color: tema.colorScheme.outline),
                      ),
                      const SizedBox(height: 8),
                      CargaAsync<List<Productor>>(
                        futuro: _productores,
                        alReintentar: () {},
                        constructor: (context, productores) =>
                            DropdownButtonFormField<int?>(
                          initialValue: _tenedorId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tenedor',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('Sin tenedor')),
                            for (final p in productores)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text(p.nombreCompleto,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: _guardando
                              ? null
                              : (v) => setState(() => _tenedorId = v),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(widget.esEdicion ? 'Guardar' : 'Crear parcela'),
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

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    final superficie =
        double.tryParse(_superficie.text.trim().replaceAll(',', '.'));

    final peticion = LoteRequest(
      sindicatoId: widget.sindicato.id,
      productorId: widget.esEdicion ? null : _tenedorId,
      numero: _texto(_numero),
      extension: _extension,
      estado: _texto(_estado),
      mercado: _mercado?.valor,
      superficie: superficie,
    );

    setState(() => _guardando = true);
    try {
      final repo = PadronScope.of(context).lotes;
      final lote = widget.esEdicion
          ? await repo.actualizar(widget.lote!.id, peticion)
          : await repo.crear(peticion);
      if (!mounted) return;
      Navigator.of(context).pop(lote);
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

/// Un dato que se muestra pero no se edita.
class _Fijo extends StatelessWidget {
  const _Fijo({required this.etiqueta, required this.valor, this.nota});

  final String etiqueta;
  final String valor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: tema.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta.toUpperCase(),
                    style: tema.textTheme.labelSmall
                        ?.copyWith(color: tema.colorScheme.outline)),
                Text(valor, style: tema.textTheme.titleSmall),
                if (nota != null)
                  Text(nota!,
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: tema.colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
