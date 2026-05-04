import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../models/course_model.dart';
import '../providers/course_provider.dart';

/// Selection emitted when admin picks a course + tee.
class CourseSelection {
  final CourseDetail course;
  final CourseTee tee;
  const CourseSelection({required this.course, required this.tee});
}

/// Inline course-search box with results dropdown. Calls [onPicked] once a
/// course is selected (no tee yet — caller owns the tee dropdown).
class CourseSearchField extends ConsumerStatefulWidget {
  final void Function(CourseSummary) onPicked;
  final String? initialLabel;
  final String label;

  const CourseSearchField({
    super.key,
    required this.onPicked,
    this.initialLabel,
    this.label = 'Search course',
  });

  @override
  ConsumerState<CourseSearchField> createState() => _CourseSearchFieldState();
}

class _CourseSearchFieldState extends ConsumerState<CourseSearchField> {
  final _controller = TextEditingController();
  Timer?  _debounce;
  String  _query = '';
  bool    _expanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLabel != null) _controller.text = widget.initialLabel!;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _expanded = v.trim().length >= 2);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'e.g. Pebble Beach',
          prefixIcon: const Icon(Icons.golf_course_outlined),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _expanded = false;
                      _query = '';
                    });
                  },
                ),
        ),
      ),
      if (_expanded && _query.isNotEmpty)
        _ResultsList(
          query: _query,
          onTap: (c) {
            FocusScope.of(context).unfocus();
            _controller.text = c.displayName;
            setState(() => _expanded = false);
            widget.onPicked(c);
          },
        ),
    ]);
  }
}

class _ResultsList extends ConsumerWidget {
  final String query;
  final void Function(CourseSummary) onTap;

  const _ResultsList({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(courseSearchProvider(query));

    Widget shell(Widget child) => Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: child,
        );

    return async.when(
      loading: () => shell(const Padding(
        padding: EdgeInsets.all(14),
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 10),
          Text('Searching golfcourseapi…',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      )),
      error: (e, _) => shell(Padding(
        padding: const EdgeInsets.all(14),
        child: Text('Search failed: $e',
            style: const TextStyle(fontSize: 12, color: AppColors.error)),
      )),
      data: (courses) {
        if (courses.isEmpty) {
          return shell(const Padding(
            padding: EdgeInsets.all(14),
            child: Text('No courses found.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ));
        }
        return shell(Column(
          children: [
            for (var i = 0; i < courses.length && i < 12; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: AppColors.divider),
              ListTile(
                dense: true,
                title: Text(courses[i].displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: courses[i].location == null
                    ? null
                    : Text(courses[i].location!,
                        style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => onTap(courses[i]),
              ),
            ],
          ],
        ));
      },
    );
  }
}
