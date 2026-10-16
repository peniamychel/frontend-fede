import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/texto_busqueda.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../productores/productor_formulario.dart';
import '../widgets/estados.dart';

/// Edición por celda. Una única cola evita que respuestas de guardados
/// simultáneos deshagan cambios o renumeraciones de lotes compartidos.
class EdicionProductoresSindicatoPagina extends StatefulWidget {
  const EdicionProductoresSindicatoPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<EdicionProductoresSindicatoPagina> createState() => _EdicionState();
}

class _EdicionState extends State<EdicionProductoresSindicatoPagina> {
  final _filas = <_Fila>[];
  final _visibles = <_Fila>[];
  final _busqueda = TextEditingController();
  final _impresosEditados = <int>{};
  Future<void> _cola = Future.value();
  OrdenProductores _orden = OrdenProductores.apellidos;
  bool _cargando = true;
  bool _iniciada = false;
  bool _cambio = false;
  bool _saliendo = false;
  bool _permitirSalir = false;
  bool _creando = false;
  bool _recargaPendiente = false;
  int? _filaSie;
  bool _decisionSieAbierta = false;
  int? _filaObservacion;
  bool _dialogoObservacionAbierto = false;
  Object? _error;
  late Padron _padron;
  Timer? _temporizadorGlobo;
  _Campo? _campoConGlobo;

