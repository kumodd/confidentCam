import 'package:equatable/equatable.dart';

/// Represents a dynamic onboarding question from Supabase.
class OnboardingQuestion extends Equatable {
  final String id;
  final String key;
  final String questionText;
  final List<String> options;
  final bool isMultiSelect;
  final int orderIndex;

  const OnboardingQuestion({
    required this.id,
    required this.key,
    required this.questionText,
    required this.options,
    this.isMultiSelect = false,
    required this.orderIndex,
  });

  factory OnboardingQuestion.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestion(
      id: json['id'] as String,
      key: json['question_key'] as String,
      questionText: json['question_text'] as String,
      options: (json['options'] as List).cast<String>(),
      isMultiSelect: json['is_multi_select'] as bool? ?? false,
      orderIndex: json['order_index'] as int,
    );
  }

  @override
  List<Object?> get props => [
    id,
    key,
    questionText,
    options,
    isMultiSelect,
    orderIndex,
  ];
}

/// Represents a goal option from Supabase.
class GoalOption extends Equatable {
  final String id;
  final String key;
  final String text;
  final String? description;
  final int orderIndex;

  const GoalOption({
    required this.id,
    required this.key,
    required this.text,
    this.description,
    required this.orderIndex,
  });

  factory GoalOption.fromJson(Map<String, dynamic> json) {
    return GoalOption(
      id: json['id'] as String,
      key: json['goal_key'] as String,
      text: json['goal_text'] as String,
      description: json['description'] as String?,
      orderIndex: json['order_index'] as int,
    );
  }

  @override
  List<Object?> get props => [id, key, text, description, orderIndex];
}

/// Represents a language option from Supabase (including bilingual options).
class LanguageOption extends Equatable {
  final String id;
  final String code;
  final String name;
  final String nativeName;
  final String? description;
  final bool isBilingual;
  final String? primaryLanguage;
  final String? secondaryLanguage;
  final int orderIndex;

  const LanguageOption({
    required this.id,
    required this.code,
    required this.name,
    required this.nativeName,
    this.description,
    this.isBilingual = false,
    this.primaryLanguage,
    this.secondaryLanguage,
    required this.orderIndex,
  });

  factory LanguageOption.fromJson(Map<String, dynamic> json) {
    return LanguageOption(
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

  /// Display text for UI (e.g., "Hinglish (हिंग्लिश)")
  String get displayText => name != nativeName ? '$name ($nativeName)' : name;

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    nativeName,
    description,
    isBilingual,
    primaryLanguage,
    secondaryLanguage,
    orderIndex,
  ];
}

/// User's personal info collected during onboarding.
class UserPersonalInfo extends Equatable {
  final String firstName;
  final int age;
  final String location;
  final String goalKey;
  final String? customGoal;
  final String languagePreference;
  final Map<String, List<String>> answers; // question_key -> selected options

  const UserPersonalInfo({
    required this.firstName,
    required this.age,
    required this.location,
    required this.goalKey,
    this.customGoal,
    this.languagePreference = 'en',
    this.answers = const {},
  });

  String get displayGoal => customGoal ?? goalKey;

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'age': age,
    'location': location,
    'goal_category': goalKey,
    'custom_goal': customGoal,
    'language_preference': languagePreference,
    'onboarding_answers': answers,
  };

  UserPersonalInfo copyWith({
    String? firstName,
    int? age,
    String? location,
    String? goalKey,
    String? customGoal,
    String? languagePreference,
    Map<String, List<String>>? answers,
  }) {
    return UserPersonalInfo(
      firstName: firstName ?? this.firstName,
      age: age ?? this.age,
      location: location ?? this.location,
      goalKey: goalKey ?? this.goalKey,
      customGoal: customGoal ?? this.customGoal,
      languagePreference: languagePreference ?? this.languagePreference,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object?> get props => [
    firstName,
    age,
    location,
    goalKey,
    customGoal,
    languagePreference,
    answers,
  ];
}
