<!-- Scelte tecniche della feature 006 (icone nascoste). Il cosa sta in spec.md. -->

# Piano

- Nuovo campo `shoppingListHideIcons` in `SettingsState`, salvato in `PreferenceStorage` con la stessa chiave, come gli altri interruttori di `SettingsCubit`.
- La pagina della lista la passa in `ShoppingListStyle.hideIcons`, che arriva a `SliverItemGridList` e da lì a `ShoppingItemWidget` (`showIcon`), l'unico punto che dà l'icona alle caselle in griglia ed elenco. Le caselle senza icona sanno già mostrarsi col solo nome. Si passa per lo stile e non per `App.settings` dentro la casella, perché la casella si usa anche fuori dalla lista (impostazioni degli articoli, scelta dell'icona) e lì le icone devono restare.
- La pagina della lista ricostruisce gli articoli quando l'impostazione cambia (`buildWhen` in `pages/household_page/shoppinglist.dart`).
- Testo nuovo solo in `app_en.arb`: l'app è sempre in inglese (feature 003).
