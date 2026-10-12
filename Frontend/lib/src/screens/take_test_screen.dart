import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/exam_repository.dart';
import '../models/exam.dart';
import '../models/student.dart';
import '../models/test_attempt.dart';
import '../theme/app_theme.dart';

class TakeTestScreen extends StatefulWidget {
  const TakeTestScreen({super.key, required this.examId, this.student});

  final int examId;
  final Student? student;

  @override
  State<TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<TakeTestScreen> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _questionKeys = {};
  final Map<int, String> _answers = {};
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _submitted = false;
  bool _loadingQuestions = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final exam = context.read<ExamRepository>().examById(widget.examId);
    if (exam == null) {
      _loadingQuestions = false;
    } else {
      unawaited(_loadQuestions(exam));
    }
  }

  Future<void> _loadQuestions(Exam exam) async {
    try {
      await context.read<ExamRepository>().loadQuestions(
        exam,
        requireAvailable: true,
      );
      if (mounted) setState(() => _prepareTest(exam));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = '$error';
        _loadingQuestions = false;
      });
    }
  }

  void _prepareTest(Exam exam) {
    _answers.clear();
    _secondsRemaining = exam.durationMinutes * 60;
    _loadingQuestions = false;
    for (final question in exam.questions) {
      _questionKeys[question.id] = GlobalKey();
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _submitted) return;
      if (_secondsRemaining <= 1) {
        setState(() => _secondsRemaining = 0);
        _submit(automatic: true);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exam = context.watch<ExamRepository>().examById(widget.examId);
    if (exam == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This examination could not be found.')),
      );
    }
    if (_loadingQuestions) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.name)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load questions: $_loadError'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loadingQuestions = true;
                    _loadError = null;
                  });
                  unawaited(_loadQuestions(exam));
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (exam.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.name)),
        body: const Center(child: Text('This test has no questions to take.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(exam.name),
        automaticallyImplyLeading: false,
        actions: [
          _TimerLabel(secondsRemaining: _secondsRemaining),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => _confirmSubmit(),
            child: const Text('Send Test Results'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 330,
                  child: _NavigationPanel(
                    exam: exam,
                    answers: _answers,
                    onSelect: _jumpToQuestion,
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: _questionBody(exam)),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                height: 116,
                child: _MobileNavigation(
                  exam: exam,
                  answers: _answers,
                  onSelect: _jumpToQuestion,
                ),
              ),
              Expanded(child: _questionBody(exam)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Scroll to top',
        onPressed: () => _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        ),
        child: const Icon(Icons.keyboard_arrow_up_rounded),
      ),
    );
  }

  Widget _questionBody(Exam exam) => Scrollbar(
    controller: _scrollController,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Answer every question before you submit.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          for (final question in exam.questions)
            _QuestionCard(
              key: _questionKeys[question.id],
              question: question,
              selected: _answers[question.id],
              onSelect: (label) =>
                  setState(() => _answers[question.id] = label),
            ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => _confirmSubmit(),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send Test Results'),
            ),
          ),
        ],
      ),
    ),
  );

  void _jumpToQuestion(ExamQuestion question) {
    final target = _questionKeys[question.id]?.currentContext;
    debugPrint(
      'Jump to ${question.number} (id ${question.id}), target: ${target != null}, scroll: ${_scrollController.hasClients}, offset: ${_scrollController.hasClients ? _scrollController.position.pixels : -1}, max: ${_scrollController.hasClients ? _scrollController.position.maxScrollExtent : -1}',
    );
    if (target == null) return;
    final renderObject = target.findRenderObject();
    final viewport = renderObject == null
        ? null
        : RenderAbstractViewport.maybeOf(renderObject);
    debugPrint(
      'target=$renderObject viewport=$viewport reveal=${renderObject == null || viewport == null ? null : viewport.getOffsetToReveal(renderObject, 0.04).offset}',
    );
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.04,
      ).then(
        (_) => debugPrint(
          'Jump complete for ${question.number}, offset: ${_scrollController.position.pixels}',
        ),
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    if (_submitted) return;
    final unanswered =
        context
            .read<ExamRepository>()
            .examById(widget.examId)
            ?.questions
            .length ??
        0;
    final remaining = unanswered - _answers.length;
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit your test?'),
        content: Text(
          remaining > 0
              ? '$remaining question${remaining == 1 ? '' : 's'} unanswered. You cannot change answers after submitting.'
              : 'You will not be able to change answers after submitting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep working'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit test'),
          ),
        ],
      ),
    );
    if (shouldSubmit == true) _submit(automatic: false);
  }

  void _submit({required bool automatic}) {
    if (_submitted) return;
    _submitted = true;
    _timer?.cancel();
    if (!mounted) return;
    if (automatic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time is up. Your test was submitted.')),
      );
    }
    context.go(
      '/student/showcase/exams/${widget.examId}/results',
      extra: TestAttempt(
        student: widget.student,
        answers: Map.unmodifiable(_answers),
      ),
    );
  }
}

