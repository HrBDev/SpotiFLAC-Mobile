package gobackend

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestExtensionProviderWrapperFullSurface(t *testing.T) {
	ext := newTestLoadedExtension(t, ExtensionTypeMetadataProvider, ExtensionTypeDownloadProvider, ExtensionTypeLyricsProvider)
	provider := newExtensionProviderWrapper(ext)

	search, err := provider.SearchTracks("query", 5)
	if err != nil {
		t.Fatalf("SearchTracks: %v", err)
	}
	if search.Total != 1 || search.Tracks[0].ProviderID != ext.ID || search.Tracks[0].ExternalLinks["tidal"] == "" {
		t.Fatalf("search = %#v", search)
	}

	track, err := provider.GetTrack("track-1")
	if err != nil {
		t.Fatalf("GetTrack: %v", err)
	}
	if track.Name != "Track track-1" || track.ProviderID != ext.ID || track.AudioQuality == "" {
		t.Fatalf("track = %#v", track)
	}

	album, err := provider.GetAlbum("album-1")
	if err != nil {
		t.Fatalf("GetAlbum: %v", err)
	}
	if album.ProviderID != ext.ID || len(album.Tracks) != 1 || album.Tracks[0].ProviderID != ext.ID {
		t.Fatalf("album = %#v", album)
	}

	playlist, err := provider.GetPlaylist("playlist-1")
	if err != nil {
		t.Fatalf("GetPlaylist: %v", err)
	}
	if playlist.Name != "Playlist playlist-1" || playlist.ProviderID != ext.ID {
		t.Fatalf("playlist = %#v", playlist)
	}

	artist, err := provider.GetArtist("artist-1")
	if err != nil {
		t.Fatalf("GetArtist: %v", err)
	}
	if artist.ProviderID != ext.ID || len(artist.Releases) != 1 || artist.Releases[0].ProviderID != ext.ID {
		t.Fatalf("artist = %#v", artist)
	}

	enriched, err := provider.EnrichTrack(&ExtTrackMetadata{ID: "track-1", Name: "Old", ProviderID: ext.ID})
	if err != nil {
		t.Fatalf("EnrichTrack: %v", err)
	}
	if enriched.Name != "Enriched" || enriched.ProviderID != ext.ID {
		t.Fatalf("enriched = %#v", enriched)
	}

	availability, err := provider.CheckAvailability("ISRC", "Song", "Artist", "spotify:1", "dz", "tidal", "qobuz")
	if err != nil {
		t.Fatalf("CheckAvailability: %v", err)
	}
	if !availability.Available || availability.TrackID != "download-track" || !availability.SkipFallback {
		t.Fatalf("availability = %#v", availability)
	}

	downloadURL, err := provider.GetDownloadURL("track-1", "LOSSLESS")
	if err != nil {
		t.Fatalf("GetDownloadURL: %v", err)
	}
	if downloadURL.Format != "flac" || downloadURL.BitDepth != 24 || downloadURL.SampleRate != 96000 {
		t.Fatalf("download URL = %#v", downloadURL)
	}

	progress := []int{}
	download, err := provider.Download("track-1", "LOSSLESS", filepath.Join(t.TempDir(), "song.flac"), "", func(percent int) {
		progress = append(progress, percent)
	})
	if err != nil {
		t.Fatalf("Download: %v", err)
	}
	if !download.Success || download.Decryption == nil || download.DecryptionKey != "001122" || len(progress) != 1 || progress[0] != 100 {
		t.Fatalf("download = %#v progress=%v", download, progress)
	}

	lyrics, err := provider.FetchLyrics("Song", "Artist", "Album", 180)
	if err != nil {
		t.Fatalf("GetLyrics: %v", err)
	}
	if lyrics.Provider != ext.ID || len(lyrics.Lines) != 1 || lyrics.Lines[0].Words != "Hello" {
		t.Fatalf("lyrics = %#v", lyrics)
	}

	urlResult, err := provider.HandleURL("https://example.test/track/1")
	if err != nil {
		t.Fatalf("HandleURL: %v", err)
	}
	if urlResult.Track == nil || urlResult.Track.Name == "" || len(urlResult.Tracks) != 1 || urlResult.Album == nil || urlResult.Artist == nil {
		t.Fatalf("url result = %#v", urlResult)
	}

	match, err := provider.MatchTrack(
		map[string]interface{}{"name": "Song", "artists": "Artist"},
		[]map[string]interface{}{{"id": "download-track", "name": "Song"}},
	)
	if err != nil {
		t.Fatalf("MatchTrack: %v", err)
	}
	if !match.Matched || match.TrackID != "download-track" {
		t.Fatalf("match = %#v", match)
	}

	post, err := provider.PostProcess(filepath.Join(t.TempDir(), "song.flac"), map[string]interface{}{"title": "Song"}, "hook")
	if err != nil {
		t.Fatalf("PostProcess: %v", err)
	}
	if !post.Success || post.BitDepth != 24 || post.SampleRate != 96000 {
		t.Fatalf("post = %#v", post)
	}
}

