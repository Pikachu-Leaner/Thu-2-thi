 class Exam {
   static const defaultDurationMinutes = 75;

  Exam({
    required this.id,
    required this.name,
    this.startAt,
    this.endAt,
    required this.durationMinutes,
    required this.questions,
    this.questionsLoaded = false,
    this.declaredTotalQuestions,
    this.isPublished = true,
  });

  final int id;
  String name;
  DateTime? startAt;
  DateTime? endAt;
  int durationMinutes;
  final List<ExamQuestion> questions;
  bool questionsLoaded;
  final int? declaredTotalQuestions;
  bool isPublished;

  int get totalQuestions => declaredTotalQuestions ?? questions.length;

  factory Exam.fromJson(Map<String, dynamic> json) {
    final id = _intValue(json['id']);
    final questionsJson =
        (json['questions'] as List<dynamic>?) ?? const <dynamic>[];
    final name = json['name'] as String? ?? 'Reading Test $id';
    return Exam(
      id: id,
      name: name,
      startAt: DateTime.tryParse(json['startAt']?.toString() ?? ''),
      endAt: DateTime.tryParse(json['endAt']?.toString() ?? ''),
      durationMinutes: defaultDurationMinutes,
      declaredTotalQuestions: _intValue(json['totalQuestions']),
      questions: questionsJson
          .whereType<Map<String, dynamic>>()
          .map(ExamQuestion.fromJson)
          .toList(),
      isPublished: json['isPublished'] as bool? ?? false,
    );
  }

  bool isAvailableAt(DateTime now) =>
      isPublished &&
      startAt != null &&
      endAt != null &&
      !now.isBefore(startAt!) &&
      now.isBefore(endAt!);
}

class ExamQuestion {
  ExamQuestion({
    required this.id,
    required this.number,
    required this.text,
    required this.options,
    this.passage,
    this.part = 5,
  });

  final int id;
  final int number;
  String text;
  String? passage;
  int part;
  final List<AnswerOption> options;

  String? get correctLabel {
    for (final option in options) {
      if (option.isCorrect) return option.label;
    }
    return null;
  }

  factory ExamQuestion.fromJson(Map<String, dynamic> json) => ExamQuestion(
        id: _intValue(json['id']),
        number: _intValue(json['number']),
        text: json['text'] as String? ?? '',
        part: _intValue(json['part'], fallback: 5),
        passage: json['passage'] as String?,
        options: ((json['options'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AnswerOption.fromJson)
            .toList(),
      );
}

class AnswerOption {
  AnswerOption({
    required this.label,
    required this.text,
    required this.isCorrect,
  });

  final String label;
  String text;
  bool isCorrect;

  factory AnswerOption.fromJson(Map<String, dynamic> json) => AnswerOption(
        label: json['label'] as String? ?? '',
        text: json['text'] as String? ?? '',
        isCorrect: json['isCorrect'] as bool? ?? false,
      );
}

int _intValue(Object? value, {int fallback = 0}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
