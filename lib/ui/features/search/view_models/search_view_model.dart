import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/models.dart';
import '../../../../utils/markdown_utils.dart';
import '../../notes/view_models/notes_view_model.dart';

class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool isSearching;
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool clearResults = false,
    bool? isSearching,
    List<String>? recentSearches,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: clearResults ? [] : results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  static const _maxRecent = 10;
  final Ref _ref;

  void search(String query) {
    if (query.trim().isEmpty) {
      state = state.copyWith(clearResults: true, query: '');
      return;
    }

    state = state.copyWith(isSearching: true, query: query);

    final notes = _ref.read(notesProvider).notes;
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (final note in notes) {
      final titleMatch = _scoreMatch(note.title.toLowerCase(), lowerQuery);
      final contentMatch =
          _scoreMatch(stripMarkdown(note.content).toLowerCase(), lowerQuery);
      final tagMatch = _scoreTags(note.tags, lowerQuery);
      final score = titleMatch * 3 + tagMatch * 2 + contentMatch;

      if (score > 0) {
        results.add(SearchResult(
          id: note.id,
          title: note.title,
          content: stripMarkdown(note.content),
          tags: note.tags,
          updatedAt: note.updatedAt,
          score: score,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    _addRecentSearch(query);
    state = state.copyWith(results: results, isSearching: false);
  }

  double _scoreMatch(String text, String query) {
    if (text.contains(query)) {
      return text.startsWith(query) ? 2.0 : 1.0;
    }
    final words = query.split(RegExp(r'\s+'));
    var matchCount = 0;
    for (final word in words) {
      if (text.contains(word)) matchCount++;
    }
    return matchCount / words.length * 0.5;
  }

  double _scoreTags(List<String> tags, String query) {
    for (final tag in tags) {
      if (tag.toLowerCase() == query) return 1.0;
      if (tag.toLowerCase().contains(query)) return 0.8;
    }
    return 0;
  }

  void clearSearch() {
    state = state.copyWith(query: '', clearResults: true);
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }

  void _addRecentSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final recent = [trimmed, ...state.recentSearches.where((s) => s != trimmed)]
        .take(_maxRecent)
        .toList();
    state = state.copyWith(recentSearches: recent);
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
