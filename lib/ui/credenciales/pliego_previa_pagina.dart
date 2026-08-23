import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/descargas.dart';
import '../widgets/estados.dart';
import 'credencial_previa_pagina.dart';

/// Vista previa del pliego: las credenciales de todo un sindicato.
///
/// El pliego es todo o nada. Se imprime a doble cara y se recorta, así que una
/// tarjeta incompleta en el medio obliga a rehacer la hoja entera. Por eso acá
/// se revisa a todos antes y no se genera hasta que no falte nada.
///
/// Lo del sindicato va separado de lo de cada persona a propósito: si falta la
/// firma de un dirigente no le falta a un productor, le falta a los cien, y
/// arreglarlo una vez arregla el pliego entero.
class PliegoPreviaPagina extends StatefulWidget {
  const PliegoPreviaPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<PliegoPreviaPagina> createState() => _PliegoPreviaPaginaState();
}

class _PliegoPreviaPaginaState extends State<PliegoPreviaPagina> {
  late Future<PliegoPrevio> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).sindicatos;
    // Con llaves y no con flecha: la flecha devolvería el Future de la
    // asignación, y setState rechaza un callback que devuelva un Future.
    setState(() {
      _futuro = repo.previaCredenciales(widget.sindicato.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Credenciales de ${widget.sindicato.nombre}'),
        actions: [
          IconButton(
            tooltip: 'Volver a revisar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<PliegoPrevio>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, previo) => _Contenido(
          previo: previo,
          sindicato: widget.sindicato,
          alRevisar: _recargar,
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.previo,
    required this.sindicato,
    required this.alRevisar,
  });

  final PliegoPrevio previo;
  final Sindicato sindicato;
  final VoidCallback alRevisar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (previo.productores == 0) {
      return const SinResultados(
        icono: Icons.badge_outlined,
        mensaje: 'Este sindicato no tiene productores.',
        detalle: 'No hay credenciales que emitir.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: previo.completa
              ? tema.colorScheme.primaryContainer
              : tema.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  previo.completa
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: previo.completa
                      ? tema.colorScheme.onPrimaryContainer
                      : tema.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    previo.completa
                        ? '${previo.productores} credenciales listas para '
                              'imprimir.'
                        : _resumenDeLoQueFalta(),
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: previo.completa
                          ? tema.colorScheme.onPrimaryContainer
                          : tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (previo.faltantesDelSindicato.isNotEmpty) ...[
          Text(
            'Le falta al sindicato',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Esto le falta a todas las credenciales por igual. Arreglarlo una '
            'vez destraba el pliego entero.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          for (final falta in previo.faltantesDelSindicato)
            _FilaFalta(falta: falta),
          const SizedBox(height: 20),
        ],
        if (previo.incompletos.isNotEmpty) ...[
          Text(
            previo.incompletos.length == 1
                ? 'Un productor con datos incompletos'
                : '${previo.incompletos.length} productores con datos '
                      'incompletos',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final quien in previo.incompletos)
            _FilaProductor(quien: quien, alRevisar: alRevisar),
          const SizedBox(height: 20),
        ],
        FilledButton.icon(
          onPressed: previo.completa
              ? () => descargarCredencialesSindicato(context, sindicato)
              : null,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            previo.completa
                ? 'Generar el pliego (${previo.productores})'
                : 'Generar el pliego',
          ),
        ),
      ],
    );
  }

  String _resumenDeLoQueFalta() {
    final partes = <String>[];
    if (previo.faltantesDelSindicato.isNotEmpty) {
      partes.add(
        previo.faltantesDelSindicato.length == 1
            ? 'un dato del sindicato'
            : '${previo.faltantesDelSindicato.length} datos del sindicato',
      );
    }
    if (previo.incompletos.isNotEmpty) {
      partes.add(
        previo.incompletos.length == 1
            ? 'un productor'
            : '${previo.incompletos.length} productores',
      );
    }
    return 'Falta completar ${partes.join(' y ')}.';
  }
}

class _FilaFalta extends StatelessWidget {
  const _FilaFalta({required this.falta});

  final Faltante falta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: tema.colorScheme.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  falta.campo,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(falta.detalle, style: tema.textTheme.bodySmall),
                Text(
                  falta.donde,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaProductor extends StatelessWidget {
  const _FilaProductor({required this.quien, required this.alRevisar});

  final ProductorIncompleto quien;
  final VoidCallback alRevisar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.person_outline, color: tema.colorScheme.error),
      title: Text(quien.nombreCompleto),
      subtitle: Text(
        quien.faltantes.map((f) => f.campo).join(' · '),
        style: tema.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      // Se entra a su vista previa: ahí se ve la tarjeta y el detalle de lo
      // que le falta, con dónde cargarlo.
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CredencialPreviaPagina(
              productorId: quien.productorId,
              nombre: quien.nombreCompleto,
            ),
          ),
        );
        alRevisar();
      },
    );
  }
}
