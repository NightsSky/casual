import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../providers/notes_provider.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../utils/common_utils.dart';

class SearchPage extends ConsumerStatefulWidget {
  final void Function(String noteId)? onOpenNote;
  final VoidCallback? onBack;

  const SearchPage({super.key, this.onOpenNote, this.onBack});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (value.trim().isNotEmpty) {
        ref.read(searchProvider.notifier).search(value);
      } else {
        ref.read(searchProvider.notifier).clearSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final isDesktop = getScreenType(context) == ScreenType.desktop;
    final hasResults = searchState.query.isNotEmpty;

    return Column(
      children: [
        _buildSearchBar(context, isDesktop),
        Expanded(
          child: hasResults
              ? _buildResults(searchState)
              : _buildRecentSearches(searchState),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        isDesktop
            ? AppSpacing.sm
            : MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: const Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    ref.read(searchProvider.notifier).search(value);
                  }
                },
                style: const TextStyle(fontSize: AppFontSize.base),
                decoration: InputDecoration(
                  hintText: context.l10n.searchNotes,
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.textPlaceholder),
                  suffixIcon: null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
              ),
            ),
          ),
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: TextButton(
                onPressed: () {
                  ref.read(searchProvider.notifier).clearSearch();
                  widget.onBack?.call();
                },
                child: Text(context.l10n.cancel),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(SearchState state) {
    if (state.recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: AppSpacing.lg),
            Text(context.l10n.enterKeywordToSearch,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.recentSearches,
                  style: const TextStyle(
                      fontSize: AppFontSize.base, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () =>
                    ref.read(searchProvider.notifier).clearRecentSearches(),
                child: Text(context.l10n.clear,
                    style: const TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textPlaceholder)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: state.recentSearches.length,
            itemBuilder: (context, index) {
              final item = state.recentSearches[index];
              return Card(
                child: InkWell(
                  onTap: () {
                    _searchController.text = item;
                    ref.read(searchProvider.notifier).search(item);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.history,
                            size: 16, color: AppColors.textPlaceholder),
                        const SizedBox(width: AppSpacing.sm),
                        Text(item,
                            style: const TextStyle(
                                fontSize: AppFontSize.base,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍',
                style: TextStyle(fontSize: 48, color: Colors.grey.shade400)),
            const SizedBox(height: AppSpacing.lg),
            Text(context.l10n.noSearchResults,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Text(
            context.l10n.searchResultsCount(state.results.length),
            style: const TextStyle(
                fontSize: AppFontSize.sm, color: AppColors.textPlaceholder),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.results.length,
            itemBuilder: (context, index) {
              final result = state.results[index];
              return Card(
                child: InkWell(
                  onTap: () {
                    ref.read(notesProvider.notifier).setCurrentNote(result.id);
                    widget.onOpenNote?.call(result.id);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          style: const TextStyle(
                              fontSize: AppFontSize.lg,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          result.content,
                          style: const TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary,
                              height: 1.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (result.tags.isNotEmpty)
                              Expanded(
                                child: Wrap(
                                  spacing: AppSpacing.xs,
                                  children: result.tags
                                      .take(3)
                                      .map((tag) => Text(
                                            '#$tag',
                                            style: const TextStyle(
                                                fontSize: AppFontSize.xs,
                                                color: AppColors.primary),
                                          ))
                                      .toList(),
                                ),
                              ),
                            Text(
                              formatTime(result.updatedAt,
                                  locale: Localizations.localeOf(context)
                                      .languageCode),
                              style: const TextStyle(
                                  fontSize: AppFontSize.xs,
                                  color: AppColors.textPlaceholder),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
