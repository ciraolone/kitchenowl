import 'package:device_info_plus/device_info_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/config.dart';
import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/services/storage/storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Impostazioni dell'app salvate sul telefono. Tema, colori e "ricorda
/// l'ultima lista" valgono per tutta l'app; quelle della lista della spesa
/// (vista, dimensioni, stile, icone, tocco, recenti, schermo acceso,
/// ordinamento) valgono per il negozio aperto (fork di Andrea, feature 007):
/// si salvano con chiave `<nome>@<householdId>` e le carica selectStore, che
/// chiama ShoppinglistCubit all'apertura di ogni negozio. La prima volta
/// selectStore copia sul negozio aperto le chiavi globali di prima e le
/// cancella, una volta sola (segnalino storeSettingsMigrated): se lo facesse
/// di nuovo, un negozio nuovo erediterebbe le impostazioni del primo.
class SettingsCubit extends Cubit<SettingsState> {
  static const _storeIntSettings = ['gridSize', 'listStyle', 'recentItemsCount'];
  static const _storeBoolSettings = [
    'shoppingListListView',
    'shoppingListTapToRemove',
    'recentItemsCategorize',
    'shoppingListKeepAwake',
    'shoppingListHideIcons',
  ];

  int? _storeId;
  int? _loadingStoreId;
  Future<void>? _storeLoading;

  SettingsCubit() : super(const SettingsState()) {
    load();
  }

  Future<void> load() async {
    final themeModeIndex =
        PreferenceStorage.getInstance().readInt(key: 'themeMode');
    final dynamicAccentColor =
        PreferenceStorage.getInstance().readBool(key: 'dynamicAccentColor');
    final accentColor =
        PreferenceStorage.getInstance().readInt(key: 'accentColor');
    final restoreLastShoppingList = PreferenceStorage.getInstance()
        .readBool(key: 'restoreLastShoppingList');

    Config.deviceInfo = DeviceInfoPlugin().deviceInfo;
    Config.packageInfo = PackageInfo.fromPlatform();

    ThemeMode themeMode = ThemeMode.system;
    if (await themeModeIndex != null) {
      themeMode = ThemeMode.values[(await themeModeIndex)!];
    }

    // copyWith e non uno stato nuovo: selectStore può aver già caricato le
    // impostazioni del negozio
    emit(state.copyWith(
      themeMode: themeMode,
      dynamicAccentColor: await dynamicAccentColor ?? false,
      accentColor: Nullable(
          (await accentColor) != null ? Color((await accentColor)!) : null),
      restoreLastShoppingList: await restoreLastShoppingList ?? false,
    ));
  }

  /// Carica le impostazioni della lista del negozio householdId. Più
  /// chiamate per lo stesso negozio condividono lo stesso caricamento.
  Future<void> selectStore(int householdId) {
    final loading = _storeLoading;
    if (householdId == _loadingStoreId && loading != null) return loading;
    _loadingStoreId = householdId;
    final next = _loadStore(householdId);
    _storeLoading = next;
    return next;
  }

  Future<void> _loadStore(int householdId) async {
    await _migrateGlobalListSettings(householdId);
    final storage = PreferenceStorage.getInstance();
    String key(String name) => _storeKey(name, householdId);
    final gridSize = await storage.readInt(key: key('gridSize'));
    final listStyle = await storage.readInt(key: key('listStyle'));
    final sorting = await storage.read(key: key('shoppingListSorting'));
    const defaults = SettingsState();
    final values = {
      for (final name in _storeBoolSettings)
        name: await storage.readBool(key: key(name)),
    };
    final recentItemsCount = await storage.readInt(key: key('recentItemsCount'));
    // Un negozio aperto dopo questo ha vinto: le sue impostazioni non si
    // sovrascrivono con quelle di un caricamento più lento
    if (householdId != _loadingStoreId) return;
    _storeId = householdId;

    emit(state.copyWith(
      gridSize: gridSize != null ? GridSize.values[gridSize] : defaults.gridSize,
      listStyle:
          listStyle != null ? ListStyle.values[listStyle] : defaults.listStyle,
      recentItemsCount: recentItemsCount ?? defaults.recentItemsCount,
      shoppingListListView:
          values['shoppingListListView'] ?? defaults.shoppingListListView,
      shoppingListTapToRemove:
          values['shoppingListTapToRemove'] ?? defaults.shoppingListTapToRemove,
      recentItemsCategorize:
          values['recentItemsCategorize'] ?? defaults.recentItemsCategorize,
      shoppingListKeepAwake:
          values['shoppingListKeepAwake'] ?? defaults.shoppingListKeepAwake,
      shoppingListHideIcons:
          values['shoppingListHideIcons'] ?? defaults.shoppingListHideIcons,
      shoppingListSorting: ShoppinglistSorting.values.asNameMap()[sorting] ??
          defaults.shoppingListSorting,
    ));
  }

