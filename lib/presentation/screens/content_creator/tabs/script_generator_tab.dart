import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../data/datasources/remote/supabase_language_datasource.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../../domain/entities/onboarding_data.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';

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
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                '✨ Generate Your Script',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 8),
              Text(
                'Answer a few questions and let AI create your script',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),

              // Questionnaire
              _buildTextField(
                controller: _topicController,
                label: 'What is this video about?',
                hint: 'e.g., 5 productivity tips for remote workers',
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _audienceController,
                label: 'Who is your target audience?',
                hint: 'e.g., Young professionals, students, entrepreneurs',
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _messageController,
                label: 'What is your key message?',
                hint: 'e.g., Small daily habits lead to big results',
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Tone selector
              _buildLabel('Select your tone'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _toneOptions.map((tone) {
                      final isSelected = _selectedTone == tone;
                      return ChoiceChip(
                        label: Text(tone),
                        selected: isSelected,
                        selectedColor: const Color(0xFFEC4899),
                        backgroundColor: const Color(0xFF2D2D3D),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedTone = tone);
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              // Language selector
              _buildLabel('Script Language'),
              const SizedBox(height: 8),
              _isLoadingLanguages
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D3D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEC4899))),
                          SizedBox(width: 12),
                          Text('Loading languages...', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : _languageOptions.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D3D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('No languages available', style: TextStyle(color: Colors.white54)),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D3D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<LanguageOption>(
                              value: _selectedLanguage,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2D2D3D),
                              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFEC4899)),
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              items: _languageOptions.map((lang) {
                                return DropdownMenuItem<LanguageOption>(
                                  value: lang,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.language, color: Color(0xFFEC4899), size: 18),
                                      const SizedBox(width: 12),
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
                                if (value != null) setState(() => _selectedLanguage = value);
                              },
                            ),
                          ),
                        ),
              const SizedBox(height: 24),

              // Template selector
              _buildLabel('Choose a script template'),
              const SizedBox(height: 12),
              ...PromptTemplate.values.map(_buildTemplateCard),
              const SizedBox(height: 16),

              // Custom prompt (optional, shown for Custom template)
              if (_selectedTemplate == PromptTemplate.custom) ...[
                _buildTextField(
                  controller: _customPromptController,
                  label: 'Custom prompt instructions',
                  hint: 'Add any specific instructions for the AI...',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
              ],

              // Generate button
              BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
                builder: (context, state) {
                  final isGenerating = state is ScriptGenerating;

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isGenerating ? null : _generateScript,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          isGenerating
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Generating...'),
                                ],
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome),
                                  SizedBox(width: 8),
                                  Text(
                                    'Generate Script',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Divider with "OR"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 24),

              // Custom script creation button
              Text(
                '✍️ Write Your Own Script',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Prefer to write your own? Create a custom script from scratch.',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCustomScriptDialog(context),
                  icon: const Icon(Icons.edit_note, color: Color(0xFF8B5CF6)),
                  label: const Text(
                    'Create Custom Script',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 14,
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
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: const Color(0xFF2D2D3D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEC4899)),
            ),
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

    return GestureDetector(
      onTap: () => setState(() => _selectedTemplate = template),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFFEC4899).withOpacity(0.2)
                  : const Color(0xFF2D2D3D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFEC4899) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFEC4899) : Colors.white38,
                  width: 2,
                ),
                color:
                    isSelected ? const Color(0xFFEC4899) : Colors.transparent,
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateScript() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for languages to load'), backgroundColor: Colors.orange),
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
        customPrompt:
            _selectedTemplate == PromptTemplate.custom
                ? _customPromptController.text
                : null,
      ),
    );
  }

  void _showScriptDialog(BuildContext context, ContentScript script) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Script Generated!',
                    style: TextStyle(color: Colors.white),
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
                    style: const TextStyle(
                      color: Color(0xFFEC4899),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D3D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      script.fullScript,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<ContentCreatorBloc>().add(
                    LoadScripts(widget.userId),
                  );
                },
                child: const Text('View in My Scripts'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Navigate to record tab (index 2)
                  // This would require a callback or state management
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                ),
                child: const Text('Record Now'),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Create Custom Script',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Write your own 3-part script for the teleprompter',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              
              // Form
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text('Script Title', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g., My Morning Routine Tips',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: const Color(0xFF2D2D3D),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Hook
                      const Text('Part 1: Hook/Opening', style: TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Grab attention (20-40 words)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: hookController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Start with a hook that grabs attention...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: const Color(0xFF2D2D3D),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Body
                      const Text('Part 2: Content/Body', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Main content (80-150 words)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bodyController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: 'Deliver your main value here...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: const Color(0xFF2D2D3D),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Close
                      const Text('Part 3: Close/Ending', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('End with impact (20-40 words)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: closeController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'End with **key takeaway**...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: const Color(0xFF2D2D3D),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Markdown Tips Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tips_and_updates, color: Color(0xFF8B5CF6), size: 18),
                                SizedBox(width: 8),
                                Text('💡 Markdown Tips', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildMarkdownTip('**word**', 'Bold text (highlights yellow)'),
                            const SizedBox(height: 6),
                            _buildMarkdownTip('...', 'Pause while speaking'),
                            const SizedBox(height: 6),
                            _buildMarkdownTip('• or -', 'Bullet point for lists'),
                            const SizedBox(height: 6),
                            _buildMarkdownTip('\\n', 'Line break'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (titleController.text.isEmpty || hookController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in title and at least the hook'), backgroundColor: Colors.orange),
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
                      const SnackBar(
                        content: Text('Custom script saved! Check My Scripts tab.'),
                        backgroundColor: Color(0xFF22C55E),
                      ),
                    );
                    
                    // Reload scripts
                    context.read<ContentCreatorBloc>().add(LoadScripts(widget.userId));
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Script', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            code,
            style: const TextStyle(
              color: Color(0xFFFBBF24),
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
