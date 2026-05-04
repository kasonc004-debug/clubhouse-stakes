import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/cs_button.dart';
import '../../clubhouses/models/clubhouse_model.dart';
import '../../clubhouses/providers/clubhouse_provider.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/course_provider.dart';
import '../../courses/widgets/course_picker.dart';

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends ConsumerState<CreateTournamentScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _courseCtrl   = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _rulesCtrl    = TextEditingController();
  final _feeCtrl      = TextEditingController();
  final _maxCtrl      = TextEditingController();
  final _skinsFeeCtrl = TextEditingController();
  String _format      = 'individual';
  String _feePer      = 'player';
  bool _handicapEnabled = true;
  // Default 18-hole pars (par 72 layout). Admin can edit per hole.
  List<int> _pars = const [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4];
  List<int>? _yardages;
  DateTime _date      = DateTime.now().add(const Duration(days: 14));
  bool _loading       = false;
  String? _error;

  // Course selection state
  CourseSummary? _pickedCourse;     // result of search
  CourseDetail?  _courseDetail;     // full detail with tees (after fetch)
  CourseTee?     _pickedTee;
  bool           _loadingCourse = false;

  // Clubhouse selection
  ClubhouseModel? _pickedClubhouse;

  @override
  void dispose() {
    _nameCtrl.dispose(); _cityCtrl.dispose(); _courseCtrl.dispose();
    _descCtrl.dispose(); _rulesCtrl.dispose(); _feeCtrl.dispose();
    _maxCtrl.dispose(); _skinsFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCoursePicked(CourseSummary c) async {
    setState(() {
      _pickedCourse  = c;
      _courseDetail  = null;
      _pickedTee     = null;
      _loadingCourse = true;
      _error         = null;
    });
    try {
      final detail = await ref.read(courseDetailProvider(c.id.toString()).future);
      if (!mounted) return;
      setState(() {
        _courseDetail = detail;
        _courseCtrl.text = detail.displayName;
        if (detail.location != null && detail.location!.isNotEmpty) {
          _cityCtrl.text = detail.location!;
        }
        // Auto-pick first tee if there's only one
        if (detail.tees.length == 1) {
          _applyTee(detail.tees.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Couldn\'t load course details: $e');
    } finally {
      if (mounted) setState(() => _loadingCourse = false);
    }
  }

  void _applyTee(CourseTee t) {
    setState(() {
      _pickedTee = t;
      _pars      = t.holes.map((h) => h.par).toList();
      _yardages  = t.holes.map((h) => h.yardage).toList();
    });
  }

  void _clearCourse() {
    setState(() {
      _pickedCourse  = null;
      _courseDetail  = null;
      _pickedTee     = null;
      _yardages      = null;
      _courseCtrl.clear();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedCourse != null && _pickedTee == null) {
      setState(() => _error = 'Pick a tee before creating the tournament.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final skinsFee = double.tryParse(_skinsFeeCtrl.text) ?? 0;
      await ref.read(apiClientProvider).post(
        ApiConstants.adminTournaments,
        data: {
          'name':        _nameCtrl.text.trim(),
          'city':        _cityCtrl.text.trim(),
          'date':        _date.toIso8601String(),
          'format':      _format,
          'sign_up_fee': double.parse(_feeCtrl.text),
          'max_players': int.parse(_maxCtrl.text),
          'fee_per':     _feePer,
          'course_name': _courseCtrl.text.trim().isEmpty ? null : _courseCtrl.text.trim(),
          'description': _descCtrl.text.trim().isEmpty  ? null : _descCtrl.text.trim(),
          'rules':       _rulesCtrl.text.trim().isEmpty ? null : _rulesCtrl.text.trim(),
          'skins_fee':   skinsFee > 0 ? skinsFee : 0,
          'handicap_enabled': _handicapEnabled,
          'pars':         _pars,
          if (_yardages != null) 'yardages': _yardages,
          if (_pickedTee != null) 'tee_name': _pickedTee!.teeName,
          if (_pickedCourse != null) 'course_api_id': _pickedCourse!.id.toString(),
          if (_pickedClubhouse != null) 'clubhouse_id': _pickedClubhouse!.id,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament created!'), backgroundColor: AppColors.success));
        context.pop();
      }
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDio(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tournament')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),

            TextFormField(controller: _nameCtrl, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Tournament Name *', prefixIcon: Icon(Icons.sports_golf)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 14),

            // Clubhouse picker (host's own clubhouses)
            _ClubhouseDropdown(
              selected: _pickedClubhouse,
              onChanged: (c) => setState(() => _pickedClubhouse = c),
            ),
            const SizedBox(height: 14),

            // Course picker (search via golfcourseapi)
            if (_pickedCourse == null)
              CourseSearchField(
                label: 'Course *',
                onPicked: _onCoursePicked,
              )
            else
              _SelectedCourseCard(
                course:  _pickedCourse!,
                detail:  _courseDetail,
                tee:     _pickedTee,
                loading: _loadingCourse,
                onClear: _clearCourse,
                onTeeSelected: _applyTee,
              ),
            const SizedBox(height: 14),

            // City + course-name fallback (free-text). Auto-filled from course
            // selection but the host can still tweak.
            Row(children: [
              Expanded(child: TextFormField(controller: _cityCtrl,
                decoration: const InputDecoration(
                    labelText: 'City *',
                    prefixIcon: Icon(Icons.location_city_outlined)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _courseCtrl,
                decoration: const InputDecoration(
                    labelText: 'Course Name',
                    prefixIcon: Icon(Icons.grass_outlined)))),
            ]),
            const SizedBox(height: 14),

            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(DateFormat('EEE, MMM d, yyyy').format(_date),
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Format
            const Text('Format', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _FormatOption('Individual', 'individual', _format,
                  (v) => setState(() => _format = v))),
              const SizedBox(width: 8),
              Expanded(child: _FormatOption('Four-Ball', 'fourball', _format,
                  (v) => setState(() => _format = v))),
              const SizedBox(width: 8),
              Expanded(child: _FormatOption('Scramble', 'scramble', _format,
                  (v) => setState(() => _format = v))),
            ]),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: TextFormField(controller: _feeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Entry Fee *', prefixText: '\$'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                })),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Players *', prefixIcon: Icon(Icons.people_outlined)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Must be a number';
                  return null;
                })),
            ]),
            const SizedBox(height: 14),

            const SizedBox(height: 14),

            // Skins fee (optional)
            TextFormField(
              controller: _skinsFeeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Skins Entry Fee (optional)',
                prefixText: '\$',
                prefixIcon: Icon(Icons.casino_outlined),
                helperText: 'Leave blank or 0 to disable skins game',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Fee per
            const Text('Fee applies per', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _FormatOption('Player', 'player', _feePer,
                  (v) => setState(() => _feePer = v))),
              const SizedBox(width: 10),
              Expanded(child: _FormatOption('Team', 'team', _feePer,
                  (v) => setState(() => _feePer = v))),
            ]),
            const SizedBox(height: 14),

            TextFormField(controller: _descCtrl, maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              )),
            const SizedBox(height: 14),

            TextFormField(controller: _rulesCtrl, maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Rules (optional)',
                alignLabelWithHint: true,
                helperText: 'Tournament-specific rules players will see on the tournament page',
                prefixIcon: Icon(Icons.gavel_outlined),
              )),
            const SizedBox(height: 18),

            // Handicap toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: SwitchListTile.adaptive(
                value: _handicapEnabled,
                onChanged: (v) => setState(() => _handicapEnabled = v),
                title: const Text('Handicap-based scoring',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _handicapEnabled
                      ? 'Net scores (gross − handicap) determine the leaderboard.'
                      : 'Gross score only — handicaps are ignored.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                activeColor: AppColors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            const SizedBox(height: 18),

            // Par-per-hole editor (compact)
            const Text('SCORECARD PARS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(children: [
                _ParRow(
                  label: 'Front 9',
                  start: 0,
                  pars: _pars,
                  onChanged: (i, v) => setState(() {
                    final next = [..._pars];
                    next[i] = v;
                    _pars = next;
                  }),
                ),
                const SizedBox(height: 10),
                _ParRow(
                  label: 'Back 9',
                  start: 9,
                  pars: _pars,
                  onChanged: (i, v) => setState(() {
                    final next = [..._pars];
                    next[i] = v;
                    _pars = next;
                  }),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('Total par: ${_pars.fold<int>(0, (a, b) => a + b)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ]),
              ]),
            ),
            const SizedBox(height: 28),

            CSButton(label: 'Create Tournament', loading: _loading, onPressed: _create),
          ]),
        ),
      ),
    );
  }
}

