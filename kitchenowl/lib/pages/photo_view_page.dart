import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PhotoViewPage extends StatelessWidget {
  final ImageProvider imageProvider;
  final Object? heroTag;
  final String? title;

  /// Se c'è, in alto compare il cestino: dopo la conferma la foto viene
  /// tolta e la pagina si chiude. Lo usano le foto allegate a un articolo.
  final Future<void> Function()? onDelete;

  const PhotoViewPage({
    super.key,
    required this.imageProvider,
    this.title,
    this.heroTag,
    this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminare la foto?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Elimina"),
          ),
        ],
      ),
    );
    if (isConfirmed != true || !context.mounted) return;
    Navigator.of(context).pop();
    await onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        actions: [
          if (onDelete != null)
            IconButton(
              tooltip: "Elimina",
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: Center(
        child: PhotoView(
          imageProvider: imageProvider,
          maxScale: PhotoViewComputedScale.contained * 4,
          minScale: PhotoViewComputedScale.contained,
          heroAttributes:
              heroTag != null ? PhotoViewHeroAttributes(tag: heroTag!) : null,
          backgroundDecoration:
              BoxDecoration(color: Theme.of(context).colorScheme.surface),
        ),
      ),
    );
  }
}