func TestBuiltInProviderAndManagerSelectionHelpers(t *testing.T) {
	previousRegistry := builtInProviderRegistry
	builtInProviderRegistry = []builtInProviderSpec{{
		ID:               "deezer",
		DisplayName:      "Deezer",
		SupportsMetadata: true,
		SupportsSearch:   true,
		GetMetadata:      GetDeezerMetadata,
		SearchAll: func(query string, trackLimit, artistLimit int, filter string) (string, error) {
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			result, err := GetDeezerClient().SearchAll(ctx, query, trackLimit, artistLimit, filter)
			if err != nil {
				return "", err
			}
			data, err := json.Marshal(result)
			return string(data), err
		},
		SearchTracks: func(query string, limit int) ([]ExtTrackMetadata, error) {
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			result, err := GetDeezerClient().SearchAll(ctx, query, limit, limit, "track")
			if err != nil {
				return nil, err
			}
			tracks := make([]ExtTrackMetadata, len(result.Tracks))
			for i, track := range result.Tracks {
				tracks[i] = normalizeBuiltInMetadataTrack(track, "deezer")
			}
			return tracks, nil
		},
	}}
	defer func() { builtInProviderRegistry = previousRegistry }()

	deezerClient = &DeezerClient{
		httpClient: &http.Client{Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
			body := fakeDeezerResponse(req.URL.Path, req.URL.RawQuery)
			if body == "" {
				body = `{"data":[]}`
			}
			return &http.Response{StatusCode: http.StatusOK, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(body)), Request: req}, nil
		})},
		searchCache:          map[string]*cacheEntry{},
		albumCache:           map[string]*cacheEntry{},
		artistCache:          map[string]*cacheEntry{},
		isrcCache:            map[string]string{},
		cacheCleanupInterval: time.Hour,
	}
	deezerClientOnce.Do(func() {})

	if !isBuiltInProvider("deezer") || !isBuiltInMetadataProvider("deezer") || !isBuiltInSearchProvider("deezer") {
		t.Fatal("expected Deezer built-in provider")
	}
	if _, ok := getBuiltInProviderSpec(" missing "); ok {
		t.Fatal("unexpected missing provider spec")
	}
	if _, err := getBuiltInProviderMetadata("missing", "track", "1"); err == nil {
		t.Fatal("expected unsupported metadata provider")
	}
	if jsonText, err := getBuiltInProviderMetadata("deezer", "track", "101"); err != nil || !strings.Contains(jsonText, "Track 101") {
		t.Fatalf("built-in metadata = %q/%v", jsonText, err)
	}
	if jsonText, err := searchBuiltInProviderAll("deezer", "artist song", 2, 2, "track"); err != nil || !strings.Contains(jsonText, "Track 101") {
		t.Fatalf("built-in search all = %q/%v", jsonText, err)
	}
	tracks, err := searchBuiltInProviderTracks("deezer", "artist song", 2)
	if err != nil || len(tracks) != 1 || tracks[0].ProviderID != "deezer" {
		t.Fatalf("built-in tracks = %#v/%v", tracks, err)
	}
	if _, err := searchBuiltInProviderTracks("missing", "q", 1); err == nil {
		t.Fatal("expected unsupported built-in tracks")
	}

	manifest := &ExtensionManifest{Capabilities: map[string]interface{}{
		"replacesBuiltInProviders": []interface{}{" Deezer ", 7, ""},
	}}
	if values := manifestCapabilityStringList(manifest, "replacesBuiltInProviders"); len(values) != 1 || values[0] != "deezer" {
		t.Fatalf("capability list = %#v", values)
	}
	if !extensionReplacesBuiltInProvider(&loadedExtension{Manifest: manifest}, "deezer") || extensionReplacesBuiltInProvider(nil, "deezer") {
		t.Fatal("extension replacement mismatch")
	}
	if trimKnownProviderPrefix("Deezer:101", "deezer") != "101" || trimKnownProviderPrefix("101", "deezer") != "101" {
		t.Fatal("trimKnownProviderPrefix mismatch")
	}
	normalized := normalizeBuiltInMetadataTrack(TrackMetadata{SpotifyID: "deezer:101", Name: "Song", Artists: "Artist", ISRC: "ISRC"}, "deezer")
	if normalized.DeezerID != "101" || normalized.ProviderID != "deezer" {
		t.Fatalf("normalized built-in track = %#v", normalized)
	}
	if metadataTrackDedupKey(ExtTrackMetadata{ISRC: "usrc"}) != "isrc:USRC" ||
		metadataTrackDedupKey(ExtTrackMetadata{SpotifyID: "sp"}) != "spotify:sp" ||
		metadataTrackDedupKey(ExtTrackMetadata{ProviderID: "p", ID: "1"}) != "p:1" {
		t.Fatal("metadata dedup key mismatch")
	}
	searchBuiltInMetadataTracksFunc = func(providerID, query string, limit int) ([]ExtTrackMetadata, error) {
		return []ExtTrackMetadata{{ID: "built-in", ProviderID: providerID}}, nil
	}
	defer func() { searchBuiltInMetadataTracksFunc = searchBuiltInMetadataTracks }()
	if tracks, err := searchBuiltInMetadataTracksForItemID("deezer", "q", 1, "item"); err != nil || len(tracks) != 1 {
		t.Fatalf("searchBuiltInMetadataTracksForItemID = %#v/%v", tracks, err)
	}

	manager := &extensionManager{extensions: map[string]*loadedExtension{}}
	downloadExt := newTestLoadedExtension(t, ExtensionTypeDownloadProvider, ExtensionTypeMetadataProvider)
	manager.extensions[downloadExt.ID] = downloadExt
	if providers := manager.GetDownloadProviders(); len(providers) != 1 {
		t.Fatalf("download providers = %#v", providers)
	}
	SetProviderPriority([]string{"deezer", "coverage-ext", "coverage-ext", " "})
	if priority := GetProviderPriority(); len(priority) != 1 || priority[0] != "coverage-ext" {
		t.Fatalf("provider priority = %#v", priority)
	}
	SetExtensionFallbackProviderIDs([]string{"a", "a", " ", "b"})
	if ids := GetExtensionFallbackProviderIDs(); len(ids) != 2 || !isExtensionFallbackAllowed("a") || isExtensionFallbackAllowed("z") {
		t.Fatalf("fallback ids = %#v", ids)
	}
	SetExtensionFallbackProviderIDs(nil)
	if !isExtensionFallbackAllowed("z") {
		t.Fatal("nil fallback list should allow all")
	}
	SetMetadataProviderPriority([]string{"spotify", "deezer", "coverage-ext", "coverage-ext"})
	if priority := GetMetadataProviderPriority(); len(priority) != 2 || priority[0] != "deezer" || priority[1] != "coverage-ext" {
		t.Fatalf("metadata priority = %#v", priority)
	}
}
