import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/descargas.dart';
import '../widgets/estados.dart';
import 'tarjeta_previa.dart';

/// Vista previa de la credencial antes de imprimirla.
///
/// La credencial sale plastificada y se reparte. Descubrir ahí que falta la
/// foto o la firma de un dirigente significa rehacerla, así que primero se
/// muestra cómo va a quedar y qué le falta, y el PDF no se genera hasta que
/// esté completa.
///
/// El botón deshabilitado no alcanza como explicación: al lado va la lista de
/// lo que falta, y cada línea dice en qué pantalla se carga.
class CredencialPreviaPagina extends StatefulWidget {
  const CredencialPreviaPagina({
    super.key,
    required this.productorId,
    required this.nombre,
  });

  final int productorId;
  final String nombre;

  @override
  State<CredencialPreviaPagina> createState() => _CredencialPreviaPaginaState();
}

class _CredencialPreviaPaginaState extends State<CredencialPreviaPagina> {
  late Future<(CredencialPrevia, DisenoCredencial)> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final padron = PadronScope.of(context);
    // Con llaves y no con flecha: la flecha devolvería el Future de la
    // asignación, y setState rechaza un callback que devuelva un Future.
    setState(() {
      _futuro = _cargarTodo(padron);
    });
  }

  Future<(CredencialPrevia, DisenoCredencial)> _cargarTodo(
    Padron padron,
  ) async {
    final previa = await padron.productores.previaCredencial(
      widget.productorId,
    );
    try {
      final editor = await padron.disenoCredencial.obtener();
      final diseno = editor.diseno.elementos.isEmpty
          ? DisenoCredencial.predeterminado()
          : editor.diseno;
      return (previa, diseno);
    } catch (_) {
      // Mantiene operativa la previa si se abre contra un backend anterior.
      return (previa, DisenoCredencial.predeterminado());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa de la credencial'),
        actions: [
          IconButton(
            tooltip: 'Volver a revisar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<(CredencialPrevia, DisenoCredencial)>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, datos) => _Contenido(
          previa: datos.$1,
          diseno: datos.$2,
          alImprimir: () => descargarCredencialProductor(
            context,
            datos.$1.productorId,
            datos.$1.nombreCompleto,
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.previa,
    required this.diseno,
    required this.alImprimir,
  });

  final CredencialPrevia previa;
  final DisenoCredencial diseno;
  final VoidCallback alImprimir;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        // En pantalla ancha las tarjetas van al lado del informe; en angosta,
        // una debajo de la otra.
        final ancho = restricciones.maxWidth;
        final enColumna = ancho < 900;

        final tarjetas = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Rotulo('Anverso'),
            const SizedBox(height: 8),
            TarjetaPrevia(previa: previa, reverso: false, diseno: diseno),
            const SizedBox(height: 24),
            const _Rotulo('Reverso'),
            const SizedBox(height: 8),
            TarjetaPrevia(previa: previa, reverso: true, diseno: diseno),
          ],
        );

        final informe = _Informe(previa: previa, alImprimir: alImprimir);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: enColumna
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [tarjetas, const SizedBox(height: 28), informe],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tarjetas,
                    const SizedBox(width: 32),
                    Expanded(child: informe),
                  ],
                ),
        );
      },
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Text(
      texto.toUpperCase(),
      style: tema.textTheme.labelSmall?.copyWith(
        color: tema.colorScheme.outline,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// El veredicto y, si hace falta, qué completar.
class _Informe extends StatelessWidget {
  const _Informe({required this.previa, required this.alImprimir});

  final CredencialPrevia previa;
  final VoidCallback alImprimir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lista = previa.faltantes;

    final bloqueo = previa.bloqueo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El bloqueo va primero y aparte: no es un dato que falte, es una
        // decisión de asamblea. Mezclarlo con los faltantes mandaría a alguien
        // a buscar una foto que está cargada.
        if (bloqueo != null) ...[
          Card(
            margin: EdgeInsets.zero,
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.block,
                        color: tema.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bloqueo.titulo,
                          style: tema.textTheme.titleMedium?.copyWith(
                            color: tema.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bloqueo.motivo,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Decidido en «${bloqueo.reunion}». ${bloqueo.comoSeLevanta}',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          margin: EdgeInsets.zero,
          color: previa.completa
              ? tema.colorScheme.primaryContainer
              : tema.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  previa.completa
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: previa.completa
                      ? tema.colorScheme.onPrimaryContainer
                      : tema.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    previa.completa
                        ? 'Lista para imprimir.'
                        : lista.isEmpty
                        ? 'Los datos están completos, pero está bloqueada.'
                        : lista.length == 1
                        ? 'Falta un dato para poder imprimirla.'
                        : 'Faltan ${lista.length} datos para poder '
                              'imprimirla.',
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: previa.completa
                          ? tema.colorScheme.onPrimaryContainer
                          : tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (lista.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final falta in lista) _FilaFaltante(falta: falta),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: previa.completa ? alImprimir : null,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Generar el PDF'),
        ),
        if (!previa.completa) ...[
          const SizedBox(height: 8),
          Text(
            'Completá lo de arriba y volvé a revisar. El servidor tampoco lo '
            'emite mientras falte algo.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilaFaltante extends StatelessWidget {
  const _FilaFaltante({required this.falta});

  final Faltante falta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: tema.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        falta.donde,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
