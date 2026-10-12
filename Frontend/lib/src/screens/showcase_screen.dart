import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/exam_repository.dart';
import '../models/exam.dart';
import '../models/student.dart';
import '../theme/app_theme.dart';

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key, required this.teacherMode, this.student});

  final bool teacherMode;
  final Student? student;

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  static const _pageSize = 30;
  bool _gridView = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ExamRepository>().load(availableOnly: !widget.teacherMode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<ExamRepository>();
    final available = repository.exams;
    final pageCount = (available.length / _pageSize).ceil().clamp(1, 1000000);
    final start = _page * _pageSize;
    final exams = available.skip(start).take(_pageSize).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        actions: [
          if (widget.teacherMode) ...[
            TextButton.icon(
              onPressed: () => _importExam(context),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import'),
            ),
            const SizedBox(width: 4),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/teacher'),
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Showcase'),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextButton.icon(
                onPressed: () => context.go('/student'),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Exit'),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600 ? 18.0 : 36.0;
          return RefreshIndicator(
            onRefresh: () =>
                repository.load(availableOnly: !widget.teacherMode),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    30,
                    horizontalPadding,
                    18,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ShowcaseHeading(
                      teacherMode: widget.teacherMode,
                      student: widget.student,
                      gridView: _gridView,
                      onToggle: () => setState(() => _gridView = !_gridView),
                    ),
                  ),
                ),
                if (repository.isLoading && available.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (repository.error != null && available.isEmpty)
                  SliverFillRemaining(
                    child: _LoadError(
                      message: repository.error!,
                      onRetry: repository.load,
                    ),
                  )
                else if (exams.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        widget.teacherMode
                            ? 'No examinations in the database yet. Import a DOCX to create the first test.'
                            : 'No examinations are currently available.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (_gridView)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ExamCard(
                          exam: exams[index],
                          listMode: false,
                          teacherMode: widget.teacherMode,
                          onTap: () => _openExam(exams[index]),
                          onAction: (action) =>
                              _handleExamAction(exams[index], action),
                        ),
                        childCount: exams.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columns(constraints.maxWidth),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: constraints.maxWidth < 600 ? 260 : 276,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    sliver: SliverList.separated(
                      itemCount: exams.length,
                      itemBuilder: (context, index) => _ExamCard(
                        exam: exams[index],
                        listMode: true,
                        teacherMode: widget.teacherMode,
                        onTap: () => _openExam(exams[index]),
                        onAction: (action) =>
                            _handleExamAction(exams[index], action),
                      ),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    26,
                    horizontalPadding,
                    40,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _Pagination(
                      page: _page,
                      pageCount: pageCount,
                      onPrevious: _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      onNext: _page + 1 < pageCount
                          ? () => setState(() => _page++)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _columns(double width) {
    if (width >= 1500) return 6;
    if (width >= 1200) return 5;
    if (width >= 950) return 4;
    if (width >= 680) return 3;
    if (width >= 420) return 2;
    return 1;
  }

  void _openExam(Exam exam) {
    if (widget.teacherMode) {
      context.go('/teacher/exams/${exam.id}');
      return;
    }
    context.go('/student/showcase/exams/${exam.id}', extra: widget.student);
  }

  Future<void> _handleExamAction(Exam exam, _ExamAction action) async {
    switch (action) {
      case _ExamAction.toggleAvailability:
        if (exam.isPublished) {
          await _saveExamChanges(exam, isPublished: false);
        } else {
          await _editSchedule(exam, publishOnSave: true);
        }
        return;
      case _ExamAction.schedule:
        await _editSchedule(exam);
        return;
      case _ExamAction.delete:
        await _deleteExam(exam);
        return;
    }
  }

  Future<void> _editSchedule(Exam exam, {bool publishOnSave = false}) async {
    var startAt = exam.startAt;
    var endAt = exam.endAt;
    var isPublished = publishOnSave || exam.isPublished;
    final selection =
        await showDialog<
          ({DateTime? startAt, DateTime? endAt, bool isPublished})
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('Schedule ${exam.name}'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DateTimeChoice(
                      label: 'Start time',
                      value: startAt,
                      onChoose: () async {
                        final value = await _pickDateTime(context, startAt);
                        if (value != null) {
                          setDialogState(() => startAt = value);
                        }
                      },
                      onClear: startAt == null
                          ? null
                          : () => setDialogState(() => startAt = null),
                    ),
                    _DateTimeChoice(
                      label: 'End time',
                      value: endAt,
                      onChoose: () async {
                        final value = await _pickDateTime(context, endAt);
                        if (value != null) setDialogState(() => endAt = value);
                      },
                      onClear: endAt == null
                          ? null
                          : () => setDialogState(() => endAt = null),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available to students'),
                      value: isPublished,
                      onChanged: (value) =>
                          setDialogState(() => isPublished = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (isPublished &&
                        (startAt == null ||
                            endAt == null ||
                            !endAt!.isAfter(startAt!) ||
                            !endAt!.isAfter(DateTime.now()))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Set a valid schedule with an end time in the future before enabling.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, (
                      startAt: startAt,
                      endAt: endAt,
                      isPublished: isPublished,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
    if (selection == null || !mounted) return;
    await _saveExamChanges(
      exam,
      startAt: selection.startAt,
      endAt: selection.endAt,
      isPublished: selection.isPublished,
      updateSchedule: true,
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? initialValue,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialValue ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initialValue == null
          ? TimeOfDay.fromDateTime(now)
          : TimeOfDay.fromDateTime(initialValue),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveExamChanges(
    Exam exam, {
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    bool updateSchedule = false,
  }) async {
    final oldStartAt = exam.startAt;
    final oldEndAt = exam.endAt;
    final oldIsPublished = exam.isPublished;
    if (updateSchedule) {
      exam
        ..startAt = isPublished == false ? null : startAt
        ..endAt = isPublished == false ? null : endAt;
    } else if (isPublished == false) {
      exam
        ..startAt = null
        ..endAt = null;
    }
    if (isPublished != null) exam.isPublished = isPublished;
    try {
      await context.read<ExamRepository>().saveExam(exam);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Examination settings saved.')),
        );
      }
    } catch (error) {
      exam
        ..startAt = oldStartAt
        ..endAt = oldEndAt
        ..isPublished = oldIsPublished;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save examination settings: $error'),
          ),
        );
      }
    }
  }

  Future<void> _deleteExam(Exam exam) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete examination?'),
        content: Text(
          '${exam.name} and its questions will be permanently removed from SQL.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    try {
      await context.read<ExamRepository>().deleteExam(exam);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Examination deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete examination: $error')),
        );
      }
    }
  }
}

enum _ExamAction { toggleAvailability, schedule, delete }

class _DateTimeChoice extends StatelessWidget {
  const _DateTimeChoice({
    required this.label,
    required this.value,
    required this.onChoose,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onChoose;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value == null ? 'Not set' : _formatDateTime(value!)),
    trailing: Wrap(
      children: [
        IconButton(
          tooltip: 'Choose date and time',
          onPressed: onChoose,
          icon: const Icon(Icons.edit_calendar_outlined),
        ),
        IconButton(
          tooltip: 'Clear',
          onPressed: onClear,
          icon: const Icon(Icons.clear),
        ),
      ],
    ),
  );
}

class _ShowcaseHeading extends StatelessWidget {
  const _ShowcaseHeading({
    required this.teacherMode,
    required this.student,
    required this.gridView,
    required this.onToggle,
  });

  final bool teacherMode;
  final Student? student;
  final bool gridView;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final title = teacherMode ? 'Examination showcase' : 'Your examinations';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 18,
      spacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              teacherMode
                  ? 'Manage TOEIC Reading tests and review their questions.'
                  : student?.fullName ?? '',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: onToggle,
          icon: Icon(gridView ? Icons.view_list_rounded : Icons.grid_view),
          label: Text(gridView ? 'List view' : 'Grid view'),
        ),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.listMode,
    required this.teacherMode,
    required this.onTap,
    required this.onAction,
  });

  final Exam exam;
  final bool listMode;
  final bool teacherMode;
  final VoidCallback onTap;
  final ValueChanged<_ExamAction> onAction;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: listMode
            ? Row(
                children: [
                  const _ExamIcon(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ExamInfo(exam: exam, teacherMode: teacherMode),
                  ),
                  if (teacherMode) _ExamMenu(exam: exam, onSelected: onAction),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _ExamIcon(),
                      const Spacer(),
                      if (teacherMode)
                        _ExamMenu(exam: exam, onSelected: onAction),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _ExamInfo(exam: exam, teacherMode: teacherMode),
                  ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _ExamMenu extends StatelessWidget {
  const _ExamMenu({required this.exam, required this.onSelected});

  final Exam exam;
  final ValueChanged<_ExamAction> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_ExamAction>(
    tooltip: 'Manage examination',
    onSelected: onSelected,
    itemBuilder: (context) => [
      PopupMenuItem(
        value: _ExamAction.toggleAvailability,
        child: Text(exam.isPublished ? 'Disable for students' : 'Enable'),
      ),
      const PopupMenuItem(
        value: _ExamAction.schedule,
        child: Text('Set availability schedule'),
      ),
      const PopupMenuItem(
        value: _ExamAction.delete,
        child: Text('Delete permanently'),
      ),
    ],
  );
}

class _ExamIcon extends StatelessWidget {
  const _ExamIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.description_outlined,
      color: AppColors.primary,
      size: 21,
    ),
  );
}

class _ExamInfo extends StatelessWidget {
  const _ExamInfo({required this.exam, required this.teacherMode});

  final Exam exam;
  final bool teacherMode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        exam.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      if (teacherMode) ...[
        const SizedBox(height: 5),
        Text(
          exam.isPublished ? 'Enabled' : 'Disabled · draft',
          style: TextStyle(
            color: exam.isPublished ? AppColors.primary : AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 11),
      _MetaLine(
        icon: Icons.calendar_month_outlined,
        text: exam.startAt == null || exam.endAt == null
            ? 'Not scheduled'
            : '${_formatDateTime(exam.startAt!)} – ${_formatDateTime(exam.endAt!)}',
      ),
      const SizedBox(height: 7),
      _MetaLine(
        icon: Icons.quiz_outlined,
        text: '${exam.totalQuestions} questions',
      ),
      const SizedBox(height: 7),
      _MetaLine(
        icon: Icons.timer_outlined,
        text: '${exam.durationMinutes} min',
      ),
    ],
  );
}

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ],
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 14,
    children: [
      OutlinedButton(onPressed: onPrevious, child: const Text('Previous')),
      Text(
        'Page ${page + 1} of $pageCount',
        style: const TextStyle(color: AppColors.muted),
      ),
      FilledButton.icon(
        onPressed: onNext,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Next Page'),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: AppColors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go('/student'),
    borderRadius: BorderRadius.circular(8),
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, color: AppColors.primary),
          SizedBox(width: 9),
          Text(
            'Readwise TOEIC',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}

Future<void> _importExam(BuildContext context) async {
  final nameController = TextEditingController();
  final repository = context.read<ExamRepository>();
  final messenger = ScaffoldMessenger.of(context);
  PlatformFile? selectedFile;
  final result = await showDialog<({String name, PlatformFile file})>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Import a Reading test'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Test name',
                  hintText: 'Reading v01',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final file = await FilePicker.pickFile(
                    type: FileType.custom,
                    allowedExtensions: ['docx'],
                  );
                  if (file != null) setDialogState(() => selectedFile = file);
                },
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(selectedFile?.name ?? 'Choose a .docx file'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                selectedFile != null && nameController.text.trim().isNotEmpty
                ? () => Navigator.pop(dialogContext, (
                    name: nameController.text.trim(),
                    file: selectedFile!,
                  ))
                : null,
            child: const Text('Import'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  if (result == null || !context.mounted) return;
  late final Uint8List bytes;
  try {
    bytes = await result.file.readAsBytes();
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Could not read the selected file: $error')),
    );
    return;
  }
  try {
    final exam = await repository.importExam(
      name: result.name,
      fileName: result.file.name,
      bytes: bytes,
    );
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('${exam.name} was imported successfully.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $error')));
  }
}