  /// L'ordinamento di prima era salvato per indice sotto itemSorting: 0 era
  /// alfabetico, 1 l'automatico che non c'è più, 2 per reparti.
  Future<void> _migrateGlobalListSettings(int householdId) async {
    final storage = PreferenceStorage.getInstance();
    if (await storage.readBool(key: 'storeSettingsMigrated') == true) return;
    for (final name in _storeIntSettings) {
      final value = await storage.readInt(key: name);
      if (value != null) {
        await storage.writeInt(key: _storeKey(name, householdId), value: value);
      }
      await storage.delete(key: name);
    }
    for (final name in _storeBoolSettings) {
      final value = await storage.readBool(key: name);
      if (value != null) {
        await storage.writeBool(key: _storeKey(name, householdId), value: value);
      }
      await storage.delete(key: name);
    }
    final itemSorting = await storage.readInt(key: 'itemSorting');
    if (itemSorting != null) {
      await storage.write(
        key: _storeKey('shoppingListSorting', householdId),
        value: itemSorting == 0
            ? ShoppinglistSorting.alphabetical.name
            : ShoppinglistSorting.category.name,
      );
    }
    await storage.delete(key: 'itemSorting');
    await storage.writeBool(key: 'storeSettingsMigrated', value: true);
  }

  static String _storeKey(String name, int householdId) =>
      '$name@$householdId';

  // Senza un negozio aperto la sezione della lista non si vede: non c'è
  // nulla da salvare
  void _writeStoreInt(String name, int value) {
    final storeId = _storeId;
    if (storeId == null) return;
    PreferenceStorage.getInstance()
        .writeInt(key: _storeKey(name, storeId), value: value);
  }

  void _writeStoreBool(String name, bool value) {
    final storeId = _storeId;
    if (storeId == null) return;
    PreferenceStorage.getInstance()
        .writeBool(key: _storeKey(name, storeId), value: value);
  }

  void setTheme(ThemeMode themeMode) {
    PreferenceStorage.getInstance()
        .writeInt(key: 'themeMode', value: themeMode.index);
    emit(state.copyWith(themeMode: themeMode));
  }

  void setUseDynamicAccentColor(bool dynamicAccentColor) {
    PreferenceStorage.getInstance()
        .writeBool(key: 'dynamicAccentColor', value: dynamicAccentColor);
    emit(state.copyWith(dynamicAccentColor: dynamicAccentColor));
  }

  void setGridSize(GridSize gridSize) {
    _writeStoreInt('gridSize', gridSize.index);
    emit(state.copyWith(gridSize: gridSize));
  }

  void setListStyle(ListStyle listStyle) {
    _writeStoreInt('listStyle', listStyle.index);
    emit(state.copyWith(listStyle: listStyle));
  }

  void setRecentItemsCount(int recentItemsCount) {
    if (recentItemsCount < 0) return;
    _writeStoreInt('recentItemsCount', recentItemsCount);
    emit(state.copyWith(recentItemsCount: recentItemsCount));
  }

  void setAccentColor(Color? accentColor) {
    accentColor = accentColor?.withAlpha(255);
    if (accentColor != null) {
      PreferenceStorage.getInstance()
          .writeInt(key: 'accentColor', value: accentColor.value);
    } else {
      PreferenceStorage.getInstance().delete(key: 'accentColor');
    }
    emit(state.copyWith(accentColor: Nullable(accentColor)));
  }

  void setShoppingListListView(bool shoppingListListView) {
    _writeStoreBool('shoppingListListView', shoppingListListView);
    emit(state.copyWith(shoppingListListView: shoppingListListView));
  }

  void setShoppingListTapToRemove(bool shoppingListTapToRemove) {
    _writeStoreBool('shoppingListTapToRemove', shoppingListTapToRemove);
    emit(state.copyWith(shoppingListTapToRemove: shoppingListTapToRemove));
  }

