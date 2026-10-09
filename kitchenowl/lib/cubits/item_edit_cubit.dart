import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_attachment.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/transaction_handler.dart';
import 'package:kitchenowl/services/transactions/item.dart';
import 'package:kitchenowl/services/transactions/shoppinglist.dart';

class ItemEditCubit<T extends Item> extends Cubit<ItemEditState> {
  final Household? household;
  final T _item;
  final ShoppingList? shoppingList;

  T get item {
    if (_item is ItemWithDescription) {
      return (((_item as ItemWithDescription).copyWith(
        description: state.description,
        category: Nullable(state.category),
        icon: Nullable(state.icon),
        name: state.name,
      )) as T);
    }

    return _item.copyWith(
      category: Nullable(state.category),
      icon: Nullable(state.icon),
      name: state.name,
    ) as T;
  }

  ItemEditCubit({required T item, required this.household, this.shoppingList})
      : _item = item,
        super(ItemEditState(
          description: (item is ItemWithDescription) ? item.description : '',
          icon: item.icon,
          name: item.name,
          category: item.category,
          attachments: item.attachments ?? const [],
        )) {
    refresh();
  }

  Future<void> refresh() async {
    if (_item.id != null) {
      final recipes = (await TransactionHandler.getInstance()
          .runTransaction(TransactionItemGetRecipes(
        household: household,
        item: _item,
      )))
        ..sort(((a, b) {
          if (a.isPlanned == b.isPlanned) {
            return 0;
          } else if (b.isPlanned) {
            return 1;
          } else {
            return -1;
          }
        }));
      // Ricarica anche gli allegati: l'endpoint /item/<id> ora risponde "full".
      final fresh = await ApiService.getInstance().getItem(_item);
      emit(state.copyWith(
        recipes: recipes,
        attachments: fresh?.attachments ?? state.attachments,
      ));
    }
  }

  // Switch della modalita' modifica (mostra/nasconde drag handle e cestini).
  void toggleEditing() {
    emit(state.copyWith(isEditing: !state.isEditing));
  }

  // Carica un file binario via /api/upload (foto/PDF) e lo aggancia all'item.
  Future<bool> addAttachmentBytes(
    NamedByteArray file,
    ItemAttachmentKind kind, {
    String? label,
  }) async {
    if (_item.id == null) return false;
    final filename = await ApiService.getInstance().uploadBytes(file);
    if (filename == null) return false;

    final created = await ApiService.getInstance().addItemAttachment(
      _item,
      filename,
      kind,
      label: label,
    );
    if (created == null) return false;

    emit(state.copyWith(
      attachments: List<ItemAttachment>.from(state.attachments)..add(created),
    ));
    return true;
  }

  Future<bool> deleteAttachment(ItemAttachment attachment) async {
    if (_item.id == null) return false;
    final ok = await ApiService.getInstance().deleteItemAttachment(
      _item,
      attachment,
    );
    if (!ok) return false;
    emit(state.copyWith(
      attachments:
          state.attachments.where((a) => a.id != attachment.id).toList(),
    ));
    return true;
  }

  Future<bool> renameAttachment(
    ItemAttachment attachment,
    String? newLabel,
  ) async {
    if (_item.id == null) return false;
    final updated = await ApiService.getInstance().renameItemAttachment(
      _item,
      attachment,
      newLabel,
    );
    if (updated == null) return false;
    emit(state.copyWith(
      attachments: state.attachments
          .map((a) => a.id == updated.id ? updated : a)
          .toList(),
    ));
    return true;
  }

  // Riordina gli allegati di un certo "kind" (foto o PDF).
  // L'ordine fornito determina la sequenza nella griglia/lista; per le foto
  // la prima diventa la copertina mostrata in lista spesa.
  Future<void> reorderAttachments(
    ItemAttachmentKind kind,
    List<ItemAttachment> newOrder,
  ) async {
    if (_item.id == null) return;
    // Aggiornamento ottimistico del local state prima della chiamata di rete:
    // permette al drag&drop di sembrare istantaneo e poi rilancia la lista
    // se il server risponde con un ordine diverso.
    final others =
        state.attachments.where((a) => a.kind != kind).toList(growable: false);
    emit(state.copyWith(
      attachments: [
        ...others,
        for (int i = 0; i < newOrder.length; i++)
          newOrder[i].copyWith(ordering: i),
      ],
    ));

    final result = await ApiService.getInstance().reorderItemAttachments(
      _item,
      kind,
      newOrder.map((a) => a.id).toList(),
    );
    if (result != null) {
      emit(state.copyWith(attachments: [...others, ...result]));
    }
  }

