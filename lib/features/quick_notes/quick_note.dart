class QuickNote {
  const QuickNote({
    required this.id,
    required this.title,
    required this.content,
    this.pinned = false,
    this.hidden = false,
    required this.updatedAt,
    this.lastCopiedAt,
  });

  final String id;
  final String title;
  final String content;

  /// Fixada no topo da lista.
  final bool pinned;

  /// Conteúdo mascarado na lista (dados bancários, documentos etc.).
  final bool hidden;

  final DateTime updatedAt;
  final DateTime? lastCopiedAt;

  /// Usada para ordenar: a mais recente entre edição e última cópia.
  DateTime get lastUsed =>
      lastCopiedAt != null && lastCopiedAt!.isAfter(updatedAt) ? lastCopiedAt! : updatedAt;

  QuickNote copyWith({
    String? title,
    String? content,
    bool? pinned,
    bool? hidden,
    DateTime? updatedAt,
    DateTime? lastCopiedAt,
  }) =>
      QuickNote(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        pinned: pinned ?? this.pinned,
        hidden: hidden ?? this.hidden,
        updatedAt: updatedAt ?? this.updatedAt,
        lastCopiedAt: lastCopiedAt ?? this.lastCopiedAt,
      );

  factory QuickNote.fromJson(Map<String, dynamic> json) => QuickNote(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        pinned: json['pinned'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
        lastCopiedAt: json['lastCopiedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['lastCopiedAt'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'pinned': pinned,
        'hidden': hidden,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'lastCopiedAt': lastCopiedAt?.millisecondsSinceEpoch,
      };
}
