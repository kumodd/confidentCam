enum PromptMode {
  selfDiscovery,
  clarityTraining,
  storytelling,
  authorityBuild,
  rawDiary,
}

enum HumanTouchLevel {
  raw,
  natural,
  composed,
}

enum AudienceCulture {
  india,
  global,
}

class PromptProfile {
  final String systemPersona;
  final String coreIntent;
  final String speakerMindset;
  final String emotionalArc;
  final String forbiddenPatterns;
  final String closingBehavior;
  final String humanSpeechRules;
  final String audienceMirrorRules;
  final String culturalRules;

  const PromptProfile({
    required this.systemPersona,
    required this.coreIntent,
    required this.speakerMindset,
    required this.emotionalArc,
    required this.forbiddenPatterns,
    required this.closingBehavior,
    required this.humanSpeechRules,
    required this.audienceMirrorRules,
    required this.culturalRules,
  });
}

class PromptConfigFactory {
  static PromptProfile build({
    PromptMode mode = PromptMode.selfDiscovery,
    HumanTouchLevel humanTouch = HumanTouchLevel.natural,
    AudienceCulture culture = AudienceCulture.india,
  }) {
    return PromptProfile(
      systemPersona: _persona(mode),
      coreIntent: _intent(mode),
      speakerMindset: _mindset(mode),
      emotionalArc: _emotionalArc(mode),
      forbiddenPatterns: _forbidden(),
      closingBehavior: _closing(mode),
      humanSpeechRules: _humanRules(humanTouch),
      audienceMirrorRules: _audienceMirror(),
      culturalRules: _culture(culture),
    );
  }

  static String _persona(PromptMode mode) {
    switch (mode) {
      case PromptMode.rawDiary:
        return 'You speak as a real person thinking out loud.';
      case PromptMode.clarityTraining:
        return 'You help thoughts slow down and form naturally.';
      case PromptMode.storytelling:
        return 'You speak through lived moments and memories.';
      case PromptMode.authorityBuild:
        return 'You speak calmly, grounded, without asserting dominance.';
      case PromptMode.selfDiscovery:
      default:
        return 'You are a beginner learning to feel safe being seen.';
    }
  }

  static String _intent(PromptMode mode) {
    switch (mode) {
      case PromptMode.rawDiary:
        return 'Honest expression without polish.';
      case PromptMode.clarityTraining:
        return 'Clear thinking through speaking.';
      case PromptMode.storytelling:
        return 'Connection through shared moments.';
      case PromptMode.authorityBuild:
        return 'Quiet presence without claiming confidence.';
      default:
        return 'Reduce loneliness while speaking.';
    }
  }

  static String _mindset(PromptMode mode) {
    switch (mode) {
      case PromptMode.rawDiary:
        return 'Emotionally open, unsure, tired.';
      case PromptMode.clarityTraining:
        return 'Thoughtful, slightly scattered.';
      case PromptMode.storytelling:
        return 'Observant, reflective.';
      case PromptMode.authorityBuild:
        return 'Calm, unhurried.';
      default:
        return 'Nervous, reflective, honest.';
    }
  }

  static String _emotionalArc(PromptMode mode) {
    switch (mode) {
      case PromptMode.rawDiary:
        return 'Emotion → release → no resolution.';
      case PromptMode.clarityTraining:
        return 'Confusion → structure → clarity.';
      case PromptMode.storytelling:
        return 'Moment → emotion → staying inside it.';
      case PromptMode.authorityBuild:
        return 'Presence → steadiness.';
      default:
        return 'Fear → familiarity → small relief.';
    }
  }

  static String _forbidden() {
    return '''
- No advice
- No motivation
- No teaching
- No clean conclusions
- No confidence claims
''';
  }

  static String _closing(PromptMode mode) {
    switch (mode) {
      case PromptMode.rawDiary:
        return 'Abrupt stopping is allowed.';
      case PromptMode.authorityBuild:
        return 'Firm but gentle ending.';
      default:
        return 'Soft acceptance. No resolution.';
    }
  }

  static String _humanRules(HumanTouchLevel level) {
    switch (level) {
      case HumanTouchLevel.raw:
        return '''
- Incomplete thoughts allowed
- Contradictions allowed
- Messy flow is acceptable
''';
      case HumanTouchLevel.composed:
        return '''
- Calm pacing
- Fewer words
- Controlled pauses
''';
      default:
        return '''
- Natural repetition
- Gentle pauses using "..."
- Imperfect flow
''';
    }
  }

  static String _audienceMirror() {
    return '''
Speak thoughts many people feel but never say.
Do not resolve emotions.
Stop where the viewer still lives.
''';
  }

  static String _culture(AudienceCulture culture) {
    if (culture == AudienceCulture.global) return '';
    return '''
Indian emotional context:
- Quiet self-doubt
- Fear of judgement
- Guilt around self-focus
- Respect for effort, not loud confidence
''';
  }
}