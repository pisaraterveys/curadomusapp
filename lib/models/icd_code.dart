class ICDCode {
  final String code;
  final String description;

  ICDCode({required this.code, required this.description});

  factory ICDCode.fromJson(Map<String, dynamic> json) {
    return ICDCode(
      code: json['code'] as String,
      description: json['description'] as String,
    );
  }
}
