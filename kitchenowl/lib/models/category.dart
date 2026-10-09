import 'model.dart';

class Category extends Model {
  final int? id;
  final String name;
  final int ordering;

  const Category({this.id, this.name = "", this.ordering = 0});

  factory Category.fromJson(Map<String, dynamic> map) => Category(
        id: map['id'],
        name: map['name'] ?? "",
        ordering: map['ordering'] ?? -1,
      );

  @override
  List<Object?> get props => [id, name, ordering];

  @override
  Map<String, dynamic> toJson() => {
        "name": name,
        "ordering": ordering,
      };

  @override
  Map<String, dynamic> toJsonWithId() => toJson()
    ..addAll({
      "id": id,
    });

  Category copyWith({String? name, int? ordering}) => Category(
        id: id,
        name: name ?? this.name,
        ordering: ordering ?? this.ordering,
      );
}

/// Stesso reparto anche quando uno dei due si porta dietro un ordering vecchio
/// o non ha ancora un id perché creato senza rete (features/005, plan
/// "Confronto fra reparti"): per id se entrambi lo hanno, altrimenti per nome.
/// null è "Uncategorized".
bool isSameCategory(Category? a, Category? b) {
  if (a == null || b == null) return a == b;
  final aId = a.id;
  final bId = b.id;
  if (aId != null && bId != null) return aId == bId;
  return a.name.toLowerCase() == b.name.toLowerCase();
}
