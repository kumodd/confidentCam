import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/spoken_language_detector.dart';
import '../../../../data/datasources/remote/supabase_language_datasource.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../../domain/entities/onboarding_data.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';
import '../content_creator_screen.dart';

/// Tab for generating new scripts using AI or creating a custom 3-part script.
class ScriptGeneratorTab extends StatefulWidget {
  final String userId;

  const ScriptGeneratorTab({super.key, required this.userId});

  @override
  State<ScriptGeneratorTab> createState() => _ScriptGeneratorTabState();
}

class _ScriptGeneratorTabState extends State<ScriptGeneratorTab> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _audienceController = TextEditingController();
  final _messageController = TextEditingController();
  final _customPromptController = TextEditingController();

  String _selectedTone = 'Casual';
  String _selectedLength = 'medium';
  String _selectedPlatform = 'reels_shorts';
  bool _romanizedScript = false;
  LanguageOption? _selectedLanguage;
  List<LanguageOption> _languageOptions = [];
  bool _isLoadingLanguages = true;
  PromptTemplate _selectedTemplate = PromptTemplate.tips;

  static const List<String> _toneOptions = [
    'Casual',
    'Professional',
    'Inspirational',
    'Humorous',
    'Educational',
  ];

  static const Map<String, String> _lengthOptions = {
    'short': 'Short (30-45s)',
    'medium': 'Medium (60-90s)',
    'long': 'Long (2-3 min)',
  };

  static const Map<String, String> _platformOptions = {
    'reels_shorts': 'Reels / Shorts',
    'youtube': 'YouTube',
    'linkedin': 'LinkedIn',
    'general': 'General',
  };

  @override
  void initState() {
    super.initState();
    _loadLanguageOptions();
  }

  Future<void> _loadLanguageOptions() async {
    try {
      final languageDataSource = sl<SupabaseLanguageDataSource>();
      final options = await languageDataSource.getLanguageOptions();

      if (mounted) {
        setState(() {
          _languageOptions = options;
          _selectedLanguage = options.isNotEmpty ? options.first : null;
          _isLoadingLanguages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLanguages = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _audienceController.dispose();
    _messageController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  bool get _canRomanizeLanguage {
    final lang = _selectedLanguage;
    if (lang == null) return false;
    final code = lang.code.toLowerCase();
    return code != 'en' && !lang.isBilingual && code != 'hinglish' && code != 'tanglish';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContentCreatorBloc, ContentCreatorState>(
      listener: (context, state) {
        if (state is IdeaEnhanced) {
          final idea = state.idea;
          setState(() {
            _topicController.text = idea.topic;
            _audienceController.text = idea.audience;
            _messageController.text = idea.coreMessage;
            _selectedTemplate = idea.suggestedTemplate;
            if (_toneOptions.contains(idea.suggestedTone)) {
              _selectedTone = idea.suggestedTone;
            }
            if (_lengthOptions.containsKey(idea.suggestedLength)) {
              _selectedLength = idea.suggestedLength;
            }
            if (_platformOptions.containsKey(idea.suggestedPlatform)) {
              _selectedPlatform = idea.suggestedPlatform;
            }
            // Automatically sync the form language selector to the detected spoken language
            final detectedCode = idea.detectedLanguageCode.toLowerCase();
            final matchedLang = _languageOptions.cast<LanguageOption?>().firstWhere(
              (o) =>
                  o != null &&
                  (o.code.toLowerCase() == detectedCode ||
                      o.name.toLowerCase() ==
                          idea.detectedLanguageName.toLowerCase()),
              orElse: () => null,
            );
            if (matchedLang != null) {
              _selectedLanguage = matchedLang;
            }
            _romanizedScript = idea.detectedScriptStyle == 'romanized';
          });
          if (!state.autoGenerating) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Detected ${idea.detectedLanguageName} • Voice idea structured! Review or tap Generate Script.',
                ),
              ),
            );
          }
        } else if (state is ScriptGenerated) {
          _showScriptDialog(context, state.script);
        } else if (state is ContentCreatorError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Voice-to-Script STT Quick Card
              _buildVoiceToScriptCard(context),
              const SizedBox(height: 14),

              SageCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: AppColors.primaryOlive,
                          size: 20,
                        ),
                        Text(
                          'AI SCRIPT GENERATOR',
                          style: AppTypography.uppercaseLabel(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1.2, color: AppColors.divider),
                    const SizedBox(height: 16),
                    Text(
                      'Generate Your Script',
                      style: AppTypography.headingMedium(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Answer a few questions and let AI create your teleprompter script',
                      style: AppTypography.body(fontSize: 13.5),
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _topicController,
                      label: 'WHAT IS THIS VIDEO ABOUT?',
                      hint: 'e.g., 5 productivity tips for remote workers',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _audienceController,
                      label: 'WHO IS YOUR TARGET AUDIENCE?',
                      hint: 'e.g., Young professionals, students, founders',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _messageController,
                      label: 'WHAT IS YOUR KEY MESSAGE?',
                      hint: 'e.g., Small daily habits lead to big results',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SageCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('SELECT YOUR TONE'),
                    const SizedBox(height: 10),
                    _buildChipSelector(
                      options: {for (final t in _toneOptions) t: t},
                      selectedKey: _selectedTone,
                      onSelected: (v) => setState(() => _selectedTone = v),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildLabel('VIDEO LENGTH'),
                    const SizedBox(height: 10),
                    _buildChipSelector(
                      options: _lengthOptions,
                      selectedKey: _selectedLength,
                      onSelected: (v) => setState(() => _selectedLength = v),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildLabel('PLATFORM'),
                    const SizedBox(height: 10),
                    _buildChipSelector(
                      options: _platformOptions,
                      selectedKey: _selectedPlatform,
                      onSelected: (v) => setState(() => _selectedPlatform = v),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildLabel('SCRIPT LANGUAGE'),
                    const SizedBox(height: 10),
                    _isLoadingLanguages
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: AppRadii.inputBorder,
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryOlive,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading languages...',
                                  style: AppTypography.body(),
                                ),
                              ],
                            ),
                          )
                        : _languageOptions.isEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: AppRadii.inputBorder,
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Text(
                                  'No languages available',
                                  style: AppTypography.body(),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: AppRadii.inputBorder,
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<LanguageOption>(
                                    value: _selectedLanguage,
                                    isExpanded: true,
                                    dropdownColor: AppColors.background,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.secondaryText,
                                    ),
                                    style: AppTypography.bodyStrong(),
                                    items: _languageOptions.map((lang) {
                                      return DropdownMenuItem<LanguageOption>(
                                        value: lang,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.language_rounded,
                                              color: AppColors.primaryOlive,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '${lang.name} (${lang.nativeName})',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedLanguage = value;
                                          if (!_canRomanizeLanguage) {
                                            _romanizedScript = false;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                    if (_canRomanizeLanguage) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Write in English letters (Romanized)',
                                  style: AppTypography.bodyStrong(fontSize: 13),
                                ),
                                Text(
                                  'Easier to read on teleprompter in ${_selectedLanguage!.name}',
                                  style: AppTypography.body(fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _romanizedScript,
                            activeThumbColor: AppColors.secondaryGreen,
                            activeTrackColor: AppColors.navPill,
                            onChanged: (v) => setState(() => _romanizedScript = v),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SageSectionHeader(title: 'CHOOSE A SCRIPT TEMPLATE'),
              const SizedBox(height: 6),
              ...PromptTemplate.values.map(_buildTemplateCard),

              if (_selectedTemplate == PromptTemplate.custom) ...[
                const SizedBox(height: 12),
                SageCard(
                  padding: const EdgeInsets.all(18),
                  child: _buildTextField(
                    controller: _customPromptController,
                    label: 'CUSTOM PROMPT INSTRUCTIONS',
                    hint: 'Add any specific instructions for the AI...',
                    maxLines: 3,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
                builder: (context, state) {
                  final isEnhancing = state is IdeaEnhancing;
                  final isGenerating = state is ScriptGenerating;
                  final isBusy = isEnhancing || isGenerating;

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isBusy ? null : _generateScript,
                      icon: isBusy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_outlined, size: 19),
                      label: Text(
                        isEnhancing
                            ? 'Structuring your idea...'
                            : isGenerating
                                ? 'Writing your script...'
                                : 'Generate Script',
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 22),

              SageCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Write Your Own Script',
                      style: AppTypography.sectionTitle(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prefer to write your own? Add a title and script for the teleprompter.',
                      style: AppTypography.body(fontSize: 13.5),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCustomScriptSheet(context),
                        icon: Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.secondaryGreen,
                        ),
                        label: const Text('Create Custom Script'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceToScriptCard(BuildContext context) {
    return BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
      builder: (context, state) {
        final isEnhancing = state is IdeaEnhancing;
        final isGenerating = state is ScriptGenerating;
        final isBusy = isEnhancing || isGenerating;

        return SageCard(
          padding: const EdgeInsets.all(18),
          borderColor: AppColors.olivePillBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOlive,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFFF7F8F0),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Speak Your Idea',
                                style: AppTypography.sectionTitle(fontSize: 16.5),
                              ),
                            ),
                            const OlivePillBadge(label: 'Auto-Lang AI'),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEnhancing
                              ? 'Detecting language & structuring your idea...'
                              : isGenerating
                                  ? 'Writing your polished teleprompter script...'
                                  : 'Speak in any language — AI detects it, expands your idea, and writes the script.',
                          style: AppTypography.body(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : () => _showVoiceIdeaSheet(context),
                  icon:
                      isBusy
                          ? SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                          : const Icon(Icons.graphic_eq_rounded, size: 19),
                  label: Text(
                    isEnhancing
                        ? 'Enhancing Voice Brief...'
                        : isGenerating
                            ? 'Generating Script...'
                            : 'Tap to Speak Idea',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVoiceIdeaSheet(BuildContext context) {
    final bloc = context.read<ContentCreatorBloc>();
    final lang = _selectedLanguage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (_) => BlocProvider.value(
            value: bloc,
            child: _VoiceIdeaSheet(
              userId: widget.userId,
              fallbackLanguageCode: lang?.code ?? 'en',
              toneHint: _selectedTone,
              lengthHint: _selectedLength,
              platformHint: _selectedPlatform,
            ),
          ),
    );
  }

  Widget _buildChipSelector({
    required Map<String, String> options,
    required String selectedKey,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) {
        final isSelected = selectedKey == entry.key;
        return GestureDetector(
          onTap: () => onSelected(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.olivePillFill : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primaryOlive : AppColors.divider,
                width: isSelected ? 1.6 : 1.1,
              ),
            ),
            child: Text(
              entry.value,
              style: AppTypography.bodyStrong(
                fontSize: 13,
                color:
                    isSelected
                        ? AppColors.primaryOlive
                        : AppColors.primaryText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.uppercaseLabel(
        fontSize: 11,
        color: AppColors.secondaryText,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.bodyStrong(),
          decoration: InputDecoration(
            hintText: hint,
            fillColor: AppColors.background,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTemplateCard(PromptTemplate template) {
    final isSelected = _selectedTemplate == template;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedTemplate = template),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.olivePillFill : AppColors.cardSurface,
            borderRadius: AppRadii.cardBorder,
            border: Border.all(
              color: isSelected ? AppColors.primaryOlive : AppColors.divider,
              width: isSelected ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected
                            ? AppColors.primaryOlive
                            : AppColors.secondaryText,
                    width: 1.6,
                  ),
                  color:
                      isSelected
                          ? AppColors.primaryOlive
                          : AppColors.background,
                ),
                child:
                    isSelected
                        ? Icon(
                          Icons.check_rounded,
                          color: AppColors.background,
                          size: 14,
                        )
                        : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.displayName,
                      style: AppTypography.bodyStrong(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      template.description,
                      style: AppTypography.body(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateScript() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for languages to load')),
      );
      return;
    }

    context.read<ContentCreatorBloc>().add(
      GenerateScript(
        userId: widget.userId,
        topic: _topicController.text.trim(),
        audience: _audienceController.text.trim(),
        message: _messageController.text.trim(),
        tone: _selectedTone,
        language: _selectedLanguage!.name,
        languageCode: _selectedLanguage!.code,
        template: _selectedTemplate,
        length: _selectedLength,
        platform: _selectedPlatform,
        scriptStyle: _romanizedScript ? 'romanized' : 'spoken_natural',
        customPrompt:
            _selectedTemplate == PromptTemplate.custom
                ? _customPromptController.text.trim()
                : null,
      ),
    );
  }

  void _showScriptDialog(BuildContext context, ContentScript initialScript) {
    final bloc = context.read<ContentCreatorBloc>();
    final tabController = ContentCreatorTabController.of(context);

    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _GeneratedScriptDialog(
          initialScript: initialScript,
          userId: widget.userId,
          tabController: tabController,
        ),
      ),
    );
  }

  void _showCustomScriptSheet(BuildContext context) {
    final bloc = context.read<ContentCreatorBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _CustomScriptSheet(userId: widget.userId),
      ),
    );
  }
}

/// Interactive preview dialog for an AI-generated script supporting:
/// - Switching between the 3 generated Hook Alternatives
/// - One-tap AI Refine (`Punchier Hook`, `Shorter`, `More Casual`, `Add Example`)
/// - Immediate Record or View in Library
class _GeneratedScriptDialog extends StatefulWidget {
  final ContentScript initialScript;
  final String userId;
  final ContentCreatorTabController? tabController;

  const _GeneratedScriptDialog({
    required this.initialScript,
    required this.userId,
    required this.tabController,
  });

  @override
  State<_GeneratedScriptDialog> createState() => _GeneratedScriptDialogState();
}

class _GeneratedScriptDialogState extends State<_GeneratedScriptDialog> {
  late ContentScript _script;
  bool _isRefining = false;

  static const Map<String, String> _refineActions = {
    'punchier_hook': 'Punchier Hook',
    'shorter': 'Shorter',
    'more_casual': 'More Casual',
    'add_example': 'Add Example',
  };

  @override
  void initState() {
    super.initState();
    _script = widget.initialScript;
  }

  String _formatDurationMeta(ContentScript script) {
    final words = script.wordCount;
    final secs = script.estimatedSeconds;
    if (words == null || secs == null) return '';
    final mins = secs ~/ 60;
    final rem = secs % 60;
    final timeStr = mins > 0 ? '${mins}m ${rem}s' : '${secs}s';
    return '$words words • ~$timeStr';
  }

  void _selectHook(String hook) {
    if (hook == _script.part1) return;
    final updated = _script.copyWith(part1: hook);
    setState(() => _script = updated);
    context.read<ContentCreatorBloc>().add(UpdateScript(updated));
  }

  @override
  Widget build(BuildContext context) {
    final hooks = _script.hookAlternatives;
    final metaLabel = _formatDurationMeta(_script);

    return BlocListener<ContentCreatorBloc, ContentCreatorState>(
      listener: (context, state) {
        if (state is ScriptRefining) {
          setState(() => _isRefining = true);
        } else if (state is ScriptRefined) {
          setState(() {
            _script = state.script;
            _isRefining = false;
          });
        } else if (state is ContentCreatorError && _isRefining) {
          setState(() => _isRefining = false);
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.secondaryGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Script Ready!',
                style: AppTypography.headingMedium(fontSize: 19),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _script.title,
                  style: AppTypography.sectionTitle(
                    color: AppColors.primaryOlive,
                    fontSize: 16,
                  ),
                ),
                if (metaLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    metaLabel,
                    style: AppTypography.body(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
                if (hooks.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    'HOOK OPTIONS',
                    style: AppTypography.uppercaseLabel(
                      fontSize: 10.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(hooks.length, (idx) {
                      final isSelected = hooks[idx] == _script.part1;
                      return GestureDetector(
                        onTap: _isRefining ? null : () => _selectHook(hooks[idx]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppColors.primaryOlive
                                    : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppColors.primaryOlive
                                      : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            'Hook ${idx + 1}',
                            style: AppTypography.bodyStrong(
                              fontSize: 11.5,
                              color:
                                  isSelected
                                      ? const Color(0xFFF7F8F0)
                                      : AppColors.primaryText,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                SageCard(
                  padding: const EdgeInsets.all(14),
                  child:
                      _isRefining
                          ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primaryOlive,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Refining script...',
                                    style: AppTypography.body(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : Text(
                            _script.fullScript.replaceAll('**', ''),
                            style: AppTypography.body(
                              color: AppColors.primaryText,
                            ),
                          ),
                ),
                const SizedBox(height: 12),
                Text(
                  'QUICK REFINE',
                  style: AppTypography.uppercaseLabel(
                    fontSize: 10.5,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _refineActions.entries.map((entry) {
                    return ActionChip(
                      label: Text(
                        entry.value,
                        style: AppTypography.bodyStrong(fontSize: 11.5),
                      ),
                      backgroundColor: AppColors.background,
                      side: BorderSide(color: AppColors.divider),
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          _isRefining
                              ? null
                              : () {
                                context.read<ContentCreatorBloc>().add(
                                  RefineScript(
                                    script: _script,
                                    instruction: entry.key,
                                  ),
                                );
                              },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _isRefining
                    ? null
                    : () {
                      Navigator.pop(context);
                      context.read<ContentCreatorBloc>().add(
                        LoadScripts(widget.userId),
                      );
                      widget.tabController?.switchToTab(1);
                    },
            child: const Text('My Scripts'),
          ),
          ElevatedButton(
            onPressed:
                _isRefining
                    ? null
                    : () {
                      Navigator.pop(context);
                      context.read<ContentCreatorBloc>().add(
                        SelectScript(_script),
                      );
                      widget.tabController?.switchToTab(2);
                    },
            child: const Text('Record Now'),
          ),
        ],
      ),
    );
  }
}

/// Properly lifecycle-managed modal sheet for writing a custom 3-part script
/// (disposes all controllers and generates valid Postgres UUID v4 IDs).
class _CustomScriptSheet extends StatefulWidget {
  final String userId;

  const _CustomScriptSheet({required this.userId});

  @override
  State<_CustomScriptSheet> createState() => _CustomScriptSheetState();
}

class _CustomScriptSheetState extends State<_CustomScriptSheet> {
  final _titleController = TextEditingController();
  final _scriptController = TextEditingController();
  static const _uuid = Uuid();

  @override
  void dispose() {
    _titleController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.uppercaseLabel(
        fontSize: 11,
        color: AppColors.secondaryText,
      ),
    );
  }

  Widget _buildMarkdownTip(String code, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            code,
            style: GoogleFonts.inter(
              color: AppColors.primaryOlive,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(description, style: AppTypography.body(fontSize: 12.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final words =
        _scriptController.text
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
    final estSec = words == 0 ? 0 : ((words / 140) * 60).round().clamp(5, 3600);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.primaryOlive),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create Custom Script',
                    style: AppTypography.headingMedium(fontSize: 20),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.secondaryText,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Write or paste your script for the teleprompter',
              style: AppTypography.body(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('TITLE'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: AppTypography.bodyStrong(),
                      decoration: const InputDecoration(
                        hintText: 'e.g., My Morning Routine Tips',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('SCRIPT'),
                        if (words > 0)
                          OlivePillBadge(label: '$words words • ~${estSec}s'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _scriptController,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.bodyStrong(),
                      minLines: 8,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        hintText:
                            'Write or paste your full teleprompter script here...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SageCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tips_and_updates_outlined,
                                color: AppColors.primaryOlive,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'MARKDOWN TIPS',
                                style: AppTypography.uppercaseLabel(
                                  color: AppColors.primaryOlive,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildMarkdownTip('**word**', 'Bold highlighted text'),
                          const SizedBox(height: 6),
                          _buildMarkdownTip('...', 'Pause while speaking'),
                          const SizedBox(height: 6),
                          _buildMarkdownTip(
                            '- or •',
                            'Bullet point for lists',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final title = _titleController.text.trim();
                  final scriptBody = _scriptController.text.trim();
                  if (title.isEmpty || scriptBody.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter both a title and script'),
                      ),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  final script = ContentScript(
                    id: _uuid.v4(),
                    userId: widget.userId,
                    title: title,
                    part1: scriptBody,
                    part2: '',
                    part3: '',
                    promptTemplate: 'custom',
                    questionnaire: null,
                    createdAt: now,
                    updatedAt: now,
                  );

                  // SaveScript internally triggers LoadScripts once persisted
                  context.read<ContentCreatorBloc>().add(SaveScript(script));
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Custom script saved! Check My Scripts tab.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Script'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that captures a short spoken video idea via on-device STT,
/// automatically detects the spoken language from the voice/transcript,
/// and triggers AI brief expansion + full script generation in that language.
class _VoiceIdeaSheet extends StatefulWidget {
  final String userId;
  final String fallbackLanguageCode;
  final String toneHint;
  final String lengthHint;
  final String platformHint;

  const _VoiceIdeaSheet({
    required this.userId,
    required this.fallbackLanguageCode,
    required this.toneHint,
    required this.lengthHint,
    required this.platformHint,
  });

  @override
  State<_VoiceIdeaSheet> createState() => _VoiceIdeaSheetState();
}

class _VoiceIdeaSheetState extends State<_VoiceIdeaSheet> {
  final SpeechToText _stt = SpeechToText();
  final TextEditingController _transcriptController = TextEditingController();
  Timer? _elapsedTimer;

  bool _isListening = false;
  bool _sttInitialized = false;
  int _elapsedSeconds = 0;
  String? _statusMessage;
  String _detectedLanguageBadge = 'Auto-Detect';

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _stt.stop();
    _transcriptController.dispose();
    super.dispose();
  }

  void _refreshDetectedLanguageBadge() {
    final detected = SpokenLanguageDetector.detectTranscriptLanguage(
      _transcriptController.text,
    );
    _detectedLanguageBadge = detected.name;
  }

  String _sttLocaleForAutoCapture() {
    switch (widget.fallbackLanguageCode.toLowerCase()) {
      case 'hi':
        return 'hi_IN';
      case 'ta':
      case 'tanglish':
        return 'ta_IN';
      case 'te':
        return 'te_IN';
      case 'mr':
        return 'mr_IN';
      case 'bn':
        return 'bn_IN';
      case 'gu':
        return 'gu_IN';
      case 'kn':
        return 'kn_IN';
      case 'ml':
        return 'ml_IN';
      case 'pa':
        return 'pa_IN';
      default:
        // en_IN handles both pure English and Romanized Hindi/Hinglish speech
        // accurately without truncating Hinglish words.
        return 'en_IN';
    }
  }

  Future<void> _startListening() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Microphone permission is required for voice-to-script.';
        });
      }
      return;
    }

    if (!_sttInitialized) {
      _sttInitialized = await _stt.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            _elapsedTimer?.cancel();
            setState(() => _isListening = false);
          }
        },
        onError: (err) {
          if (!mounted) return;
          _elapsedTimer?.cancel();
          setState(() {
            _isListening = false;
            _statusMessage = 'Tap the mic to try again (${err.errorMsg}).';
          });
        },
      );
    }

    if (!_sttInitialized) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Speech recognition unavailable on this device. You can type your rough idea below.';
        });
      }
      return;
    }

    setState(() {
      _isListening = true;
      _elapsedSeconds = 0;
      _statusMessage = 'Listening... speak in any language (EN / Hindi / Hinglish)';
    });

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isListening) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
    });

    final basePrefix =
        _transcriptController.text.trim().isNotEmpty
            ? '${_transcriptController.text.trim()} '
            : '';

    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: _sttLocaleForAutoCapture(),
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) {
        if (!mounted) return;
        final spoken = result.recognizedWords.trim();
        if (spoken.isNotEmpty) {
          setState(() {
            _transcriptController.text = '$basePrefix$spoken';
            _transcriptController.selection = TextSelection.collapsed(
              offset: _transcriptController.text.length,
            );
            _refreshDetectedLanguageBadge();
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    _elapsedTimer?.cancel();
    await _stt.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _refreshDetectedLanguageBadge();
        _statusMessage =
            _transcriptController.text.trim().isNotEmpty
                ? 'Detected $_detectedLanguageBadge • AI will structure & script it.'
                : 'Tap the mic and speak your video idea.';
      });
    }
  }

  void _submit({required bool autoGenerate}) {
    final transcript = _transcriptController.text.trim();
    if (transcript.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please speak or enter a brief video idea first.'),
        ),
      );
      return;
    }
    _stopListening();
    final detected = SpokenLanguageDetector.detectTranscriptLanguage(transcript);
    context.read<ContentCreatorBloc>().add(
      EnhanceSpokenIdea(
        userId: widget.userId,
        transcript: transcript,
        language: detected.name,
        // Always pass 'auto' so the AI backend inspects the transcript itself
        // and generates the brief & script in the true spoken language.
        languageCode: 'auto',
        scriptStyle: detected.scriptStyle,
        toneHint: widget.toneHint,
        lengthHint: widget.lengthHint,
        platformHint: widget.platformHint,
        autoGenerate: autoGenerate,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasTranscript = _transcriptController.text.trim().length >= 3;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.mic_rounded, color: AppColors.primaryOlive),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voice-to-Script',
                    style: AppTypography.headingMedium(fontSize: 19),
                  ),
                ),
                OlivePillBadge(label: _detectedLanguageBadge),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.secondaryText,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _statusMessage ??
                  'Speak in any language — AI detects it, enhances your brief, and writes the script.',
              style: AppTypography.body(fontSize: 13),
            ),
            const SizedBox(height: 18),

            // Animated tap-to-listen mic button
            Center(
              child: Column(
                children: [
                  Semantics(
                    label: _isListening ? 'Stop Listening' : 'Start Listening',
                    button: true,
                    child: GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isListening ? 86 : 74,
                        height: _isListening ? 86 : 74,
                        decoration: BoxDecoration(
                          color:
                              _isListening
                                  ? AppColors.error
                                  : AppColors.primaryOlive,
                          shape: BoxShape.circle,
                          boxShadow:
                              _isListening
                                  ? [
                                    BoxShadow(
                                      color: AppColors.error.withValues(
                                        alpha: 0.32,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 6,
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: const Color(0xFFF7F8F0),
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isListening
                        ? 'Listening • ${_elapsedSeconds}s (tap to stop)'
                        : 'Tap mic to speak',
                    style: AppTypography.bodyStrong(
                      fontSize: 12.5,
                      color:
                          _isListening
                              ? AppColors.error
                              : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CAPTURED IDEA (EDITABLE)',
                  style: AppTypography.uppercaseLabel(
                    fontSize: 10.5,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (_transcriptController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _transcriptController.clear();
                        _refreshDetectedLanguageBadge();
                      });
                    },
                    child: Text(
                      'Clear',
                      style: AppTypography.bodyStrong(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _transcriptController,
              maxLines: 4,
              onChanged: (_) => setState(_refreshDetectedLanguageBadge),
              style: AppTypography.bodyStrong(fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    'e.g., "ChatGPT kaise kaam karta hai" or "3 tips to beat camera shyness"',
                fillColor: AppColors.cardSurface,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    hasTranscript ? () => _submit(autoGenerate: true) : null,
                icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                label: const Text('Enhance & Generate Script'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    hasTranscript ? () => _submit(autoGenerate: false) : null,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Fill Enhanced Brief Only'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
