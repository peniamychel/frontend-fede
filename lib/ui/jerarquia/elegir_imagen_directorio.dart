import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Ofrece la misma elección de origen usada para las fotos de productores.
Future<PlatformFile?> elegirImagenDirectorio(BuildContext context) async {
  final origen = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            subtitle: const Text('Abrir la cámara del dispositivo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            subtitle: const Text('Seleccionar una imagen guardada'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (origen == null || !context.mounted) return null;

  final archivo = await ImagePicker().pickImage(
    source: origen,
    preferredCameraDevice: CameraDevice.rear,
    requestFullMetadata: false,
  );
  if (archivo == null) return null;
  final bytes = await archivo.readAsBytes();
  return PlatformFile(name: archivo.name, size: bytes.length, bytes: bytes);
}
