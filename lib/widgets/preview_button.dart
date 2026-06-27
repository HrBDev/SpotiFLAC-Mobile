import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/preview_player_provider.dart';

class PreviewButton extends ConsumerWidget {
  final Track track;
  final double size;

  const PreviewButton({super.key, required this.track, this.size = 24});

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(previewPlayerProvider.notifier).toggle(track.previewUrl);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.previewUnavailable)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!track.hasPreview) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final previewState = ref.watch(previewPlayerProvider);
    final isActive = previewState.isActiveUrl(track.previewUrl);
    final status = isActive ? previewState.status : PreviewStatus.idle;

    final Widget icon;
    final String tooltip;
    switch (status) {
      case PreviewStatus.loading:
        icon = SizedBox(
          width: size * 0.7,
          height: size * 0.7,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        );
        tooltip = context.l10n.previewStop;
        break;
      case PreviewStatus.playing:
        icon = Icon(
          Icons.pause_circle_filled_rounded,
          color: colorScheme.primary,
        );
        tooltip = context.l10n.previewStop;
        break;
      case PreviewStatus.paused:
        icon = Icon(
          Icons.play_circle_fill_rounded,
          color: colorScheme.primary,
        );
        tooltip = context.l10n.previewPlay;
        break;
      case PreviewStatus.idle:
        icon = Icon(
          Icons.play_circle_outline_rounded,
          color: colorScheme.onSurfaceVariant,
        );
        tooltip = context.l10n.previewPlay;
        break;
    }

    return Transform.translate(
      offset: const Offset(18, 0),
      child: IconButton(
        iconSize: size,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 36),
        icon: icon,
        tooltip: tooltip,
        onPressed: () => _onPressed(context, ref),
      ),
    );
  }
}
