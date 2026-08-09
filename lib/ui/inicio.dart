import 'package:flutter/material.dart';

import 'calidad/calidad_pagina.dart';
import 'jerarquia/jerarquia_pagina.dart';
import 'observaciones/observaciones_pagina.dart';
import 'productores/productores_pagina.dart';
import 'reuniones/reuniones_pagina.dart';

/// Armazón de la app con navegación adaptativa.
///
/// La misma app corre en escritorio, web y teléfono, así que la navegación
/// cambia de forma según el ancho disponible: barra inferior en móvil, riel
/// lateral en tablet, y riel extendido con etiquetas en escritorio.
class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int _seccion = 0;

  static const List<_Destino> _destinos = [
    _Destino('Productores', Icons.people_outline, Icons.people),
    _Destino('Jerarquía', Icons.account_tree_outlined, Icons.account_tree),
    _Destino('Reuniones', Icons.event_note_outlined, Icons.event_note),
    _Destino('Observaciones', Icons.flag_outlined, Icons.flag),
    _Destino('Calidad', Icons.fact_check_outlined, Icons.fact_check),
  ];

  @override
  Widget build(BuildContext context) {
    // IndexedStack y no un switch: conserva el scroll y los filtros de cada
    // sección al ir y volver.
    final contenido = IndexedStack(
      index: _seccion,
      children: const [
        ProductoresPagina(),
        JerarquiaPagina(),
        ReunionesPagina(),
        ObservacionesPagina(),
        CalidadPagina(),
      ],
    );

    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth;

        if (ancho < 700) {
          return Scaffold(
            body: contenido,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _seccion,
              onDestinationSelected: _ir,
              destinations: [
                for (final d in _destinos)
                  NavigationDestination(
                    icon: Icon(d.icono),
                    selectedIcon: Icon(d.iconoActivo),
                    label: d.etiqueta,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _seccion,
                onDestinationSelected: _ir,
                extended: ancho >= 1100,
                labelType: ancho >= 1100
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: ancho >= 1100
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.badge_outlined),
                            SizedBox(width: 12),
                            Text('Padrón FEDERA',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                          ],
                        ),
                      )
                    : const SizedBox(height: 8),
                destinations: [
                  for (final d in _destinos)
                    NavigationRailDestination(
                      icon: Icon(d.icono),
                      selectedIcon: Icon(d.iconoActivo),
                      label: Text(d.etiqueta),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: contenido),
            ],
          ),
        );
      },
    );
  }

  void _ir(int indice) => setState(() => _seccion = indice);
}

class _Destino {
  const _Destino(this.etiqueta, this.icono, this.iconoActivo);

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
}
