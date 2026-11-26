/// Detected spoken language category for multilingual teleprompter tracking.
enum SpokenLanguage {
  unknown,
  english,
  hindi,
  hinglish,
}

extension SpokenLanguageX on SpokenLanguage {
  String get shortBadge {
    switch (this) {
      case SpokenLanguage.english:
        return 'EN';
      case SpokenLanguage.hindi:
        return 'HI';
      case SpokenLanguage.hinglish:
        return 'HI-EN';
      case SpokenLanguage.unknown:
        return 'AUTO';
    }
  }

  String get displayName {
    switch (this) {
      case SpokenLanguage.english:
        return 'English';
      case SpokenLanguage.hindi:
        return 'Hindi';
      case SpokenLanguage.hinglish:
        return 'Hinglish (HI+EN)';
      case SpokenLanguage.unknown:
        return 'Auto-Detect';
    }
  }
}

/// Deterministic Devanagari-to-Latin phonetic transliterator.
///
/// Enables cross-script fuzzy matching so Hindi Devanagari ASR output
/// (e.g., `"क्या आपको लगता है कॉन्फिडेंस"`) matches Romanized Hinglish scripts
/// (e.g., `"Kya aapko lagta hai confidence"`) and vice versa.
class DevanagariTransliterator {
  const DevanagariTransliterator._();

  static const Map<int, String> _independentVowels = {
    0x0905: 'a', // अ
    0x0906: 'aa', // आ
    0x0907: 'i', // इ
    0x0908: 'ee', // ई
    0x0909: 'u', // उ
    0x090A: 'oo', // ऊ
    0x090B: 'ri', // ऋ
    0x090F: 'e', // ए
    0x0910: 'ai', // ऐ
    0x0911: 'o', // ऑ
    0x0913: 'o', // ओ
    0x0914: 'au', // औ
  };

  static const Map<int, String> _consonants = {
    0x0915: 'k', // क
    0x0916: 'kh', // ख
    0x0917: 'g', // ग
    0x0918: 'gh', // घ
    0x0919: 'ng', // ङ
    0x091A: 'ch', // च
    0x091B: 'chh', // छ
    0x091C: 'j', // ज
    0x091D: 'jh', // झ
    0x091E: 'ny', // ञ
    0x091F: 't', // ट
    0x0920: 'th', // ठ
    0x0921: 'd', // ड
    0x0922: 'dh', // ढ
    0x0923: 'n', // ण
    0x0924: 't', // त
    0x0925: 'th', // थ
    0x0926: 'd', // द
    0x0927: 'dh', // ध
    0x0928: 'n', // न
    0x0929: 'n', // ऩ
    0x092A: 'p', // प
    0x092B: 'ph', // फ
    0x092C: 'b', // ब
    0x092D: 'bh', // भ
    0x092E: 'm', // म
    0x092F: 'y', // य
    0x0930: 'r', // र
    0x0931: 'r', // ऱ
    0x0932: 'l', // ल
    0x0933: 'l', // ळ
    0x0935: 'v', // व
    0x0936: 'sh', // श
    0x0937: 'sh', // ष
    0x0938: 's', // स
    0x0939: 'h', // ह
    0x0958: 'k', // क़
    0x0959: 'kh', // ख़
    0x095A: 'g', // ग़
    0x095B: 'z', // ज़
    0x095C: 'r', // ड़
    0x095D: 'rh', // ढ़
    0x095E: 'f', // फ़
    0x095F: 'y', // य़
  };

  static const Map<int, String> _vowelMatras = {
    0x093E: 'aa', // ा
    0x093F: 'i', // ि
    0x0940: 'ee', // ी
    0x0941: 'u', // ु
    0x0942: 'oo', // ू
    0x0943: 'ri', // ृ
    0x0945: 'e', // ॅ
    0x0947: 'e', // े
    0x0948: 'ai', // ै
    0x0949: 'o', // ॉ
    0x094B: 'o', // ो
    0x094C: 'au', // ौ
  };

  static const int _halant = 0x094D; // ्
  static const int _nukta = 0x093C; // ़
  static const int _anusvara = 0x0902; // ं
  static const int _chandrabindu = 0x0901; // ँ
  static const int _visarga = 0x0903; // ः

