import 'package:flutter/material.dart';
import '../sesion_scope.dart';

class CuentaPagina extends StatelessWidget {
  const CuentaPagina({super.key});
  @override Widget build(BuildContext context) {
    final controlador=SesionScope.of(context); final sesion=controlador.sesion!;
    return Scaffold(appBar:AppBar(title:const Text('Mi acceso')),body:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:520),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const CircleAvatar(radius:34,child:Icon(Icons.person_outline,size:38)),const SizedBox(height:16),
        SelectableText(sesion.nombreCompleto,style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
        const SizedBox(height:8),Text(sesion.roles.join(', ')),const SizedBox(height:24),
        FilledButton.tonalIcon(onPressed:()=>controlador.cerrar(),icon:const Icon(Icons.logout),label:const Text('Cerrar sesión')),
      ]))))));
  }
}
