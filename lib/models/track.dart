import 'package:json_annotation/json_annotation.dart';

part 'track.g.dart';

@JsonSerializable()
class Track {
  final String id;
  final String name;
  final String artistName;
  final String albumName;
  final String? albumArtist;
  final String? artistId;
  final String? albumId;
  final String? coverUrl;
  final String? isrc;
  final String? previewUrl;
  final int duration;
  final int? trackNumber;
  final int? discNumber;
  final int? totalDiscs;
  final String? releaseDate;
  final String? deezerId;
  final ServiceAvailability? availability;
  final String? source;
  final String? albumType;
  final int? totalTracks;
  final String? composer;
  final String? itemType;
  final String? audioQuality;
  final String? audioModes;

  const Track({
    required this.id,
    required this.name,
    required this.artistName,
    required this.albumName,
    this.albumArtist,
    this.artistId,
    this.albumId,
    this.coverUrl,
    this.isrc,
    this.previewUrl,
    required this.duration,
    this.trackNumber,
    this.discNumber,
    this.totalDiscs,
    this.releaseDate,
    this.deezerId,
    this.availability,
    this.source,
    this.albumType,
    this.totalTracks,
    this.composer,
    this.itemType,
    this.audioQuality,
    this.audioModes,
  });

  bool get isSingle {
    switch (albumType?.toLowerCase()) {
      case 'single':
      case 'ep':
        return true;
      default:
        return false;
    }
  }

  bool get isAlbumItem => itemType == 'album';

  bool get isPlaylistItem => itemType == 'playlist';

  bool get isArtistItem => itemType == 'artist';

  bool get isCollection => isAlbumItem || isPlaylistItem || isArtistItem;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);

  bool get isFromExtension => source != null && source!.isNotEmpty;

  bool get isDolbyAtmos =>
      audioModes != null && audioModes!.contains('DOLBY_ATMOS');

  bool get hasAudioQuality => audioQuality != null && audioQuality!.isNotEmpty;

  bool get hasPreview => previewUrl != null && previewUrl!.isNotEmpty;
}

@JsonSerializable()
class ServiceAvailability {
  final bool tidal;
  final bool qobuz;
  final bool amazon;
  final bool deezer;
  final String? tidalUrl;
  final String? qobuzUrl;
  final String? amazonUrl;
  final String? deezerUrl;
  final String? deezerId;

  const ServiceAvailability({
    this.tidal = false,
    this.qobuz = false,
    this.amazon = false,
    this.deezer = false,
    this.tidalUrl,
    this.qobuzUrl,
    this.amazonUrl,
    this.deezerUrl,
    this.deezerId,
  });

  factory ServiceAvailability.fromJson(Map<String, dynamic> json) =>
      _$ServiceAvailabilityFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceAvailabilityToJson(this);
}