  static bool containsDevanagari(String input) {
    for (final rune in input.runes) {
      if (rune >= 0x0900 && rune <= 0x097F) return true;
    }
    return false;
  }

  /// Transliterates any Devanagari characters in [input] into phonetic Latin
  /// while leaving ASCII/Latin characters untouched.
  static String toLatin(String input) {
    if (!containsDevanagari(input)) return input;

    final runes = input.runes.toList(growable: false);
    final out = StringBuffer();

    var i = 0;
    while (i < runes.length) {
      final cp = runes[i];

      if (cp < 0x0900 || cp > 0x097F) {
        out.writeCharCode(cp);
        i++;
        continue;
      }

      // Digits ०-९
      if (cp >= 0x0966 && cp <= 0x096F) {
        out.writeCharCode(0x30 + (cp - 0x0966));
        i++;
        continue;
      }

      if (cp == _anusvara || cp == _chandrabindu) {
        out.write('n');
        i++;
        continue;
      }
      if (cp == _visarga) {
        out.write('h');
        i++;
        continue;
      }

      final indepVowel = _independentVowels[cp];
      if (indepVowel != null) {
        out.write(indepVowel);
        i++;
        continue;
      }

      var consonant = _consonants[cp];
      if (consonant != null) {
        // Handle nukta modifier (e.g., फ + ़ -> f, ज + ़ -> z)
        if (i + 1 < runes.length && runes[i + 1] == _nukta) {
          if (cp == 0x092B) consonant = 'f';
          if (cp == 0x091C) consonant = 'z';
          if (cp == 0x0921) consonant = 'r';
          if (cp == 0x0922) consonant = 'rh';
          i++;
        }

        out.write(consonant);

        final next = (i + 1 < runes.length) ? runes[i + 1] : null;
        final next2 = (i + 2 < runes.length) ? runes[i + 2] : null;
        if (next == _halant) {
          // Explicit virama suppresses inherent 'a'
          i += 2;
        } else if (next != null && _vowelMatras.containsKey(next)) {
          out.write(_vowelMatras[next]);
          i += 2;
        } else {
          // Hindi schwa deletion:
          // 1. Always delete inherent 'a' at word end ("कमल" -> "kamal").
          // 2. Delete medial schwa before a consonant+matra when not word-initial
          //    ("आपको" -> "aapko", "लगता" -> "lagta", "सामने" -> "samne").
          final isWordEnd = next == null || next < 0x0900 || next > 0x097F;
          final prev = i > 0 ? runes[i - 1] : null;
          final isWordStart = prev == null || prev < 0x0900 || prev > 0x097F;
          final nextIsConsonantWithMatra = next != null &&
              _consonants.containsKey(next) &&
              next2 != null &&
              _vowelMatras.containsKey(next2);
          final suppressSchwa =
              isWordEnd || (!isWordStart && nextIsConsonantWithMatra);
          if (!suppressSchwa) {
            out.write('a');
          }
          i++;
        }
        continue;
      }

      final matra = _vowelMatras[cp];
      if (matra != null) {
        out.write(matra);
        i++;
        continue;
      }

      // Skip danda / other Devanagari punctuation cleanly
      out.write(' ');
      i++;
    }

    return out.toString();
  }
}

/// Real-time spoken language detector combining platform ASR language codes
/// with lightweight lexical + Unicode script analysis for English, Hindi, and
/// code-switched Hinglish.
class SpokenLanguageDetector {
  static const Set<String> _romanHindiMarkers = {
    'hai',
    'hain',
    'nahi',
    'nahin',
    'kya',
    'aap',
    'aapko',
    'aapka',
    'aapki',
    'mein',
    'mera',
    'meri',
    'hum',
    'hamara',
    'toh',
    'bhi',
    'aur',
    'lekin',
    'kyunki',
    'agar',
    'sabko',
    'pata',
    'saamne',
    'samne',
    'hota',
    'hoti',
    'chalo',
    'chaliye',
    'shuru',
    'karein',
    'karo',
    'karna',
    'karne',
    'baat',
    'samajh',
    'lagta',
    'lagti',
    'bilkul',
    'sirf',
    'aaj',
    'kal',
    'pehle',
    'pehli',
    'baar',
    'chhote',
    'chote',
    'zyada',
    'bahut',
    'khud',
    'vishwas',
    'rakho',
    'yeh',
    'woh',
    'jab',
    'tab',
    'kaise',
    'kitna',
    'asaan',
    'tayyar',
    'jao',
    'apni',
    'apne',
    'zarurat',
    'log',
    'karte',
    'jaata',
    'aati',
  };

