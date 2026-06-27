import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/extension_provider.dart';
import 'package:spotiflac_android/providers/track_provider.dart';
import 'package:spotiflac_android/providers/preview_player_provider.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/widgets/track_collection_quick_actions.dart';
import 'package:spotiflac_android/widgets/animation_utils.dart';
import 'package:spotiflac_android/utils/clickable_metadata.dart';
import 'package:spotiflac_android/widgets/audio_quality_badges.dart';
import 'package:spotiflac_android/widgets/cached_cover_image.dart';
import 'package:spotiflac_android/widgets/preview_button.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String query;

  const SearchScreen({super.key, required this.query});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    if (widget.query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(trackProvider.notifier).search(widget.query);
      });
    }
  }

  @override
  void dispose() {
    ref.read(previewPlayerProvider.notifier).stop();
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(trackProvider.notifier).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: context.l10n.searchTracksHint,
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
          autofocus: widget.query.isEmpty,
        ),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).searchFieldLabel,
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: const _SearchResultsBody(),
    );
  }
}

class _SearchResultsBody extends ConsumerWidget {
  const _SearchResultsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(trackProvider.select((s) => s.tracks));
    final isLoading = ref.watch(trackProvider.select((s) => s.isLoading));
    final error = ref.watch(trackProvider.select((s) => s.error));
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (isLoading) LinearProgressIndicator(color: colorScheme.primary),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(error, style: TextStyle(color: colorScheme.error)),
          ),
        Expanded(
          child: AnimatedStateSwitcher(
            child: isLoading && tracks.isEmpty
                ? const TrackListSkeleton(key: ValueKey('loading'))
                : tracks.isEmpty
                ? _SearchEmptyState(
                    key: const ValueKey('empty'),
                    colorScheme: colorScheme,
                  )
                : ListView.builder(
                    key: const ValueKey('results'),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) => StaggeredListItem(
                      key: ValueKey('search-track-${tracks[index].id}-$index'),
                      index: index,
                      child: _SearchTrackTile(track: tracks[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SearchEmptyState({super.key, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            context.l10n.searchTracksEmptyPrompt,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTrackTile extends ConsumerWidget {
  final Track track;

  const _SearchTrackTile({required this.track});

  void _downloadTrack(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final extensionState = ref.read(extensionProvider);
    final service = resolveEffectiveDownloadService(
      settings.defaultService,
      extensionState,
    );
    if (service.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
      );
      return;
    }
    ref.read(downloadQueueProvider.notifier).addToQueue(track, service);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverWidget = track.coverUrl != null
        ? CachedCoverImage(
            imageUrl: track.coverUrl!,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(8),
          )
        : Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
          );

    return ListTile(
      leading: coverWidget,
      title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClickableArtistName(
            artistName: track.artistName,
            artistId: track.artistId,
            coverUrl: track.coverUrl,
            extensionId: track.source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          Row(
            children: [
              Flexible(
                child: ClickableAlbumName(
                  albumName: track.albumName,
                  albumId: track.albumId,
                  artistName: track.artistName,
                  coverUrl: track.coverUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              ...buildQualityBadges(
                audioQuality: track.audioQuality,
                audioModes: track.audioModes,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
      onLongPress: () => TrackCollectionQuickActions.showTrackOptionsSheet(
        context,
        ref,
        track,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PreviewButton(track: track),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: context.l10n.dialogDownload,
            onPressed: () => _downloadTrack(context, ref),
          ),
        ],
      ),
      onTap: () => _downloadTrack(context, ref),
    );
  }
}
