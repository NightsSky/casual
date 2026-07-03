class SearchResult {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime updatedAt;
  final double score;

  const SearchResult({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.updatedAt,
    required this.score,
  });
}
