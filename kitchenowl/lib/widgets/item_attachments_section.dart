// Sezione "Allegati" della pagina dettaglio di un Item.
//
// Mostra:
//   - Griglia 3 colonne delle foto, con tap = lightbox a schermo intero.
//     In modalita' modifica si possono trascinare per riordinare (la prima e'
//     la copertina mostrata nella lista spesa) e cancellare con il cestino.
//   - Lista compatta dei PDF: tap = scarica e apre col viewer del sistema,
//     icona matita = rinomina, in modalita' modifica appare il cestino.
//
// La modalita' modifica si attiva con il pulsante "Modifica" in app bar
// (gestito dalla pagina contenitore) e cambia "isEditing" nel cubit. Una
// foto si elimina anche dalla lightbox, col cestino in alto: senza passare
// dalla modalita' modifica non si trovava (bug del 2026-10-09). Mentre una
// foto o un PDF si carica compare una barra di avanzamento.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/item_edit_cubit.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_attachment.dart';
import 'package:kitchenowl/pages/photo_view_page.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/widgets/image_provider.dart';
import 'package:kitchenowl/widgets/select_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reorderables/reorderables.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:universal_html/html.dart' as html;

class ItemAttachmentsSection extends StatelessWidget {
  final Item item;

  const ItemAttachmentsSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ItemEditCubit, ItemEditState>(
      buildWhen: (prev, curr) =>
          prev.attachments != curr.attachments ||
          prev.isEditing != curr.isEditing ||
          prev.isUploading != curr.isUploading,
      builder: (context, state) {
        final cubit = context.read<ItemEditCubit>();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 32),
              _SectionHeader(
                title: "Foto",
                count: state.photos.length,
                cap: 20,
              ),
              const SizedBox(height: 8),
              _PhotoGrid(
                photos: state.photos,
                isEditing: state.isEditing,
                onOpen: (att) => _openLightbox(context, cubit, att),
                onDelete: (att) => cubit.deleteAttachment(att),
                onReorder: (newOrder) => cubit.reorderAttachments(
                  ItemAttachmentKind.photo,
                  newOrder,
                ),
              ),
              if (state.isUploading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (state.photos.length < 20 && !state.isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: () => _addPhoto(context, cubit),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text("Aggiungi foto"),
                  ),
                ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: "Documenti",
                count: state.pdfs.length,
                cap: 10,
              ),
              const SizedBox(height: 8),
              _PdfList(
                pdfs: state.pdfs,
                isEditing: state.isEditing,
                onOpen: (att) => _openPdf(context, att),
                onRename: (att) => _renamePdf(context, cubit, att),
                onDelete: (att) => cubit.deleteAttachment(att),
              ),
              if (state.pdfs.length < 10 && !state.isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: () => _addPdf(context, cubit),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text("Aggiungi PDF"),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---- Foto ----------------------------------------------------------------

  Future<void> _addPhoto(BuildContext context, ItemEditCubit cubit) async {
    final file = await selectFile(
      context: context,
      title: "Aggiungi foto",
    );
    if (file == null || file.isEmpty) return;
    await cubit.addAttachmentBytes(file, ItemAttachmentKind.photo);
  }

  void _openLightbox(
    BuildContext context,
    ItemEditCubit cubit,
    ItemAttachment att,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewPage(
          imageProvider: getImageProvider(context, att.filename),
          heroTag: 'item_attachment_${att.id}',
          onDelete: () => cubit.deleteAttachment(att),
        ),
      ),
    );
  }

  // ---- PDF -----------------------------------------------------------------

