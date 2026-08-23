import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Asignar y quitar la parcela de un productor, y el sistema de esa parcela,
/// desde su ficha.
///
/// Nadie puede tener dos parcelas a su nombre, así que estas pantallas son
/// binarias: o tiene una y se le puede quitar, o no tiene y se le puede dar.
/// Esa regla la impone el backend; acá solo se evita ofrecer lo que sabemos que
/// va a ser rechazado.
///
/// Quitar no borra nada: la parcela sigue existiendo y queda sin tenedor —una
/// situación real, alguien vendió y el comprador todavía no está cargado— y el
/// período que termina queda en el historial con su fecha.

/// Le da una parcela al productor: una nueva, o una del sindicato que hoy no
/// tenga nadie. Devuelve true si algo cambió.
Future<bool> asignarParcela(BuildContext context, Productor productor) async {
  final elegido = await showDialog<_Eleccion>(
    context: context,
    builder: (_) => _DialogoParcela(productor: productor),
  );
  if (elegido == null || !context.mounted) return false;

  final padron = PadronScope.of(context);
  try {
    if (elegido.nuevo) {
      await padron.lotes.crear(LoteRequest(
        sindicatoId: productor.sindicatoId,
        productorId: productor.id,
        numero: elegido.numero,
        extension: elegido.extension,
        superficie: elegido.superficie,
      ));
    } else {
      await padron.lotes.traspasar(
        elegido.existenteId!,
        TraspasoRequest(motivo: MotivoTraspaso.otro, productorId: productor.id),
      );
    }
    if (context.mounted) {
      mostrarExito(context, 'Parcela asignada a ${productor.nombreCompleto}');
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

/// Le saca la parcela: sigue existiendo, pero sin tenedor.
Future<bool> quitarParcela(
    BuildContext context, Lote lote, Productor productor) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Quitarle la parcela?'),
      content: Text(
        'La parcela ${lote.codigo} deja de estar a nombre de '
        '${productor.nombreCompleto} y queda sin tenedor. No se borra: sigue '
        'en el sindicato, y el período que termina queda en el historial.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Quitar'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return false;

  try {
    await PadronScope.of(context).lotes.traspasar(
          lote.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro),
        );
    if (context.mounted) {
      mostrarExito(context, '${lote.codigo} quedó sin tenedor');
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

/// Instala un sistema en la parcela: uno nuevo, o uno de los que están sin
/// instalar en ninguna.
Future<bool> asignarSistema(BuildContext context, Lote lote) async {
  final elegido = await showDialog<_Eleccion>(
    context: context,
    builder: (_) => const _DialogoSistema(),
  );
  if (elegido == null || !context.mounted) return false;

  final padron = PadronScope.of(context);
  try {
    final int sistemaId;
    if (elegido.nuevo) {
      final creado = await padron.sistemas.crear(
          SistemaRequest(codigo: elegido.codigo!, descripcion: elegido.descripcion));
      sistemaId = creado.id;
    } else {
      sistemaId = elegido.existenteId!;
    }
    await padron.sistemas.trasladar(
        sistemaId, lote.id, const TraspasoRequest(motivo: MotivoTraspaso.otro));
    if (context.mounted) {
      mostrarExito(context, 'Sistema instalado en ${lote.codigo}');
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

/// Retira el sistema de la parcela. Queda disponible para otra.
Future<bool> quitarSistema(BuildContext context, Lote lote) async {
  final sistema = lote.sistema;
  if (sistema == null) return false;

  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Retirar el sistema?'),
      content: Text(
        '${sistema.codigo} sale de ${lote.codigo} y queda disponible para otra '
        'parcela. El período en esta queda en el historial.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Retirar'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return false;

  try {
    await PadronScope.of(context).sistemas.trasladar(
          sistema.sistemaId,
          null,
          const TraspasoRequest(motivo: MotivoTraspaso.otro),
        );
    if (context.mounted) mostrarExito(context, '${sistema.codigo} quedó disponible');
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

// ------------------------------------------------------------- los diálogos

/// Lo que devuelve un diálogo: crear algo nuevo, o tomar uno que ya existe.
class _Eleccion {
  const _Eleccion.nueva({this.numero, this.extension, this.superficie})
      : nuevo = true,
        existenteId = null,
        codigo = null,
        descripcion = null;

  const _Eleccion.nuevoSistema({this.codigo, this.descripcion})
      : nuevo = true,
        existenteId = null,
        numero = null,
        extension = null,
        superficie = null;

  const _Eleccion.existente(this.existenteId)
      : nuevo = false,
        numero = null,
        extension = null,
        superficie = null,
        codigo = null,
        descripcion = null;

  final bool nuevo;
  final int? existenteId;

  final String? numero;
  final ExtensionLote? extension;
  final double? superficie;

  final String? codigo;
  final String? descripcion;
}

class _DialogoParcela extends StatefulWidget {
  const _DialogoParcela({required this.productor});

  final Productor productor;

  @override
  State<_DialogoParcela> createState() => _DialogoParcelaState();
}

class _DialogoParcelaState extends State<_DialogoParcela> {
  final _formulario = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _superficie = TextEditingController();

  bool _nueva = true;
  ExtensionLote? _extension;
  Lote? _elegida;
  List<Lote> _libres = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarLibres();
  }

  @override
  void dispose() {
    _numero.dispose();
    _superficie.dispose();
    super.dispose();
  }

  Future<void> _cargarLibres() async {
    try {
      final lotes = await PadronScope.of(context)
          .lotes
          .listar(sindicatoId: widget.productor.sindicatoId);
      if (!mounted) return;
      setState(() {
        _libres = lotes.where((l) => !l.tieneTenedor).toList(growable: false);
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar parcela'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Nueva')),
                  ButtonSegment(value: false, label: Text('Existente')),
                ],
                selected: {_nueva},
                onSelectionChanged: (v) => setState(() => _nueva = v.first),
              ),
              const SizedBox(height: 16),
              if (_nueva) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _numero,
                        autofocus: true,
                        decoration:
                            const InputDecoration(labelText: 'N° de parcela'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<ExtensionLote?>(
                        initialValue: _extension,
                        decoration:
                            const InputDecoration(labelText: 'Extensión'),
                        items: [
                          const DropdownMenuItem<ExtensionLote?>(
                              value: null, child: Text('—')),
                          for (final e in ExtensionLote.values)
                            DropdownMenuItem<ExtensionLote?>(
                                value: e, child: Text(e.valor)),
                        ],
                        onChanged: (v) => setState(() => _extension = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _superficie,
                  decoration: const InputDecoration(
                    labelText: 'Superficie en hectáreas',
                    helperText: 'Opcional. Se puede medir después.',
                  ),
                ),
              ] else if (_cargando)
                const LinearProgressIndicator()
              else if (_libres.isEmpty)
                Text(
                  'En ${widget.productor.sindicatoNombre} no hay parcelas sin '
                  'tenedor. Podés crear una nueva.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                DropdownButtonFormField<Lote?>(
                  initialValue: _elegida,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Parcela sin tenedor *'),
                  items: [
                    for (final l in _libres)
                      DropdownMenuItem<Lote?>(
                        value: l,
                        child: Text(
                          l.codigo.isEmpty ? 'Parcela ${l.id}' : l.codigo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _elegida = v),
                  validator: (v) => v == null ? 'Elegí una parcela' : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aceptar,
          child: const Text('Asignar'),
        ),
      ],
    );
  }

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    if (_nueva) {
      Navigator.of(context).pop(_Eleccion.nueva(
        numero: _limpio(_numero),
        extension: _extension,
        superficie:
            double.tryParse((_limpio(_superficie) ?? '').replaceAll(',', '.')),
      ));
    } else {
      if (_elegida == null) return;
      Navigator.of(context).pop(_Eleccion.existente(_elegida!.id));
    }
  }

  String? _limpio(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }
}

class _DialogoSistema extends StatefulWidget {
  const _DialogoSistema();

  @override
  State<_DialogoSistema> createState() => _DialogoSistemaState();
}

class _DialogoSistemaState extends State<_DialogoSistema> {
  final _formulario = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _descripcion = TextEditingController();

  bool _nuevo = true;
  Sistema? _elegido;
  List<Sistema> _libres = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarLibres();
  }

  @override
  void dispose() {
    _codigo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarLibres() async {
    try {
      final sistemas =
          await PadronScope.of(context).sistemas.listar(disponibles: true);
      if (!mounted) return;
      setState(() {
        _libres = sistemas;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar sistema'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Nuevo')),
                  ButtonSegment(value: false, label: Text('Existente')),
                ],
                selected: {_nuevo},
                onSelectionChanged: (v) => setState(() => _nuevo = v.first),
              ),
              const SizedBox(height: 16),
              if (_nuevo) ...[
                TextFormField(
                  controller: _codigo,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Código del sistema *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Poné un código'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
              ] else if (_cargando)
                const LinearProgressIndicator()
              else if (_libres.isEmpty)
                Text(
                  'No hay sistemas sin instalar. Podés dar de alta uno nuevo.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                DropdownButtonFormField<Sistema?>(
                  initialValue: _elegido,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Sistema disponible *'),
                  items: [
                    for (final s in _libres)
                      DropdownMenuItem<Sistema?>(
                        value: s,
                        child: Text(s.codigo, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _elegido = v),
                  validator: (v) => v == null ? 'Elegí un sistema' : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aceptar,
          child: const Text('Asignar'),
        ),
      ],
    );
  }

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    if (_nuevo) {
      Navigator.of(context).pop(_Eleccion.nuevoSistema(
        codigo: _codigo.text.trim(),
        descripcion:
            _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
      ));
    } else {
      if (_elegido == null) return;
      Navigator.of(context).pop(_Eleccion.existente(_elegido!.id));
    }
  }
}