  bool get _ocupado => _creando || _filaSie != null || _filaObservacion != null;
  bool get _puedeCrear => context.puedeRegistrarProductores;
  bool get _puedeObservar =>
      context.puede('PRODUCTORES_OBSERVAR') ||
      context.puede('PRODUCTORES_EDITAR');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciada) {
      _iniciada = true;
      _padron = PadronScope.of(context);
      unawaited(_cargar());
    }
  }

  Future<List<Productor>> _todos() async {
    final productores = <Productor>[];
    var paginacion = const Paginacion(tamano: 100);
    while (true) {
      final pagina = await _padron.productores.listar(
        sindicatoId: widget.sindicato.id,
        orden: OrdenProductores.apellidos,
        paginacion: paginacion,
      );
      productores.addAll(pagina.contenido);
      if (pagina.esUltima || pagina.estaVacia) return productores;
      paginacion = paginacion.siguiente();
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final productores = await _todos();
      if (!mounted) return;
      setState(() {
        for (final p in productores) {
          _filas.add(_crearFila(p));
        }
        _ordenar();
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _cargando = false;
        });
      }
    }
  }

  _Fila _crearFila(Productor p) {
    final fila = _Fila(p);
    for (final c in fila.campos.values) {
      c.foco.addListener(() {
        if (!c.foco.hasFocus && mounted) _guardar(fila, c);
      });
    }
    return fila;
  }

  Future<void> _actualizarTrasAlta() async {
    try {
      final productores = await _todos();
      if (!mounted) return;
      setState(() {
        final existentes = {for (final f in _filas) f.productor.id: f};
        for (final p in productores) {
          final fila = existentes[p.id];
          if (fila == null) {
            _filas.add(_crearFila(p));
            continue;
          }
          fila.productor = p;
          for (final c in fila.campos.values) {
            // El alta puede reasignar letras de lotes compartidos. Refrescar
            // solo celdas limpias, sin perder un borrador con error.
            if (c.pendientes == 0 &&
                c.error == null &&
                c.texto.text.trim() == c.guardado) {
              c.guardado = _valor(p, c.nombre);
              c.objetivo = c.guardado;
              c.texto.text = c.guardado;
            }
          }
        }
        _ordenar();
        _recargaPendiente = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recargaPendiente = true);
      mostrarAviso(
        context,
        'El productor quedó registrado, pero no se pudo actualizar la lista. Reintentá actualizarla; no hace falta registrarlo de nuevo.',
      );
    }
  }

  Future<void> _crearProductor({bool soloActualizar = false}) async {
    if (_ocupado ||
        _saliendo ||
        _cargando ||
        _error != null ||
        (!soloActualizar && !_puedeCrear)) {
      return;
    }
    _ocultarGlobo();
    setState(() => _creando = true);
    FocusManager.instance.primaryFocus?.unfocus();
    // Confirmar las celdas antes de que el alta pueda renumerar un lote.
    // Un error permanece en la tabla: no se descarta ni impide el alta.
    for (final f in _filas) {
      for (final c in f.campos.values) {
        _guardar(f, c);
      }
    }
    try {
      await _cola;
      if (!mounted) return;
      if (soloActualizar) {
        await _actualizarTrasAlta();
        return;
      }
      final creado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ProductorFormulario(
            sindicatoFijo: widget.sindicato,
            abrirFichaAlCrear: false,
          ),
        ),
      );
      if (!mounted || creado != true) return;
      _cambio = true;
      await _actualizarTrasAlta();
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  void _ordenar() {
    String valor(_Fila f, String campo) =>
        f.campos[campo]!.guardado.toUpperCase();
    int lote(_Fila a, _Fila b) {
      final x = valor(a, 'numeroLote'), y = valor(b, 'numeroLote');
      if (x.isEmpty || y.isEmpty) return x.isEmpty ? (y.isEmpty ? 0 : 1) : -1;
      final nx = int.tryParse(RegExp(r'^\d+').firstMatch(x)?.group(0) ?? '');
      final ny = int.tryParse(RegExp(r'^\d+').firstMatch(y)?.group(0) ?? '');
      if (nx != null && ny != null && nx != ny) return nx.compareTo(ny);
      if ((nx == null) != (ny == null)) return nx == null ? 1 : -1;
      return x.compareTo(y);
    }

    _filas.sort((a, b) {
      final primero = switch (_orden) {
        OrdenProductores.numeroLote => lote(a, b),
        OrdenProductores.nombres => valor(
          a,
          'nombres',
        ).compareTo(valor(b, 'nombres')),
        _ => valor(a, 'apellidos').compareTo(valor(b, 'apellidos')),
      };
      if (primero != 0) return primero;
      final secundario = _orden == OrdenProductores.nombres
          ? 'apellidos'
          : 'nombres';
      final segundo = valor(a, secundario).compareTo(valor(b, secundario));
      return segundo != 0 ? segundo : a.productor.id.compareTo(b.productor.id);
    });
    _filtrar();
  }

  void _filtrar() {
    final texto = textoParaBusqueda(_busqueda.text);
    final numerico = RegExp(r'^\d').hasMatch(texto);
    final patron = RegExp(
      texto.split(RegExp(r'\s+')).map(RegExp.escape).join('.*'),
    );
    bool coincide(_Fila fila) {
      if (texto.isEmpty) return true;
      final p = fila.productor;
      final ci = textoParaBusqueda(fila.campos['ci']!.guardado);
      final codigos = [
        p.codigo,
        p.codigoPadron,
      ].whereType<String>().map(textoParaBusqueda);
      if (numerico) return ci.startsWith(texto) || codigos.contains(texto);
      final nombres = fila.campos['nombres']!.guardado;
      final apellidos = fila.campos['apellidos']!.guardado;
      return ci.startsWith(texto) ||
          codigos.any((codigo) => codigo.contains(texto)) ||
          [
            '$nombres $apellidos',
            '$apellidos $nombres',
            '${p.nombres} ${p.apellidos ?? ''}',
            '${p.apellidos ?? ''} ${p.nombres}',
          ].any((nombre) => patron.hasMatch(textoParaBusqueda(nombre)));
    }

    // Solo recalcular al buscar u ordenar: una fila que se está corrigiendo
    // no desaparece en medio de la edición si deja de coincidir con el nombre.
    _visibles
      ..clear()
      ..addAll(_filas.where(coincide));
  }

  void _buscar() {
    _ocultarGlobo();
    setState(_filtrar);
  }

  void _guardar(_Fila fila, _Campo campo) {
    final valor = campo.texto.text.trim();
    if (valor == campo.objetivo && campo.error == null) return;
    if (valor == campo.guardado && campo.pendientes == 0) {
      setState(() {
        campo.error = null;
        campo.objetivo = valor;
      });
      return;
    }
    if ((campo.nombre == 'nombres' || campo.nombre == 'numeroLote') &&
        valor.isEmpty) {
      setState(() => campo.error = 'Este campo no puede quedar vacío');
      return;
    }
    campo.objetivo = valor;
    final version = ++campo.version;
    setState(() {
      campo.pendientes++;
      campo.error = null;
    });
    _cola = _cola.then((_) async {
      try {
        if (campo.nombre == 'numeroLote') {
          final actuales = await _padron.lotes.listar(
            productorId: fila.productor.id,
          );
          if (actuales.length > 1) {
            throw const ApiException(
              estado: 409,
              mensaje:
                  'Este productor tiene varias parcelas. Editá el lote desde su ficha.',
            );
          }
          final referencia = actuales.isEmpty ? null : actuales.first;
          // «4 B» reserva B; un número sin letra usa el orden automático.
          final partes = RegExp(
            r'^(.*?)\s+([A-H])$',
            caseSensitive: false,
          ).firstMatch(valor);
          var numero = partes?.group(1) ?? valor;
          // La subdivisión histórica es parte del rótulo mostrado, no del
          // número base; no duplicarla como «22-A-A» al editar.
          final sufijo = referencia?.extension == null
              ? null
              : '-${referencia!.extension!.valor}';
          if (sufijo != null && numero.toUpperCase().endsWith(sufijo)) {
            numero = numero.substring(0, numero.length - sufijo.length);
          }
          final lote = await _padron.lotes.guardarNumeroProductor(
            fila.productor.id,
            numero,
            loteId: referencia?.id,
            letra: partes?.group(2)?.toUpperCase() ?? '',
          );
          _confirmar(campo, valor, lote.codigo, version);
          _cambio = true;
          // Cambiar un lote puede cambiar las letras de otras filas.
          try {
            for (final p in await _todos()) {
              final existentes = _filas.where((f) => f.productor.id == p.id);
              if (existentes.isEmpty) continue;
              final otra = existentes.first;
              otra.productor = p;
              final c = otra.campos['numeroLote']!;
              if (c.pendientes == 0 && c.texto.text.trim() == c.guardado) {
                c.guardado = p.numeroLote ?? '';
                c.objetivo = c.guardado;
                c.texto.text = c.guardado;
              }
            }
          } catch (_) {
            // El PUT ya quedó confirmado: un fallo de refresco no debe
            // presentarse como un guardado fallido ni repetir la escritura.
            if (mounted) {
              mostrarAviso(
                context,
                'Lote guardado. No se pudieron actualizar las letras de las otras filas.',
              );
            }
          }
        } else {
          final p = await _padron.productores.actualizarCampo(
            fila.productor.id,
            campo.nombre,
            valor,
          );
          fila.productor = p;
          _confirmar(campo, valor, _valor(p, campo.nombre), version);
          _cambio = true;
          if (campo.nombre == 'ci') {
            // Cambiar una CI afecta también al otro productor que la compartía.
            // Se actualizan solo los modelos, sin tocar borradores, focos ni scroll.
            try {
              final actualizados = await _todos();
              if (!mounted) return;
              final porId = {for (final p in actualizados) p.id: p};
              for (final otra in _filas) {
                otra.productor = porId[otra.productor.id] ?? otra.productor;
              }
            } catch (_) {
              if (mounted) {
                mostrarAviso(
                  context,
                  'CI guardada. No se pudieron actualizar los conflictos de las otras filas; volvé a cargar la lista.',
                );
              }
            }
          }
        }
        if (fila.productor.credencialImpresa &&
            !fila.productor.reimpresionFasePendiente) {
          _impresosEditados.add(fila.productor.id);
        }
      } catch (e) {
        if (campo.version == version) {
          campo.error = e is ApiException
              ? e.descripcion
              : e is SinConexionException
              ? e.descripcion
              : '$e';
          campo.objetivo = null;
        }
      } finally {
        campo.pendientes--;
        if (mounted) setState(() {});
      }
    });
  }

  void _confirmar(_Campo campo, String enviado, String guardado, int version) {
    campo.guardado = guardado;
    if (campo.version == version) {
      campo.objetivo = guardado;
      campo.error = null;
      if (campo.texto.text.trim() == enviado) campo.texto.text = guardado;
      if (mounted &&
          !_saliendo &&
          !_ocupado &&
          campo.texto.text.trim() == guardado) {
        _ocultarGlobo();
        _campoConGlobo = campo;
        campo.globo.show();
        _temporizadorGlobo = Timer(const Duration(seconds: 2), _ocultarGlobo);
      }
    }
  }

  void _ocultarGlobo() {
    _temporizadorGlobo?.cancel();
    _temporizadorGlobo = null;
    final globo = _campoConGlobo?.globo;
    if (globo != null && globo.isShowing) globo.hide();
    _campoConGlobo = null;
  }

  Future<void> _sincronizarFila(_Fila fila) async {
    final detalle = await _padron.productores.obtener(fila.productor.id);
    if (!mounted) return;
    setState(() {
      fila.productor = detalle.productor;
      for (final c in fila.campos.values) {
        c.guardado = _valor(detalle.productor, c.nombre);
        c.objetivo = c.guardado;
        c.error = null;
        c.texto.text = c.guardado;
      }
    });
  }

  void _revisarSie(_Fila fila) {
    if (_ocupado || _saliendo || !context.puede('SIE_REVISAR')) return;
    _ocultarGlobo();
    FocusManager.instance.primaryFocus?.unfocus();
    for (final c in fila.campos.values) {
      _guardar(fila, c);
    }
    setState(() {
      _filaSie = fila.productor.id;
      fila.avisoSie = null;
    });
    // La consulta y su decisión comparten la cola del guardado automático:
    // nunca consultar un CI anterior ni sobrescribir una decisión con un PUT.
    _cola = _cola.then((_) async {
      try {
        if (!mounted) return;
        if (fila.campos.values.any((c) => c.error != null)) {
          mostrarAviso(
            context,
            'Corregí los campos con error antes de revisar por SIE.',
          );
          return;
        }
        if (fila.productor.ci?.trim().isNotEmpty != true) {
          fila.avisoSie = 'Falta CI';
          mostrarAviso(
            context,
            'Ingresá y guardá la cédula antes de revisar por SIE.',
          );
          return;
        }
        final resultado = await _padron.productores.verificarManualmenteConSie(
          fila.productor.id,
        );
        if (!mounted) return;
        if (resultado.estado == EstadoRevisionSie.noDisponible) {
          fila.avisoSie = resultado.mensaje;
          mostrarAviso(context, resultado.mensaje);
          return;
        }
        // REQUIERE_CONFIRMACION también persiste la advertencia SIE.
        _cambio = true;
        await _sincronizarFila(fila);
        if (!mounted) return;
        setState(() => _decisionSieAbierta = true);
        final decision = await _mostrarResultadoSie(fila, resultado);
        if (!mounted) return;
        setState(() => _decisionSieAbierta = false);
        if (decision == null) return;
        RevisionSieProductor confirmado;
        if (decision == _DecisionSie.aceptar) {
          confirmado = await _padron.productores.confirmarRevisionSie(
            fila.productor.id,
            resultado,
            aceptar: true,
          );
        } else {
          confirmado = await _padron.productores.aprobarDatosActualesSie(
            fila.productor.id,
          );
        }
        if (confirmado.datosModificados &&
            fila.productor.credencialImpresa &&
            !fila.productor.reimpresionFasePendiente) {
          _impresosEditados.add(fila.productor.id);
        }
        await _sincronizarFila(fila);
        if (mounted) mostrarExito(context, confirmado.mensaje);
      } catch (e) {
        fila.avisoSie = e is ApiException
            ? e.descripcion
            : e is SinConexionException
            ? e.descripcion
            : '$e';
        if (mounted) mostrarError(context, e);
      } finally {
        if (mounted) {
          setState(() {
            _filaSie = null;
            _decisionSieAbierta = false;
          });
        }
      }
    });
  }

  void _editarObservacion(_Fila fila) {
    if (_ocupado || _saliendo || !_puedeObservar) return;
    _ocultarGlobo();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _filaObservacion = fila.productor.id);
    _cola = _cola.then((_) async {
      try {
        if (!mounted) return;
        setState(() => _dialogoObservacionAbierto = true);
        final cambio = await _pedirObservacion(fila);
        if (!mounted) return;
        setState(() => _dialogoObservacionAbierto = false);
        if (cambio == null) return;
        if (!cambio.quitar) fila.borradorObservacion = cambio.texto;
        final p = cambio.quitar
            ? await _padron.productores.quitarObservacion(fila.productor.id)
            : await _padron.productores.observar(
                fila.productor.id,
                cambio.texto,
              );
        _cambio = true;
        if (!mounted) return;
        setState(() {
          fila.productor = p;
          fila.borradorObservacion = null;
          // La observación no cambia los campos de identidad. Conservamos
          // incluso borradores que tengan un error de guardado.
        });
        mostrarExito(
          context,
          cambio.quitar
              ? 'Observación quitada'
              : 'Productor marcado como observado',
        );
      } catch (e) {
        if (mounted) mostrarError(context, e);
      } finally {
        if (mounted) {
          setState(() {
            _filaObservacion = null;
            _dialogoObservacionAbierto = false;
          });
        }
      }
    });
  }

  Future<_CambioObservacion?> _pedirObservacion(_Fila fila) {
    final formulario = GlobalKey<FormState>();
    var texto = fila.borradorObservacion ?? fila.productor.observacion ?? '';
    return showDialog<_CambioObservacion>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        icon: Icon(
          Icons.report_problem_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          fila.productor.observado
              ? 'Editar observación'
              : 'Marcar como observado',
        ),
        content: Form(
          key: formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_valor(fila.productor, 'nombres')} ${_valor(fila.productor, 'apellidos')}',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('motivo-observacion'),
                initialValue: texto,
                onChanged: (valor) => texto = valor,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la observación',
                  hintText: 'Escribí qué se debe revisar o corregir',
                  alignLabelWithHint: true,
                ),
                validator: (valor) => valor == null || valor.trim().isEmpty
                    ? 'Escribí el motivo de la observación'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          if (fila.productor.observado && context.puede('PRODUCTORES_EDITAR'))
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                const _CambioObservacion(quitar: true),
              ),
              child: const Text('Quitar observación'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formulario.currentState?.validate() != true) return;
              Navigator.pop(context, _CambioObservacion(texto: texto.trim()));
            },
            child: const Text('Guardar observación'),
          ),
        ],
      ),
    );
  }

  Future<_DecisionSie?> _mostrarResultadoSie(
    _Fila fila,
    RevisionSieProductor resultado,
  ) {
    final diferencia =
        resultado.estado == EstadoRevisionSie.requiereConfirmacion;
    final noEncontrado =
        resultado.estado == EstadoRevisionSie.aceptadaSinCoincidencia;
    String nombre(Map<String, dynamic>? datos) => [
      datos?['nombres'],
      datos?['apellidos'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' ');
    return showDialog<_DecisionSie>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          diferencia
              ? 'El nombre no coincide con SIE'
              : noEncontrado
              ? 'No encontrado en SIE'
              : 'Resultado de revisión SIE',
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CI: ${fila.productor.ci ?? ''}'),
            const SizedBox(height: 12),
            Text(resultado.mensaje),
            if (diferencia) ...[
              const SizedBox(height: 16),
              const Text('Datos actuales:'),
              SelectableText(nombre(resultado.actuales)),
              const SizedBox(height: 12),
              const Text('Datos encontrados en SIE:'),
              SelectableText(nombre(resultado.propuestos)),
            ] else ...[
              const SizedBox(height: 12),
              SelectableText(
                '${_valor(fila.productor, 'nombres')} ${_valor(fila.productor, 'apellidos')}',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              diferencia || noEncontrado ? 'Dejar pendiente' : 'Entendido',
            ),
          ),
          if (diferencia || noEncontrado)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _DecisionSie.aprobarActuales),
              child: const Text('Aprobar datos existentes'),
            ),
          if (diferencia)
            FilledButton(
              onPressed: () => Navigator.pop(context, _DecisionSie.aceptar),
              child: const Text('Aceptar sugerencia SIE'),
            ),
        ],
      ),
    );
  }

  Future<void> _salir() async {
    _ocultarGlobo();
    if (_saliendo || _creando) return;
    setState(() => _saliendo = true);
    FocusManager.instance.primaryFocus?.unfocus();
    for (final f in _filas) {
      for (final c in f.campos.values) {
        _guardar(f, c);
      }
    }
    await _cola;
    if (!mounted) return;
    final fallos = _filas.any(
      (f) =>
          f.borradorObservacion != null ||
          f.campos.values.any((c) => c.error != null),
    );
    if (fallos) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hay cambios sin guardar'),
          content: const Text(
            'Los campos o notas con error no se guardaron. Podés volver para corregirlos o salir descartando solo esos cambios. Los demás ya están guardados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver a corregir'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar y salir'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (descartar != true) {
        setState(() => _saliendo = false);
        return;
      }
    }
    if (_impresosEditados.isNotEmpty && context.puede('CARNETS_IMPRIMIR')) {
      final agregar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Agregar para reimpresión?'),
          content: Text(
            'Se modificaron ${_impresosEditados.length} productores con carnet impreso. ¿Agregarlos para reimpresión en la siguiente fase? No hace falta que haya una fase activa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar para reimpresión'),
            ),
          ],
        ),
      );
      if (agregar == true) {
        try {
          for (final id in _impresosEditados.toList()) {
            await _padron.productores.agregarReimpresionAFase(id);
            _impresosEditados.remove(id);
          }
        } catch (e) {
          if (mounted) {
            mostrarError(context, e);
            setState(() => _saliendo = false);
          }
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() => _permitirSalir = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_cambio);
    });
  }

  @override
  void dispose() {
    // Los portales se desmontan antes que esta página y retiran su propio
    // aviso. No intentar ocultar un portal que ya ha sido desmontado.
    _temporizadorGlobo?.cancel();
    _campoConGlobo = null;
    _busqueda.dispose();
    for (final f in _filas) {
      for (final c in f.campos.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: _permitirSalir,
    onPopInvokedWithResult: (salio, _) {
      if (!salio) unawaited(_salir());
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            unawaited(_salir()),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _salir),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edición de productores · ${widget.sindicato.nombre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Central: ${widget.sindicato.centralNombre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              if (_puedeCrear)
                IconButton(
                  key: const ValueKey('nuevo-productor-edicion'),
                  tooltip: 'Nuevo productor',
                  onPressed:
                      _saliendo || _ocupado || _cargando || _error != null
                      ? null
                      : _crearProductor,
                  icon: _creando
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt),
                ),
              PopupMenuButton<OrdenProductores>(
                tooltip: 'Ordenar productores',
                enabled: !_saliendo && !_ocupado,
                icon: const Icon(Icons.sort),
                onSelected: (orden) {
                  _ocultarGlobo();
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    _orden = orden;
                    _ordenar();
                  });
                },
                itemBuilder: (_) => [
                  for (final orden in OrdenProductores.values.where(
                    (o) => o != OrdenProductores.recientes,
                  ))
                    PopupMenuItem(value: orden, child: Text(orden.etiqueta)),
                ],
              ),
            ],
          ),
          body: _cargando
              ? const Cargando(mensaje: 'Cargando productores…')
              : _error != null
              ? FalloCarga(error: _error!, alReintentar: _cargar)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _saliendo
                            ? 'Esperando que terminen los guardados…'
                            : '${_busqueda.text.trim().isEmpty ? '${_filas.length}' : '${_visibles.length} de ${_filas.length}'} productores · Guardado automático al salir del campo o pulsar Enter. Lote: por ejemplo 4 o 4 B. No se modifican fotos ni clasificación.',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: TextField(
                        key: const ValueKey('buscar-edicion-productores'),
                        controller: _busqueda,
                        enabled: !_saliendo && !_ocupado,
                        onChanged: (_) => _buscar(),
                        onEditingComplete: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          labelText: 'Buscar productor',
                          hintText: 'Nombre, apellido, CI o código',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _busqueda.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: _saliendo || _ocupado
                                      ? null
                                      : () {
                                          _busqueda.clear();
                                          _buscar();
                                        },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    if (_recargaPendiente)
                      TextButton.icon(
                        onPressed: _saliendo || _ocupado
                            ? null
                            : () => _crearProductor(soloActualizar: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Actualizar lista del productor registrado',
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, limites) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: math.max(
                              limites.maxWidth,
                              852.0 +
                                  (context.puede('SIE_REVISAR') ? 160 : 0) +
                                  (_puedeObservar ? 88 : 0),
                            ),
                            height: limites.maxHeight,
                            child: Column(
                              children: [
                                _cabecera(),
                                Expanded(
                                  child: _visibles.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No se encontraron productores.',
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _visibles.length,
                                          findChildIndexCallback: (key) {
                                            if (key is! ValueKey<int>) {
                                              return null;
                                            }
                                            final indice = _visibles.indexWhere(
                                              (fila) =>
                                                  fila.productor.id ==
                                                  key.value,
                                            );
                                            return indice < 0 ? null : indice;
                                          },
                                          itemBuilder: (_, i) =>
                                              _fila(_visibles[i], i),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );

  Widget _cabecera() => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Row(
      children: [
        const SizedBox(width: 44, child: Text('N°')),
        const Expanded(flex: 3, child: Text('Nombres')),
        const Expanded(flex: 4, child: Text('Apellidos')),
        const Expanded(flex: 2, child: Text('CI')),
        const SizedBox(width: 80, child: Text('N° lote')),
        if (context.puede('SIE_REVISAR'))
          const SizedBox(width: 160, child: Text('Revisión SIE')),
        if (_puedeObservar)
          const SizedBox(width: 88, child: Text('Observación')),
      ],
    ),
  );

  Widget _fila(_Fila fila, int i) {
    final campos = fila.campos.values;
    final fallo = campos.any((c) => c.error != null);
    final pendienteSie = fila.productor.revisionSiePendiente;
    final ciDuplicada = fila.productor.ciDuplicada;
    final colores = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey(fila.productor.id),
      decoration: BoxDecoration(
        color: ciDuplicada
            ? colores.errorContainer.withValues(alpha: 0.3)
            : pendienteSie
            ? colores.surfaceContainerHighest
            : null,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    '${i + 1}',
                    style: ciDuplicada
                        ? TextStyle(color: colores.error)
                        : pendienteSie
                        ? TextStyle(color: colores.outline)
                        : null,
                  ),
                ),
              ),
              for (final (nombre, flex) in [
                ('nombres', 3),
                ('apellidos', 4),
                ('ci', 2),
              ])
                Expanded(
                  flex: flex,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _celda(fila, nombre),
                  ),
                ),
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _celda(fila, 'numeroLote'),
                ),
              ),
              if (context.puede('SIE_REVISAR')) _accionSie(fila),
              if (_puedeObservar) _accionObservacion(fila),
            ],
          ),
          if (ciDuplicada)
            Text(
              'Revisión CI · Cédula repetida: impresión bloqueada',
              style: TextStyle(color: colores.error),
            ),
          if (fallo)
            TextButton(
              onPressed: _saliendo || _ocupado
                  ? null
                  : () {
                      for (final c in campos.where((c) => c.error != null)) {
                        _guardar(fila, c);
                      }
                    },
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }

  Widget _celda(_Fila fila, String nombre) {
    final campo = fila.campos[nombre]!;
    return OverlayPortal(
      controller: campo.globo,
      overlayChildBuilder: (context) => IgnorePointer(
        child: Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: campo.enlaceGlobo,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -6),
            child: Material(
              key: ValueKey('dato-guardado-${fila.productor.id}'),
              elevation: 4,
              color: Theme.of(context).colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Dato guardado',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: campo.enlaceGlobo,
        child: Stack(
          children: [
            TextField(
              key: ValueKey('${fila.productor.id}-$nombre'),
              style: fila.productor.ciDuplicada
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : fila.productor.revisionSiePendiente
                  ? TextStyle(color: Theme.of(context).colorScheme.outline)
                  : null,
              controller: fila.campos[nombre]!.texto,
              focusNode: fila.campos[nombre]!.foco,
              enabled:
                  !_saliendo &&
                  !_ocupado &&
                  (nombre == 'numeroLote'
                      ? context.puede('NUMERO_LOTE_EDITAR') ||
                            context.puede('LOTES_EDITAR')
                      : context.puede('PRODUCTORES_EDITAR')),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  nombre == 'ci'
                      ? 20
                      : nombre == 'numeroLote'
                      ? 24
                      : 60,
                ),
              ],
              onChanged: (_) {
                _ocultarGlobo();
                setState(() {});
              },
              onEditingComplete: () {
                _guardar(fila, fila.campos[nombre]!);
                fila.campos[nombre]!.foco.unfocus();
              },
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: fila.campos[nombre]!.error,
                errorMaxLines: 4,
                hintText: nombre == 'numeroLote' ? 'Sin lote' : null,
              ),
            ),
            if (campo.pendientes > 0)
              Positioned(
                left: 8,
                right: 8,
                bottom: 0,
                child: Semantics(
                  label: 'Guardando dato',
                  child: const LinearProgressIndicator(minHeight: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _accionSie(_Fila fila) {
    final p = fila.productor;
    final revisando = _filaSie == p.id;
    final estado =
        fila.avisoSie ??
        (p.revisionSiePendiente
            ? 'Revisión pendiente'
            : switch (p.revisionSieEstado) {
                EstadoRevisionSiePersistida.verificado => 'Verificado en SIE',
                EstadoRevisionSiePersistida.corregidoSie => 'Corregido con SIE',
                EstadoRevisionSiePersistida.corregidoManual =>
                  'Corregido manualmente',
                EstadoRevisionSiePersistida.aprobadoManual =>
                  'Aprobado manualmente',
                EstadoRevisionSiePersistida.diferenciaPendiente =>
                  'Diferencia pendiente',
                EstadoRevisionSiePersistida.noEncontrado =>
                  'No encontrado en SIE',
                EstadoRevisionSiePersistida.sinCedula => 'Falta CI',
                null => 'Sin revisión SIE',
              });
    return SizedBox(
      width: 160,
      child: Column(
        children: [
          TextButton.icon(
            key: ValueKey('sie-${p.id}'),
            onPressed: _saliendo || _ocupado ? null : () => _revisarSie(fila),
            icon: revisando && !_decisionSieAbierta
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined, size: 18),
            label: Text(
              revisando
                  ? (_decisionSieAbierta ? 'Resultado SIE' : 'Revisando…')
                  : 'Revisar SIE',
            ),
          ),
          Tooltip(
            message: fila.avisoSie ?? p.revisionSieMensaje ?? estado,
            child: Text(
              estado,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    p.revisionSiePendiente ||
                        p.revisionSieBloqueaImpresion ||
                        fila.avisoSie != null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionObservacion(_Fila fila) {
    final observado = fila.productor.observado;
    final guardando =
        _filaObservacion == fila.productor.id && !_dialogoObservacionAbierto;
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          IconButton(
            key: ValueKey('observacion-${fila.productor.id}'),
            tooltip: observado ? 'Editar observación' : 'Marcar como observado',
            onPressed: _saliendo || _ocupado
                ? null
                : () => _editarObservacion(fila),
            color: observado || fila.borradorObservacion != null
                ? Theme.of(context).colorScheme.error
                : null,
            icon: guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    observado
                        ? Icons.report_problem
                        : Icons.report_problem_outlined,
                  ),
          ),
          if (observado || fila.borradorObservacion != null)
            Tooltip(
              message:
                  fila.borradorObservacion ??
                  fila.productor.observacion ??
                  'Productor observado',
              child: Text(
                fila.borradorObservacion != null
                    ? 'Nota sin guardar'
                    : 'Observado',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CambioObservacion {
  const _CambioObservacion({this.quitar = false, this.texto = ''});
  final bool quitar;
  final String texto;
}

enum _DecisionSie { aceptar, aprobarActuales }

String _valor(Productor p, String campo) => switch (campo) {
  'nombres' => p.nombresCorregidos ?? p.nombres,
  'apellidos' => p.apellidosCorregidos ?? p.apellidos ?? '',
  'ci' => p.ci ?? '',
  _ => p.numeroLote ?? '',
};

class _Fila {
  _Fila(this.productor)
    : campos = {
        for (final campo in ['nombres', 'apellidos', 'ci', 'numeroLote'])
          campo: _Campo(campo, _valor(productor, campo)),
      };
  Productor productor;
  String? avisoSie;
  String? borradorObservacion;
  final Map<String, _Campo> campos;
}

class _Campo {
  _Campo(this.nombre, this.guardado)
    : objetivo = guardado,
      texto = TextEditingController(text: guardado);
  final String nombre;
  final TextEditingController texto;
  final FocusNode foco = FocusNode();
  final OverlayPortalController globo = OverlayPortalController();
  final LayerLink enlaceGlobo = LayerLink();
  String guardado;
  String? objetivo;
  String? error;
  int pendientes = 0;
  int version = 0;
  void dispose() {
    texto.dispose();
    foco.dispose();
  }
}