  static const Set<String> _englishMarkers = {
    'the',
    'and',
    'is',
    'are',
    'was',
    'were',
    'this',
    'that',
    'with',
    'from',
    'your',
    'you',
    'have',
    'will',
    'about',
    'camera',
    'confidence',
    'practice',
    'today',
    'first',
    'step',
    'goal',
    'remember',
    'smile',
    'speak',
    'heart',
    'perfect',
    'matters',
    'action',
    'together',
    'simple',
    'system',
    'tools',
    'focus',
    'build',
    'start',
    'video',
    'script',
  };

  int _hindiEvidence = 0;
  int _englishEvidence = 0;
  SpokenLanguage _detected = SpokenLanguage.unknown;

  SpokenLanguage get detected => _detected;

  void reset() {
    _hindiEvidence = 0;
    _englishEvidence = 0;
    _detected = SpokenLanguage.unknown;
  }

  /// Updates the detected language from a platform ISO/BCP-47 language
  /// code (e.g. `"en-US"`, `"hi-IN"`, `"hi"`, `"en"`) and/or recognized text.
  SpokenLanguage observe({String? languageCode, String? text}) {
    if (languageCode != null && languageCode.trim().isNotEmpty) {
      final norm = languageCode.trim().toLowerCase();
      if (norm.startsWith('hi')) {
        _hindiEvidence += 3;
      } else if (norm.startsWith('en')) {
        _englishEvidence += 2;
      }
    }

    if (text != null && text.trim().isNotEmpty) {
      final tokens = text
          .toLowerCase()
          .split(RegExp(r'[\s,.\?!;:\-\(\)\[\]"]+'))
          .where((t) => t.isNotEmpty);

      for (final token in tokens) {
        if (DevanagariTransliterator.containsDevanagari(token)) {
          _hindiEvidence += 2;
        } else if (_romanHindiMarkers.contains(token)) {
          _hindiEvidence += 2;
        } else if (_englishMarkers.contains(token)) {
          _englishEvidence += 2;
        } else if (RegExp(r'^[a-z]{4,}$').hasMatch(token)) {
          _englishEvidence += 1;
        }
      }
    }

    // Keep sliding evidence bounded so mid-recording language switches adapt fast.
    if (_hindiEvidence + _englishEvidence > 30) {
      _hindiEvidence = (_hindiEvidence * 0.7).round();
      _englishEvidence = (_englishEvidence * 0.7).round();
    }

    if (_hindiEvidence == 0 && _englishEvidence == 0) {
      _detected = SpokenLanguage.unknown;
    } else if (_hindiEvidence >= 3 && _englishEvidence >= 3) {
      _detected = SpokenLanguage.hinglish;
    } else if (_hindiEvidence > _englishEvidence) {
      _detected = SpokenLanguage.hindi;
    } else {
      _detected = SpokenLanguage.english;
    }

    return _detected;
  }

  /// Infers initial preferred ASR locales directly from the script content
  /// itself + the user's language setting so auto-detection starts hot on word 1.
  static List<String> inferPreferredLocales({
    required String scriptText,
    required String languagePreference,
  }) {
    final detector = SpokenLanguageDetector();
    final scriptLang = detector.observe(text: scriptText);

    if (scriptLang == SpokenLanguage.hindi ||
        languagePreference.toLowerCase() == 'hi') {
      return const ['hi-IN', 'en-IN', 'en-US'];
    }
    if (scriptLang == SpokenLanguage.hinglish ||
        languagePreference.toLowerCase() == 'hinglish') {
      return const ['en-IN', 'hi-IN', 'en-US'];
    }
    return const ['en-US', 'en-IN', 'hi-IN'];
  }
}
