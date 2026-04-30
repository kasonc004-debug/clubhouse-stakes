import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/cs_button.dart';

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
  final _feeCtrl      = TextEditingController();
  final _maxCtrl      = TextEditingController();
  String _format      = 'individual';
  String _feePer      = 'player';
  DateTime _date      = DateTime.now().add(const Duration(days: 14));
  bool _loading       = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _cityCtrl.dispose(); _courseCtrl.dispose();
    _descCtrl.dispose(); _feeCtrl.dispose(); _maxCtrl.dispose();
    super.dispose();
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
    setState(() { _loading = true; _error = null; });
    try {
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

            Row(children: [
              Expanded(child: TextFormField(controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'City *', prefixIcon: Icon(Icons.location_city_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _courseCtrl,
                decoration: const InputDecoration(labelText: 'Course Name', prefixIcon: Icon(Icons.grass_outlined)))),
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
              const SizedBox(width: 10),
              Expanded(child: _FormatOption('Four-Ball', 'fourball', _format,
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
            const SizedBox(height: 28),

            CSButton(label: 'Create Tournament', loading: _loading, onPressed: _create),
          ]),
        ),
      ),
    );
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
