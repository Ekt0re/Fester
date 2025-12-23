class TemplateModel {
  final String id;
  final String name;
  final String description;
  final String html;
  final String css;
  final List<String> variables;

  TemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.html,
    this.css = '',
    this.variables = const [],
  });

  TemplateModel copyWith({
    String? id,
    String? name,
    String? description,
    String? html,
    String? css,
    List<String>? variables,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      html: html ?? this.html,
      css: css ?? this.css,
      variables: variables ?? this.variables,
    );
  }
}