class _TimerLabel extends StatelessWidget {
  const _TimerLabel({required this.secondsRemaining});

  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final hours = secondsRemaining ~/ 3600;
    final minutes = (secondsRemaining % 3600) ~/ 60;
    final seconds = secondsRemaining % 60;
    final text = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: secondsRemaining < 300
            ? AppColors.red.withValues(alpha: .08)
            : AppColors.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.exam,
    required this.answers,
    required this.onSelect,
  });

  final Exam exam;
  final Map<int, String> answers;
  final ValueChanged<ExamQuestion> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question navigator',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${answers.length} / ${exam.questions.length} answered',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: GridView.builder(
              padding: const EdgeInsets.only(right: 6, bottom: 12),
              itemCount: exam.questions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final question = exam.questions[index];
                return _QuestionPill(
                  question: question,
                  answered: answers.containsKey(question.id),
                  onTap: () => onSelect(question),
                );
              },
            ),
          ),
        ),
        const _PillLegend(),
      ],
    ),
  );
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.exam,
    required this.answers,
    required this.onSelect,
  });

  final Exam exam;
  final Map<int, String> answers;
  final ValueChanged<ExamQuestion> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${answers.length} / ${exam.questions.length} answered',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 7),
        Expanded(
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: exam.questions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: 34,
            ),
            itemBuilder: (context, index) {
              final question = exam.questions[index];
              return _QuestionPill(
                question: question,
                answered: answers.containsKey(question.id),
                onTap: () => onSelect(question),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _QuestionPill extends StatelessWidget {
  const _QuestionPill({
    required this.question,
    required this.answered,
    required this.onTap,
  });

  final ExamQuestion question;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Question ${question.number}',
    child: Material(
      color: answered ? AppColors.primary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: answered ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            '${question.number}',
            style: TextStyle(
              color: answered ? Colors.white : AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  final ExamQuestion question;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${question.number}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((question.passage ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                question.passage!,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              question.text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (label) {
                if (label != null) onSelect(label);
              },
              child: Column(
                children: [
                  for (final option in question.options)
                    _AnswerRow(
                      option: option,
                      onTap: () => onSelect(option.label),
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

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.option, required this.onTap});

  final AnswerOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Radio<String>(value: option.label),
          Text(
            '${option.label}. ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Expanded(child: Text(option.text)),
        ],
      ),
    ),
  );
}

class _PillLegend extends StatelessWidget {
  const _PillLegend();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _LegendDot(color: Colors.white, border: AppColors.border),
      SizedBox(width: 6),
      Text('Unanswered', style: TextStyle(fontSize: 12)),
      SizedBox(width: 14),
      _LegendDot(color: AppColors.primary, border: AppColors.primary),
      SizedBox(width: 6),
      Text('Answered', style: TextStyle(fontSize: 12)),
    ],
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.border});

  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    width: 13,
    height: 13,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
