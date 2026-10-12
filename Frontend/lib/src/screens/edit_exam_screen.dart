import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/exam_repository.dart';
import '../models/exam.dart';
import '../theme/app_theme.dart';

class EditExamScreen extends StatefulWidget {
  const EditExamScreen({super.key, required this.examId});

  final int examId;

  @override
  State<EditExamScreen> createState() => _EditExamScreenState();
}

class _EditExamScreenState extends State<EditExamScreen> {
  ExamQuestion? _selected;
  String? _selectedCorrectLabel;
  final _questionController = TextEditingController();
  final _passageController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  bool _saving = false;
  bool _loadingExam = true;
  bool _loadingQuestions = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadExamAndQuestions(),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _passageController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(ExamQuestion question) {
    setState(() => _populateQuestion(question));
  }

  void _populateQuestion(ExamQuestion question) {
    _selected = question;
    _selectedCorrectLabel = question.correctLabel;
    _questionController.text = question.text;
    _passageController.text = question.passage ?? '';
    for (var i = 0; i < 4; i++) {
      _optionControllers[i].text = i < question.options.length
          ? question.options[i].text
          : '';
    }
  }

  Future<void> _loadQuestions() async {
    final repository = context.read<ExamRepository>();
    final exam = repository.examById(widget.examId);
    if (exam == null || exam.questionsLoaded || _loadingQuestions) return;
    setState(() {
      _loadingQuestions = true;
      _loadError = null;
    });
    try {
      await repository.loadQuestions(exam);
    } catch (error) {
      _loadError = '$error';
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _loadExamAndQuestions() async {
    final repository = context.read<ExamRepository>();
    var exam = repository.examById(widget.examId);
    if (exam == null) {
      await repository.load();
      exam = repository.examById(widget.examId);
    }
    if (!mounted) return;
    if (exam == null) {
      setState(() {
        _loadingExam = false;
        _loadError = repository.error ?? 'This examination could not be found.';
      });
      return;
    }
    setState(() => _loadingExam = false);
    await _loadQuestions();
  }

  Future<void> _save(Exam exam) async {
    final question = _selected;
    if (question == null) return;
    setState(() => _saving = true);
    final originalText = question.text;
    final originalPassage = question.passage;
    final originalOptionTexts = question.options
        .map((option) => option.text)
        .toList();
    final originalCorrectLabel = question.correctLabel;
    question.text = _questionController.text.trim();
    final updatedPassage = _passageController.text.trim();
    if (question.part >= 6) {
      _updatePassageForQuestionRun(
        exam,
        question,
        originalPassage,
        updatedPassage.isEmpty ? null : updatedPassage,
      );
    }
    for (var i = 0; i < question.options.length && i < 4; i++) {
      question.options[i].text = _optionControllers[i].text.trim();
      question.options[i].isCorrect =
          question.options[i].label == _selectedCorrectLabel;
    }
    try {
      await context.read<ExamRepository>().saveQuestion(exam, question);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Question changes saved.')));
    } catch (error) {
      question.text = originalText;
      if (question.part >= 6) {
        _updatePassageForQuestionRun(
          exam,
          question,
          updatedPassage.isEmpty ? null : updatedPassage,
          originalPassage,
        );
      }
      for (var i = 0; i < question.options.length; i++) {
        question.options[i].text = originalOptionTexts[i];
        question.options[i].isCorrect =
            question.options[i].label == originalCorrectLabel;
      }
      _selectedCorrectLabel = originalCorrectLabel;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save question: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updatePassageForQuestionRun(
    Exam exam,
    ExamQuestion question,
    String? sourcePassage,
    String? targetPassage,
  ) {
    final selectedIndex = exam.questions.indexOf(question);
    if (selectedIndex < 0) return;
    var first = selectedIndex;
    var last = selectedIndex;
    while (first > 0 &&
        exam.questions[first - 1].part == question.part &&
        exam.questions[first - 1].passage == sourcePassage) {
      first--;
    }
    while (last + 1 < exam.questions.length &&
        exam.questions[last + 1].part == question.part &&
        exam.questions[last + 1].passage == sourcePassage) {
      last++;
    }
    for (var index = first; index <= last; index++) {
      exam.questions[index].passage = targetPassage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<ExamRepository>();
    final exam = repository.examById(widget.examId);
    if (exam == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/teacher')),
        ),
        body: Center(
          child: _loadingExam
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError ?? 'This examination could not be found.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loadingExam = true;
                          _loadError = null;
                        });
                        _loadExamAndQuestions();
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
        ),
      );
    }
    if (_loadingExam) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_selected == null && exam.questions.isNotEmpty) {
      _populateQuestion(exam.questions.first);
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/teacher')),
        title: Text(exam.name),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/teacher'),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Showcase'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          if (_loadingQuestions) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_loadError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load questions: $_loadError'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadQuestions,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          if (exam.questions.isEmpty) {
            return const Center(child: Text('This test has no questions.'));
          }
          return Padding(
            padding: EdgeInsets.all(narrow ? 16 : 32),
            child: narrow
                ? _editorContent(exam, compact: true)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 260, child: _questionPicker(exam)),
                      const SizedBox(width: 22),
                      Expanded(child: _editorContent(exam)),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _editorContent(Exam exam, {bool compact = false}) {
    final question = _selected;
    if (question == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) ...[
          DropdownButtonFormField<ExamQuestion>(
            initialValue: question,
            decoration: const InputDecoration(labelText: 'Question'),
            items: exam.questions
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text('Question ${item.number}'),
                  ),
                )
                .toList(),
            onChanged: (item) {
              if (item != null) _select(item);
            },
          ),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${question.number}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'Part ${question.part}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              if (question.part >= 6) ...[
                TextField(
                  controller: _passageController,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Part 6/7 passage',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                controller: _questionController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Question text',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              RadioGroup<String>(
                groupValue: _selectedCorrectLabel,
                onChanged: (label) {
                  if (label == null) return;
                  setState(() => _selectedCorrectLabel = label);
                },
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < question.options.length && index < 4;
                      index++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Radio<String>(value: question.options[index].label),
                            SizedBox(
                              width: 34,
                              child: Text(
                                question.options[index].label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Answer option',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Select the radio button beside the correct answer.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _save(exam),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save changes'),
          ),
        ),
      ],
    );
  }

  Widget _questionPicker(Exam exam) => Card(
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final part in const [5, 6, 7])
          if (exam.questions.any((question) => question.part == part)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Text(
                'Part $part',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final question in exam.questions.where(
                  (question) => question.part == part,
                ))
                  ChoiceChip(
                    key: ValueKey('question-pill-${question.number}'),
                    label: Text('${question.number}'),
                    selected: question == _selected,
                    onSelected: (_) => _select(question),
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
              ],
            ),
            const Divider(height: 20),
          ],
      ],
    ),
  );
}