class _ParRow extends StatelessWidget {
  final String label;
  final int start;
  final List<int> pars;
  final void Function(int holeIdx, int newPar) onChanged;
  const _ParRow({
    required this.label,
    required this.start,
    required this.pars,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final segment = pars.sublist(start, start + 9);
    final total = segment.fold<int>(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary, letterSpacing: 1)),
        const Spacer(),
        Text('Par $total',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      ]),
      const SizedBox(height: 6),
      Row(
        children: List.generate(9, (i) {
          final holeIdx = start + i;
          final par = pars[holeIdx];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                // Cycle 3 → 4 → 5 → 6 → 3
                const cycle = [3, 4, 5, 6];
                final next = cycle[(cycle.indexOf(par) + 1) % cycle.length];
                onChanged(holeIdx, next);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(children: [
                  Text('${holeIdx + 1}',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
                  Text('$par',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          );
        }),
      ),
    ]);
  }
}

class _FormatOption extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _FormatOption(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          )),
        ),
      ),
    );
  }
}

class _ClubhouseDropdown extends ConsumerWidget {
  final ClubhouseModel? selected;
  final ValueChanged<ClubhouseModel?> onChanged;
  const _ClubhouseDropdown({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myClubhousesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          // Encourage admin to create a clubhouse but don't block tournament creation.
          return InkWell(
            onTap: () => context.push('/clubhouses/edit'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: const [
                Icon(Icons.add_circle_outline,
                    size: 20, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add a clubhouse to host this tournament under (optional)',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ]),
            ),
          );
        }
        return DropdownButtonFormField<ClubhouseModel?>(
          value: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Clubhouse (optional)',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
          items: [
            const DropdownMenuItem<ClubhouseModel?>(
              value: null,
              child: Text('No clubhouse',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ...list.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _SelectedCourseCard extends StatelessWidget {
  final CourseSummary course;
  final CourseDetail? detail;
  final CourseTee? tee;
  final bool loading;
  final VoidCallback onClear;
  final void Function(CourseTee) onTeeSelected;

  const _SelectedCourseCard({
    required this.course,
    required this.detail,
    required this.tee,
    required this.loading,
    required this.onClear,
    required this.onTeeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.golf_course, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (course.location != null)
                    Text(course.location!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                ]),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Pick a different course',
          ),
        ]),
        const SizedBox(height: 10),
        if (loading)
          const Row(children: [
            SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary)),
            SizedBox(width: 10),
            Text('Loading tees…',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])
        else if (detail == null)
          const SizedBox.shrink()
        else if (detail!.tees.isEmpty)
          const Text(
            'This course has no full 18-hole tee data. Pars + yardages will use defaults — edit below.',
            style: TextStyle(fontSize: 12, color: AppColors.warning),
          )
        else
          DropdownButtonFormField<CourseTee>(
            value: tee,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tee *',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: detail!.tees
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        '${t.displayName}  ·  ${t.totalYards} yds  ·  par ${t.parTotal}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (t) {
              if (t != null) onTeeSelected(t);
            },
          ),
        if (tee != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _CourseStat(label: 'TOTAL', value: '${tee!.totalYards} yds'),
              _CourseStat(label: 'PAR',   value: '${tee!.parTotal}'),
              if (tee!.courseRating != null)
                _CourseStat(
                    label: 'RATING',
                    value: tee!.courseRating!.toStringAsFixed(1)),
              if (tee!.slopeRating != null)
                _CourseStat(
                    label: 'SLOPE',
                    value: tee!.slopeRating!.toStringAsFixed(0)),
            ],
          ),
        ],
      ]),
    );
  }
}

class _CourseStat extends StatelessWidget {
  final String label, value;
  const _CourseStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppColors.textSecondary)),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700)),
      ]);
}
