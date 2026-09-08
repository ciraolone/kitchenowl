import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:kitchenowl/widgets/image_provider.dart';

class SelectableButtonCard extends StatefulWidget {
  final String title;
  final IconData? icon;
  final String? description;
  final bool selected;
  final void Function()? onPressed;
  final void Function()? onLongPressed;
  final Widget? extraOption;
  // Se valorizzato, al posto dell'icona viene mostrato un thumbnail della foto
  // (con blurhash come placeholder durante il caricamento). Pensato come
  // copertina degli Item della lista spesa.
  final String? coverPhoto;
  final String? coverHash;

  const SelectableButtonCard({
    super.key,
    this.icon,
    required this.title,
    this.description,
    this.onPressed,
    this.onLongPressed,
    this.selected = false,
    this.extraOption,
    this.coverPhoto,
    this.coverHash,
  });

  @override
  State<SelectableButtonCard> createState() => _SelectableButtonCardState();
}

class _SelectableButtonCardState extends State<SelectableButtonCard> {
  bool mouseHover = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: widget.selected ? 1 : 0,
      color: widget.selected
          ? Theme.of(context).colorScheme.primary
          : ElevationOverlay.applySurfaceTint(
              Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
              Theme.of(context).cardTheme.surfaceTintColor ??
                  Theme.of(context).colorScheme.surfaceTint,
              1,
            ),
      child: MouseRegion(
        onEnter: (event) {
          setState(() {
            mouseHover = true;
          });
        },
        onExit: (event) {
          setState(() {
            mouseHover = false;
          });
        },
        child: InkWell(
          onTap: widget.onPressed,
          onSecondaryTap: widget.onLongPressed,
          onLongPress: widget.onLongPressed,
          child: Stack(
            alignment: AlignmentDirectional.topEnd,
            children: [
              if (widget.extraOption != null && mouseHover) widget.extraOption!,
              if (widget.extraOption == null &&
                  widget.onLongPressed != null &&
                  mouseHover)
                IconButton(
                  onPressed: widget.onLongPressed,
                  color: widget.selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.coverPhoto != null && widget.coverPhoto!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (widget.coverHash != null)
                                BlurHash(hash: widget.coverHash!),
                              Image(
                                image: getImageProvider(
                                  context,
                                  widget.coverPhoto!,
                                  maxWidth: 200,
                                  maxHeight: 200,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (widget.icon != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      child: LayoutBuilder(
                        builder: (context, constraint) => Icon(
                          widget.icon,
                          size: constraint.maxWidth / 2.4,
                          color: widget.selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                      ),
                    ),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.description?.isNotEmpty ?? false)
                    Text(
                      widget.description!,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: widget.selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withAlpha(178)
                                : null,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
