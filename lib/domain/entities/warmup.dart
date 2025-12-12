import 'package:equatable/equatable.dart';

/// Warmup data for the pre-challenge warmups.
class Warmup extends Equatable {
  final int index;
  final String title;
  final String description;
  final String prompt;
  final int durationSeconds;
  final List<String> checklistItems;

  const Warmup({
    required this.index,
    required this.title,
    required this.description,
    required this.prompt,
    required this.durationSeconds,
    required this.checklistItems,
  });

  @override
  List<Object?> get props => [index, title, description, prompt, durationSeconds, checklistItems];
}

/// Predefined warmups for the app.
class Warmups {
  static const breathing = Warmup(
    index: 0,
    title: 'Deep Breathing',
    description: 'Calm your nerves and center yourself',
    prompt: 'Take 3 deep breaths. On camera, briefly introduce yourself and share how you\'re feeling right now.',
    durationSeconds: 60,
    checklistItems: [
      'I took 3 deep breaths before speaking',
      'I looked at the camera',
      'I spoke from the heart',
      'I felt calmer after recording',
    ],
  );

  static const smile = Warmup(
    index: 1,
    title: 'Genuine Smile',
    description: 'Practice authentic expressions',
    prompt: 'Think of something that makes you genuinely happy. Share that thought on camera with a smile.',
    durationSeconds: 60,
    checklistItems: [
      'My smile felt genuine',
      'I maintained eye contact with the camera',
      'I shared something personal',
      'I felt more relaxed than the first warmup',
    ],
  );

  static const energy = Warmup(
    index: 2,
    title: 'High Energy',
    description: 'Bring your enthusiasm',
    prompt: 'Pretend you\'re greeting your best friend. Talk about something you\'re excited about this week!',
    durationSeconds: 60,
    checklistItems: [
      'I spoke with energy and enthusiasm',
      'My gestures felt natural',
      'I didn\'t hold back my personality',
      'I felt ready to start the challenge',
    ],
  );

  static const List<Warmup> all = [breathing, smile, energy];

  static Warmup? getByIndex(int index) {
    if (index < 0 || index >= all.length) return null;
    return all[index];
  }
}