  void setRecentItemsCategorize(bool recentItemsCategorize) {
    _writeStoreBool('recentItemsCategorize', recentItemsCategorize);
    emit(state.copyWith(recentItemsCategorize: recentItemsCategorize));
  }

  void setRestoreLastShoppinglist(bool restoreLastShoppingList) {
    PreferenceStorage.getInstance().writeBool(
      key: 'restoreLastShoppingList',
      value: restoreLastShoppingList,
    );
    emit(state.copyWith(restoreLastShoppingList: restoreLastShoppingList));
  }

  void setShoppingListKeepAwake(bool shoppingListKeepAwake) {
    _writeStoreBool('shoppingListKeepAwake', shoppingListKeepAwake);
    emit(state.copyWith(shoppingListKeepAwake: shoppingListKeepAwake));
  }

  /// Articoli senza icona, solo col nome (features/006-icone-nascoste).
  void setShoppingListHideIcons(bool shoppingListHideIcons) {
    _writeStoreBool('shoppingListHideIcons', shoppingListHideIcons);
    emit(state.copyWith(shoppingListHideIcons: shoppingListHideIcons));
  }

  /// Salvato per nome e non per indice: l'indice è cambiato togliendo
  /// l'ordinamento automatico, e cambierebbe di nuovo con un valore nuovo.
  void setShoppingListSorting(ShoppinglistSorting shoppingListSorting) {
    final storeId = _storeId;
    if (storeId != null) {
      PreferenceStorage.getInstance().write(
        key: _storeKey('shoppingListSorting', storeId),
        value: shoppingListSorting.name,
      );
    }
    emit(state.copyWith(shoppingListSorting: shoppingListSorting));
  }
}

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final bool dynamicAccentColor;
  final int recentItemsCount;
  final GridSize gridSize;
  final ListStyle listStyle;
  final Color? accentColor;
  final bool shoppingListListView;
  final bool shoppingListTapToRemove;
  final bool recentItemsCategorize;
  final bool restoreLastShoppingList;
  final bool shoppingListKeepAwake;
  final bool shoppingListHideIcons;
  final ShoppinglistSorting shoppingListSorting;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.dynamicAccentColor = false,
    this.gridSize = GridSize.normal,
    this.listStyle = ListStyle.cards,
    this.recentItemsCount = 9,
    this.accentColor,
    this.shoppingListListView = false,
    this.shoppingListTapToRemove = true,
    this.recentItemsCategorize = false,
    this.restoreLastShoppingList = false,
    this.shoppingListKeepAwake = false,
    this.shoppingListHideIcons = false,
    this.shoppingListSorting = ShoppinglistSorting.category,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? dynamicAccentColor,
    GridSize? gridSize,
    ListStyle? listStyle,
    int? recentItemsCount,
    Nullable<Color>? accentColor,
    bool? shoppingListListView,
    bool? shoppingListTapToRemove,
    bool? recentItemsCategorize,
    bool? restoreLastShoppingList,
    bool? shoppingListKeepAwake,
    bool? shoppingListHideIcons,
    ShoppinglistSorting? shoppingListSorting,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        dynamicAccentColor: dynamicAccentColor ?? this.dynamicAccentColor,
        gridSize: gridSize ?? this.gridSize,
        listStyle: listStyle ?? this.listStyle,
        recentItemsCount: recentItemsCount ?? this.recentItemsCount,
        accentColor: (accentColor ?? Nullable(this.accentColor)).value,
        shoppingListListView: shoppingListListView ?? this.shoppingListListView,
        shoppingListTapToRemove:
            shoppingListTapToRemove ?? this.shoppingListTapToRemove,
        recentItemsCategorize:
            recentItemsCategorize ?? this.recentItemsCategorize,
        restoreLastShoppingList:
            restoreLastShoppingList ?? this.restoreLastShoppingList,
        shoppingListKeepAwake:
            shoppingListKeepAwake ?? this.shoppingListKeepAwake,
        shoppingListHideIcons:
            shoppingListHideIcons ?? this.shoppingListHideIcons,
        shoppingListSorting: shoppingListSorting ?? this.shoppingListSorting,
      );

  @override
  List<Object?> get props => [
        themeMode,
        dynamicAccentColor,
        gridSize,
        listStyle,
        recentItemsCount,
        accentColor,
        shoppingListListView,
        shoppingListTapToRemove,
        recentItemsCategorize,
        restoreLastShoppingList,
        shoppingListKeepAwake,
        shoppingListHideIcons,
        shoppingListSorting,
      ];
}
