// Modello dei file allegati a un Item: foto o PDF.
// Le foto sono mostrate in griglia (la prima e' la copertina nella lista spesa).
// I PDF sono in lista compatta sotto la griglia, con etichetta rinominabile.
import 'package:kitchenowl/models/model.dart';

enum ItemAttachmentKind {
  photo,
  pdf;

  String toJson() => name;

  static ItemAttachmentKind? tryParse(String? raw) {
    for (final k in ItemAttachmentKind.values) {
      if (k.name == raw) return k;
    }
    return null;
  }
}

class ItemAttachment extends Model {
  final int id;
  // Filename del file caricato (relativo a /api/upload/<filename>).
  final String filename;
  // Tipo: foto o pdf — guida la UI di rendering.
  final ItemAttachmentKind kind;
  // Posizione nella griglia/lista. La prima foto (ordering minore) e' la copertina.
  final int ordering;
  // Etichetta leggibile dei PDF (null per le foto).
  final String? label;
  // Hash di sfocatura (blurhash) per il placeholder durante il caricamento.
  final String? blurHash;

  const ItemAttachment({
    required this.id,
    required this.filename,
    required this.kind,
    required this.ordering,
    this.label,
    this.blurHash,
  });

  factory ItemAttachment.fromJson(Map<String, dynamic> map) => ItemAttachment(
        id: map['id'],
        filename: map['file_filename'],
        kind: ItemAttachmentKind.tryParse(map['kind']) ??
            ItemAttachmentKind.photo,
        ordering: map['ordering'] ?? 0,
        label: map['label'],
        blurHash: map['blur_hash'],
      );

  bool get isPhoto => kind == ItemAttachmentKind.photo;
  bool get isPdf => kind == ItemAttachmentKind.pdf;

  ItemAttachment copyWith({
    int? ordering,
    String? label,
  }) =>
      ItemAttachment(
        id: id,
        filename: filename,
        kind: kind,
        ordering: ordering ?? this.ordering,
        label: label ?? this.label,
        blurHash: blurHash,
      );

  @override
  List<Object?> get props => [id, filename, kind, ordering, label, blurHash];

  @override
  Map<String, dynamic> toJson() => {
        "id": id,
        "file_filename": filename,
        "kind": kind.toJson(),
        "ordering": ordering,
        "label": label,
        "blur_hash": blurHash,
      };
}