  Future<void> saveItem() async {
    if (shoppingList != null && state.hasChangedDescription(_item)) {
      await TransactionHandler.getInstance()
          .runTransaction(TransactionShoppingListUpdateItem(
        household: household!,
        shoppinglist: shoppingList!,
        item: _item,
        description: state.description,
      ));
    }
    if (state.hasChangedItem(_item)) {
      if (item.id != null) {
        await TransactionHandler.getInstance()
            .runTransaction(TransactionItemUpdate(
          item: item,
        ));
      } else if (household != null) {
        await TransactionHandler.getInstance()
            .runTransaction(TransactionItemAdd(
          household: household!,
          item: item,
        ));
      }
    }
  }

  Future<bool> deleteItem() async {
    if (_item.id != null) {
      return ApiService.getInstance().deleteItem(_item);
    }

    return false;
  }

  Future<bool> mergeItem(Item other) async {
    if (_item.id != null &&
        other.id != null &&
        await ApiService.getInstance().mergeItems(_item, other)) {
      emit(state.copyWith(hasMerged: true));
      return true;
    }

    return false;
  }

  void setName(String name) {
    emit(state.copyWith(name: name));
  }

  void setDescription(String desc) {
    emit(state.copyWith(description: desc));
  }

  void setCategory(Category? category) {
    emit(state.copyWith(
      category: Nullable(category),
    ));
  }

  void setIcon(String? icon) {
    emit(state.copyWith(
      icon: Nullable(icon),
    ));
  }
}

class ItemEditState extends Equatable {
  final String name;
  final String description;
  final String? icon;
  final List<Recipe> recipes;
  final Category? category;
  final bool hasMerged;
  // Tutti gli allegati dell'item, ordinati come arrivano dal backend (foto e PDF
  // mescolati ma comunque per "ordering" crescente, raggruppabili per "kind"
  // dalla UI).
  final List<ItemAttachment> attachments;
  // Modalita' modifica attiva: la UI mostra maniglie di drag e cestini.
  final bool isEditing;

  const ItemEditState({
    this.name = "",
    this.description = "",
    this.icon,
    this.recipes = const [],
    this.category,
    this.hasMerged = false,
    this.attachments = const [],
    this.isEditing = false,
  });

  // Comodo: foto ordinate per "ordering" (la prima e' la copertina).
  List<ItemAttachment> get photos =>
      attachments.where((a) => a.kind == ItemAttachmentKind.photo).toList()
        ..sort((a, b) => a.ordering.compareTo(b.ordering));

  // Comodo: PDF ordinati per "ordering".
  List<ItemAttachment> get pdfs =>
      attachments.where((a) => a.kind == ItemAttachmentKind.pdf).toList()
        ..sort((a, b) => a.ordering.compareTo(b.ordering));

  ItemEditState copyWith({
    String? name,
    String? description,
    Nullable<String>? icon,
    List<Recipe>? recipes,
    Nullable<Category>? category,
    bool? hasMerged,
    List<ItemAttachment>? attachments,
    bool? isEditing,
  }) =>
      ItemEditState(
        name: name ?? this.name,
        description: description ?? this.description,
        icon: (icon ?? Nullable(this.icon)).value,
        recipes: recipes ?? this.recipes,
        category: (category ?? Nullable(this.category)).value,
        hasMerged: hasMerged ?? this.hasMerged,
        attachments: attachments ?? this.attachments,
        isEditing: isEditing ?? this.isEditing,
      );

  @override
  List<Object?> get props => [
        name,
        description,
        icon,
        recipes,
        category,
        hasMerged,
        attachments,
        isEditing,
      ];

  bool hasChanged(Item comparedTo) =>
      hasChangedItem(comparedTo) || hasChangedDescription(comparedTo);

  bool hasChangedItem(Item comparedTo) =>
      comparedTo.category != category ||
      comparedTo.icon != icon ||
      comparedTo.name != name ||
      hasMerged;

  bool hasChangedDescription(Item comparedTo) {
    return comparedTo is ItemWithDescription &&
        (comparedTo).description != description;
  }
}