  Future<void> _addPdf(BuildContext context, ItemEditCubit cubit) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;
    final bytes = NamedByteArray(picked.name, picked.bytes!);
    // Etichetta di default = nome del file caricato (rinominabile dopo).
    await cubit.addAttachmentBytes(
      bytes,
      ItemAttachmentKind.pdf,
      label: picked.name,
    );
  }

  Future<void> _renamePdf(
    BuildContext context,
    ItemEditCubit cubit,
    ItemAttachment att,
  ) async {
    final controller = TextEditingController(text: att.label ?? "");
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rinomina documento"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Nome"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text("Salva"),
          ),
        ],
      ),
    );
    if (newLabel != null && newLabel.isNotEmpty) {
      await cubit.renameAttachment(att, newLabel);
    }
  }

  Future<void> _openPdf(BuildContext context, ItemAttachment att) async {
    // Scarica i bytes con autenticazione (gli upload sono protetti) e poi:
    //   - su web: crea un blob URL e apre in nuova scheda
    //   - su mobile/desktop: salva in temp e condivide con app esterna
    final res = await ApiService.getInstance().get('/upload/${att.filename}');
    if (res.statusCode != 200) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossibile aprire il PDF")),
        );
      }
      return;
    }

    final filename = att.label ?? att.filename;
    if (kIsWeb) {
      final blob = html.Blob([res.bodyBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      // Il browser tiene il blob vivo per la nuova scheda; lo revokiamo poi.
      Future.delayed(const Duration(seconds: 30), () {
        html.Url.revokeObjectUrl(url);
      });
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(Uint8List.fromList(res.bodyBytes));
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await share_plus.Share.shareXFiles(
      [share_plus.XFile(file.path, name: filename)],
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final int cap;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 8),
        Text(
          "$count / $cap",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<ItemAttachment> photos;
  final bool isEditing;
  final void Function(ItemAttachment) onOpen;
  final void Function(ItemAttachment) onDelete;
  final void Function(List<ItemAttachment>) onReorder;

  const _PhotoGrid({
    required this.photos,
    required this.isEditing,
    required this.onOpen,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Nessuna foto",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    // 3 colonne con padding orizzontale 16+16 = 32 e gap 8+8 = 16: tile = (w-48)/3
    final tile = ((width - 48) / 3).clamp(80.0, 200.0);

    final cells = [
      for (final att in photos)
        SizedBox(
          key: ValueKey(att.id),
          width: tile,
          height: tile,
          child: _PhotoCell(
            attachment: att,
            isEditing: isEditing,
            onTap: () => onOpen(att),
            onDelete: () => onDelete(att),
          ),
        ),
    ];

    if (!isEditing) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cells,
      );
    }
    return ReorderableWrap(
      spacing: 8,
      runSpacing: 8,
      needsLongPressDraggable: true,
      onReorder: (oldIndex, newIndex) {
        final list = List<ItemAttachment>.from(photos);
        final moved = list.removeAt(oldIndex);
        list.insert(newIndex, moved);
        onReorder(list);
      },
      children: cells,
    );
  }
}

class _PhotoCell extends StatelessWidget {
  final ItemAttachment attachment;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoCell({
    required this.attachment,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final image = Hero(
      tag: 'item_attachment_${attachment.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (attachment.blurHash != null)
              BlurHash(hash: attachment.blurHash!),
            Image(
              image: getImageProvider(
                context,
                attachment.filename,
                maxWidth: 400,
                maxHeight: 400,
              ),
              fit: BoxFit.cover,
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            child: image,
          ),
        ),
        if (isEditing)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.red.shade700,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PdfList extends StatelessWidget {
  final List<ItemAttachment> pdfs;
  final bool isEditing;
  final void Function(ItemAttachment) onOpen;
  final void Function(ItemAttachment) onRename;
  final void Function(ItemAttachment) onDelete;

  const _PdfList({
    required this.pdfs,
    required this.isEditing,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (pdfs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Nessun documento",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      children: [
        for (final att in pdfs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(att.label ?? att.filename, maxLines: 2),
            onTap: () => onOpen(att),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "Rinomina",
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onRename(att),
                ),
                if (isEditing)
                  IconButton(
                    tooltip: "Elimina",
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => onDelete(att),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
