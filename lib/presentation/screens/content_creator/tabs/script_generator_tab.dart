import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/datasources/remote/supabase_language_datasource.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../../domain/entities/onboarding_data.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';
import '../content_creator_screen.dart';

/// Tab for generating new scripts using AI.
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

  String _selectedTone = 'Casual';
  LanguageOption? _selectedLanguage;
  List<LanguageOption> _languageOptions = [];
  bool _isLoadingLanguages = true;
  PromptTemplate _selectedTemplate = PromptTemplate.tips;
  final _customPromptController = TextEditingController();

  final List<String> _toneOptions = [
    'Casual',
    'Professional',
    'Inspirational',
    'Humorous',
    'Educational',
  ];

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

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContentCreatorBloc, ContentCreatorState>(
      listener: (context, state) {
        if (state is ScriptGenerated) {
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _toneOptions.map((tone) {
                        final isSelected = _selectedTone == tone;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTone = tone),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.olivePillFill
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryOlive
                                    : AppColors.divider,
                                width: isSelected ? 1.6 : 1.1,
                              ),
                            ),
                            child: Text(
                              tone,
                              style: AppTypography.bodyStrong(
                                fontSize: 13.5,
                                color: isSelected
                                    ? AppColors.primaryOlive
                                    : AppColors.primaryText,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                                        setState(
                                          () => _selectedLanguage = value,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
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
                  final isGenerating = state is ScriptGenerating;

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isGenerating ? null : _generateScript,
                      icon: isGenerating
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : Icon(Icons.auto_awesome_outlined, size: 19),
                      label: Text(
                        isGenerating ? 'Generating...' : 'Generate Script',
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
                      'Prefer to write your own? Create a custom 3-part teleprompter script from scratch.',
                      style: AppTypography.body(fontSize: 13.5),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCustomScriptDialog(context),
                        icon: Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.secondaryGreen,
                        ),
                        label: Text('Create Custom Script'),
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
            if (value == null || value.isEmpty) {
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
            color:
                isSelected ? AppColors.olivePillFill : AppColors.cardSurface,
            borderRadius: AppRadii.cardBorder,
            border: Border.all(
              color:
                  isSelected ? AppColors.primaryOlive : AppColors.divider,
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
                    color: isSelected
                        ? AppColors.primaryOlive
                        : AppColors.secondaryText,
                    width: 1.6,
                  ),
                  color: isSelected
                      ? AppColors.primaryOlive
                      : AppColors.background,
                ),
                child: isSelected
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
        SnackBar(
          content: Text('Please wait for languages to load'),
        ),
      );
      return;
    }

    context.read<ContentCreatorBloc>().add(
          GenerateScript(
            userId: widget.userId,
            topic: _topicController.text,
            audience: _audienceController.text,
            message: _messageController.text,
            tone: _selectedTone,
            language: _selectedLanguage!.name,
            template: _selectedTemplate,
            customPrompt: _selectedTemplate == PromptTemplate.custom
                ? _customPromptController.text
                : null,
          ),
        );
  }

  void _showScriptDialog(BuildContext context, ContentScript script) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.secondaryGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Script Generated!',
                style: AppTypography.headingMedium(fontSize: 19),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                script.title,
                style: AppTypography.sectionTitle(
                  color: AppColors.primaryOlive,
                ),
              ),
              const SizedBox(height: 12),
              SageCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  script.fullScript.replaceAll('**', ''),
                  style: AppTypography.body(color: AppColors.primaryText),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<ContentCreatorBloc>()
                  .add(LoadScripts(widget.userId));
              ContentCreatorTabController.of(context)?.switchToTab(1);
            },
            child: Text('View in My Scripts'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ContentCreatorBloc>().add(SelectScript(script));
              ContentCreatorTabController.of(context)?.switchToTab(2);
            },
            child: Text('Record Now'),
          ),
        ],
      ),
    );
  }

  void _showCustomScriptDialog(BuildContext context) {
    final titleController = TextEditingController();
    final hookController = TextEditingController();
    final bodyController = TextEditingController();
    final closeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
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
                  Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primaryOlive,
                  ),
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
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Write your own 3-part script for the teleprompter',
                style: AppTypography.body(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('SCRIPT TITLE'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        style: AppTypography.bodyStrong(),
                        decoration: InputDecoration(
                          hintText: 'e.g., My Morning Routine Tips',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('PART 1: HOOK / OPENING (20–40 WORDS)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: hookController,
                        style: AppTypography.bodyStrong(),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Start with a hook that grabs attention...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('PART 2: CONTENT / BODY (80–150 WORDS)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bodyController,
                        style: AppTypography.bodyStrong(),
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: 'Deliver your main value here...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('PART 3: CLOSE / ENDING (20–40 WORDS)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: closeController,
                        style: AppTypography.bodyStrong(),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'End with **key takeaway**...',
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
                            _buildMarkdownTip('• or -', 'Bullet point for lists'),
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
                    if (titleController.text.isEmpty ||
                        hookController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please fill in title and at least the hook',
                          ),
                        ),
                      );
                      return;
                    }

                    final now = DateTime.now();
                    final script = ContentScript(
                      id: now.millisecondsSinceEpoch.toString(),
                      userId: widget.userId,
                      title: titleController.text,
                      part1: hookController.text,
                      part2: bodyController.text,
                      part3: closeController.text,
                      promptTemplate: 'custom',
                      questionnaire: null,
                      createdAt: now,
                      updatedAt: now,
                    );

                    context.read<ContentCreatorBloc>().add(SaveScript(script));
                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Custom script saved! Check My Scripts tab.',
                        ),
                      ),
                    );

                    context
                        .read<ContentCreatorBloc>()
                        .add(LoadScripts(widget.userId));
                  },
                  icon: Icon(Icons.save_outlined),
                  label: Text('Save Script'),
                ),
              ),
            ],
          ),
        ),
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
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            code,
            style: GoogleFonts.manrope(
              color: AppColors.primaryOlive,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: AppTypography.body(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
