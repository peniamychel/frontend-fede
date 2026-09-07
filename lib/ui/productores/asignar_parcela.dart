import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Asignar y quitar la parcela de un productor, y cambiar su clasificación,
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
      await padron.lotes.crear(
        LoteRequest(
          sindicatoId: productor.sindicatoId,
          productorId: productor.id,
          numero: elegido.numero,
          superficie: elegido.superficie,
          estado: elegido.estado?.valor,
        ),
      );
    } else {
      final parcela = await padron.lotes.obtener(elegido.existenteId!);
      await padron.lotes.actualizar(
        parcela.id,
        LoteRequest(
          sindicatoId: parcela.sindicatoId,
          numero: parcela.numero,
          extension: parcela.extension,
          superficie: parcela.superficie,
          mercado: parcela.mercado?.valor,
          estado: elegido.estado?.valor,
        ),
      );
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
  BuildContext context,
  Lote lote,
  Productor productor,
) async {
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

/// Corrige el número sin cambiar de productor ni abrir otro
/// período de tenencia. Si el número queda compartido, el backend recalcula
/// automáticamente las letras A-H de ambos grupos.
Future<bool> cambiarNumeroParcela(BuildContext context, Lote lote) async {
  final List<Lote> lotes;
  try {
    lotes = await PadronScope.of(
      context,
    ).lotes.listar(sindicatoId: lote.sindicatoId);
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
  if (!context.mounted) return false;

  final cambio = await showDialog<_NumeroParcela>(
    context: context,
    builder: (context) => _DialogoCambiarNumero(lote: lote, lotes: lotes),
  );
  if (cambio == null || !context.mounted) return false;

  try {
    final actualizado = await PadronScope.of(context).lotes.actualizar(
      lote.id,
      LoteRequest(
        sindicatoId: lote.sindicatoId,
        numero: cambio.numero,
        superficie: lote.superficie,
        estado: lote.estadoOriginal ?? lote.estado.valor,
        mercado: lote.mercado?.valor,
      ),
    );
    if (context.mounted) {
      mostrarExito(
        context,
        'Número de lote actualizado',
        detalle: '${lote.codigo} → ${actualizado.codigo}',
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

/// Cambia la clasificación asociada a la participación de este productor.
Future<bool> cambiarClasificacionParcela(
  BuildContext context,
  Lote lote,
) async {
  final elegido = await showDialog<EstadoLote>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Clasificación de la parcela'),
      children: [
        for (final estado in clasificacionesParcela)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(estado),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: estado == lote.estado
                      ? const Icon(Icons.check, size: 20)
                      : null,
                ),
                Text(estado.etiqueta),
              ],
            ),
          ),
      ],
    ),
  );
  if (elegido == null || !context.mounted) return false;
  try {
    await PadronScope.of(context).lotes.actualizar(
      lote.id,
      LoteRequest(
        sindicatoId: lote.sindicatoId,
        numero: lote.numero,
        extension: lote.extension,
        superficie: lote.superficie,
        mercado: lote.mercado?.valor,
        estado: elegido.valor,
      ),
    );
    if (context.mounted) {
      mostrarExito(context, '${lote.codigo}: ${elegido.etiqueta}');
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

// ------------------------------------------------------------- los diálogos

/// Lo que devuelve un diálogo: crear algo nuevo, o tomar uno que ya existe.
class _Eleccion {
  const _Eleccion.nueva({this.numero, this.superficie, required this.estado})
    : nuevo = true,
      existenteId = null;

  const _Eleccion.existente(this.existenteId, {required this.estado})
    : nuevo = false,
      numero = null,
      superficie = null;

  final bool nuevo;
  final int? existenteId;

  final String? numero;
  final double? superficie;
  final EstadoLote? estado;
}

class _NumeroParcela {
  const _NumeroParcela(this.numero);

  final String numero;
}

class _DialogoCambiarNumero extends StatefulWidget {
  const _DialogoCambiarNumero({required this.lote, required this.lotes});

  final Lote lote;
  final List<Lote> lotes;

  @override
  State<_DialogoCambiarNumero> createState() => _DialogoCambiarNumeroState();
}

class _DialogoCambiarNumeroState extends State<_DialogoCambiarNumero> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _numero;

  @override
  void initState() {
    super.initState();
    _numero = TextEditingController(text: widget.lote.numero ?? '')
      ..addListener(_actualizar);
  }

  @override
  void dispose() {
    _numero.removeListener(_actualizar);
    _numero.dispose();
    super.dispose();
  }

  void _actualizar() => setState(() {});

  String get _numeroLimpio => _numero.text.trim();

  bool get _cambioReal => _numeroLimpio != (widget.lote.numero ?? '').trim();

  List<Lote> get _ocupantes {
    final numero = _numeroLimpio.toUpperCase();
    if (numero.isEmpty) return const [];
    return widget.lotes
        .where(
          (otro) =>
              otro.id != widget.lote.id &&
              otro.tieneTenedor &&
              otro.numero?.trim().toUpperCase() == numero,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ocupantes = _ocupantes;
    final lleno = ocupantes.length >= 8;
    final actualConSistema = widget.lote.estado == EstadoLote.conSistema;
    final hayOtroConSistema = ocupantes.any(
      (otro) => otro.estado == EstadoLote.conSistema,
    );
    final tema = Theme.of(context);
    return AlertDialog(
      title: const Text('Cambiar número de lote'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formulario,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El lote seguirá a nombre de ${widget.lote.tenedor?.nombre ?? 'su tenedor actual'}. '
                  'Solo se corregirá su número.',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _numero,
                  autofocus: true,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo número *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Ingresá el número del lote'
                      : null,
                ),
                if (_numeroLimpio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lleno
                          ? tema.colorScheme.errorContainer
                          : tema.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ocupantes.isEmpty
                              ? 'Ese número no tiene otro productor: el lote quedará sin letra y el código del productor no cambiará.'
                              : lleno
                              ? 'Ese número ya tiene ocho productores (A-H).'
                              : actualConSistema && !hayOtroConSistema
                              ? 'Este productor tiene Sistema: recibirá la letra A y las letras de los demás se reordenarán.'
                              : 'Ya tiene ${ocupantes.length} productor(es). Las letras se recalcularán automáticamente, dando prioridad a quienes tienen Sistema.',
                          style: tema.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'La letra solo pertenece al lote; ningún código de padrón se renumera.',
                          style: tema.textTheme.bodySmall,
                        ),
                        for (final otro in ocupantes)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '${otro.tenedor!.codigoPadron ?? otro.tenedor!.letra ?? '—'} · '
                              '${otro.tenedor!.nombre} · ${otro.estado.etiqueta}',
                              style: tema.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: lleno || !_cambioReal ? null : _guardar,
          child: const Text('Guardar número'),
        ),
      ],
    );
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(_NumeroParcela(_numeroLimpio));
  }
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
  Lote? _elegida;
  List<Lote> _libres = const [];
  List<Lote> _todas = const [];
  late EstadoLote _estado =
      clasificacionesParcela.contains(widget.productor.clasificacion)
      ? widget.productor.clasificacion!
      : EstadoLote.sinSistema;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _numero.addListener(_alCambiarNumero);
    _cargarLibres();
  }

  @override
  void dispose() {
    _numero.removeListener(_alCambiarNumero);
    _numero.dispose();
    _superficie.dispose();
    super.dispose();
  }

  Future<void> _cargarLibres() async {
    try {
      final lotes = await PadronScope.of(
        context,
      ).lotes.listar(sindicatoId: widget.productor.sindicatoId);
      if (!mounted) return;
      setState(() {
        _todas = lotes;
        _libres = lotes.where((l) => !l.tieneTenedor).toList(growable: false);
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _alCambiarNumero() {
    if (mounted) setState(() {});
  }

  List<Lote> get _ocupantes {
    final numero = _limpio(_numero)?.toUpperCase();
    if (numero == null) return const [];
    return _todas
        .where(
          (lote) =>
              lote.tieneTenedor && lote.numero?.trim().toUpperCase() == numero,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar parcela'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.productor.revisionLotePendiente) ...[
                  Text(widget.productor.resumenRevisionLote),
                  const Text(
                    'Completá el número de lote para salir de la revisión. '
                    'La clasificación del Excel queda preseleccionada si existe.',
                  ),
                  const SizedBox(height: 16),
                ],
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
                  TextFormField(
                    controller: _numero,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'N° de parcela *',
                    ),
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Ingresá el número de parcela'
                        : null,
                  ),
                  if (_limpio(_numero) != null) ...[
                    const SizedBox(height: 12),
                    _resumenNumero(context),
                  ],
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
                    decoration: const InputDecoration(
                      labelText: 'Parcela sin tenedor *',
                    ),
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
                    onChanged: (v) => setState(() {
                      _elegida = v;
                      if (v != null &&
                          clasificacionesParcela.contains(v.estado)) {
                        _estado = v.estado;
                      }
                    }),
                    validator: (v) => v == null ? 'Elegí una parcela' : null,
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EstadoLote>(
                  initialValue: _estado,
                  decoration: const InputDecoration(
                    labelText: 'Clasificación *',
                  ),
                  items: [
                    for (final estado in clasificacionesParcela)
                      DropdownMenuItem(
                        value: estado,
                        child: Text(estado.etiqueta),
                      ),
                  ],
                  onChanged: (valor) {
                    if (valor != null) {
                      setState(() => _estado = valor);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _nueva && _ocupantes.length >= 8 ? null : _aceptar,
          child: const Text('Asignar'),
        ),
      ],
    );
  }

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    if (_nueva) {
      Navigator.of(context).pop(
        _Eleccion.nueva(
          numero: _limpio(_numero),
          superficie: double.tryParse(
            (_limpio(_superficie) ?? '').replaceAll(',', '.'),
          ),
          estado: _estado,
        ),
      );
    } else {
      if (_elegida == null) return;
      Navigator.of(
        context,
      ).pop(_Eleccion.existente(_elegida!.id, estado: _estado));
    }
  }

  String? _limpio(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Widget _resumenNumero(BuildContext context) {
    final tema = Theme.of(context);
    final ocupantes = _ocupantes;
    final lleno = ocupantes.length >= 8;
    final cantidadConSistema = ocupantes
        .where((lote) => lote.estado == EstadoLote.conSistema)
        .length;
    final proxima = lleno
        ? null
        : String.fromCharCode(
            65 +
                (_estado == EstadoLote.conSistema
                    ? cantidadConSistema
                    : ocupantes.length),
          );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lleno
            ? tema.colorScheme.errorContainer
            : tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ocupantes.isEmpty
                ? 'Número disponible: el lote quedará sin letra y el código del productor no cambiará.'
                : lleno
                ? 'Ya tiene ocho productores (A-H).'
                : _estado == EstadoLote.conSistema
                ? 'Ya tiene ${ocupantes.length} productor(es). Como esta clasificación es Sistema, se asignará la letra $proxima y se reordenarán las demás.'
                : cantidadConSistema > 0
                ? 'Ya tiene ${ocupantes.length} productor(es). Quienes tienen Sistema conservan las primeras letras; se asignará la letra $proxima.'
                : 'Ya tiene ${ocupantes.length} productor(es). Se asignará la letra $proxima.',
            style: tema.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'La letra solo pertenece al lote; ningún código de padrón se renumera.',
            style: tema.textTheme.bodySmall,
          ),
          for (var i = 0; i < ocupantes.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '${ocupantes[i].tenedor!.codigoPadron ?? ocupantes[i].tenedor!.letra ?? String.fromCharCode(65 + i)} · '
                '${ocupantes[i].tenedor!.nombre} · ${ocupantes[i].estado.etiqueta}',
                style: tema.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
