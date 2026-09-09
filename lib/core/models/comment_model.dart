/// Local Comment Model - pengganti commentum_client
enum CommentStatus { active, pending, archived, deleted }

class Comment {
  final String id;
  final String content;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int score;
  final CommentStatus status;
  final List<Comment> replies;
  final int repliesCount;
  final bool hasMoreReplies;
  final int? userVote; // -1 (downvote), 0 (no vote), 1 (upvote)

  Comment({
    required this.id,
    required this.content,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.score,
    required this.status,
    this.replies = const [],
    this.repliesCount = 0,
    this.hasMoreReplies = false,
    this.userVote,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'username': username,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'score': score,
      'status': status.name,
      'replies': replies.map((c) => c.toJson()).toList(),
      'repliesCount': repliesCount,
      'hasMoreReplies': hasMoreReplies,
      'userVote': userVote,
    };
  }

  /// Create from JSON
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      content: json['content'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      score: json['score'] as int,
      status: CommentStatus.values
          .firstWhere((e) => e.name == json['status'], orElse: () => CommentStatus.active),
      replies: (json['replies'] as List?)?.map((c) => Comment.fromJson(c)).toList() ?? [],
      repliesCount: json['repliesCount'] as int? ?? 0,
      hasMoreReplies: json['hasMoreReplies'] as bool? ?? false,
      userVote: json['userVote'] as int?,
    );
  }

  /// Copy with method
  Comment copyWith({
    String? id,
    String? content,
    String? username,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? score,
    CommentStatus? status,
    List<Comment>? replies,
    int? repliesCount,
    bool? hasMoreReplies,
    int? userVote,
  }) {
    return Comment(
      id: id ?? this.id,
      content: content ?? this.content,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      score: score ?? this.score,
      status: status ?? this.status,
      replies: replies ?? this.replies,
      repliesCount: repliesCount ?? this.repliesCount,
      hasMoreReplies: hasMoreReplies ?? this.hasMoreReplies,
      userVote: userVote ?? this.userVote,
    );
  }
}

/// Response model untuk list comments
class CommentResponse {
  final List<Comment> data;
  final int count;
  final String? nextCursor;

  CommentResponse({
    required this.data,
    required this.count,
    this.nextCursor,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    return CommentResponse(
      data: (json['data'] as List?)?.map((c) => Comment.fromJson(c)).toList() ?? [],
      count: json['count'] as int? ?? 0,
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((c) => c.toJson()).toList(),
      'count': count,
      'nextCursor': nextCursor,
    };
  }
}
