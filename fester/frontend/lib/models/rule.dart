import 'package:equatable/equatable.dart';

class Rule extends Equatable {
  final String text;

  const Rule({
    required this.text,
  });

  factory Rule.fromJson(dynamic json) {
    if (json is String) {
      return Rule(text: json);
    }
    if (json is Map<String, dynamic>) {
      return Rule(text: json['text'] ?? '');
    }
    return const Rule(text: '');
  }

  Map<String, dynamic> toJson() => {
    'text': text,
  };

  Rule copyWith({
    String? text,
  }) {
    return Rule(
      text: text ?? this.text,
    );
  }

  @override
  List<Object?> get props => [text];
} 