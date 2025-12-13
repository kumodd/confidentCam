import '../../domain/entities/onboarding_data.dart';

/// Data model for LanguageOption - extends the existing entity with toJson.
class LanguageOptionModel extends LanguageOption {
  const LanguageOptionModel({
    required super.id,
    required super.code,
    required super.name,
    required super.nativeName,
    super.description,
    super.isBilingual,
    super.primaryLanguage,
    super.secondaryLanguage,
    required super.orderIndex,
  });

  factory LanguageOptionModel.fromJson(Map<String, dynamic> json) {
    return LanguageOptionModel(
      id: json['id'] as String,
      code: json['language_code'] as String,
      name: json['language_name'] as String,
      nativeName: json['native_name'] as String,
      description: json['description'] as String?,
      isBilingual: json['is_bilingual'] as bool? ?? false,
      primaryLanguage: json['primary_language'] as String?,
      secondaryLanguage: json['secondary_language'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  /// Convert entity to model
  factory LanguageOptionModel.fromEntity(LanguageOption entity) {
    return LanguageOptionModel(
      id: entity.id,
      code: entity.code,
      name: entity.name,
      nativeName: entity.nativeName,
      description: entity.description,
      isBilingual: entity.isBilingual,
      primaryLanguage: entity.primaryLanguage,
      secondaryLanguage: entity.secondaryLanguage,
      orderIndex: entity.orderIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'language_code': code,
      'language_name': name,
      'native_name': nativeName,
      'description': description,
      'is_bilingual': isBilingual,
      'primary_language': primaryLanguage,
      'secondary_language': secondaryLanguage,
      'order_index': orderIndex,
    };
  }
}

