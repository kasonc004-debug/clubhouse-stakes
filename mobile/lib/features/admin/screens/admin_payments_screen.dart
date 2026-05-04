import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../tournaments/providers/tournament_provider.dart';
import '../providers/admin_provider.dart';

class AdminPaymentsScreen extends ConsumerWidget {
  final String tournamentId;
  final String tournamentName;
  const AdminPaymentsScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partsAsync = ref.watch(adminParticipantsProvider(tournamentId));
    final tAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final t = tAsync.valueOrNull;
    final entryFee = t?.signUpFee ?? 0;
    final skinsFee = t?.skinsFee ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(tournamentName,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: partsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorCard(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminParticipantsProvider(tournamentId)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.attach_money,
              title: 'No registrations yet',
              subtitle: 'Players who sign up will show up here.',
            );
          }
          // Totals
          var entryCollected = 0.0, entryOutstanding = 0.0;
          var skinsCollected = 0.0, skinsOutstanding = 0.0;
          for (final r in rows) {
            final paid = r['payment_status'] == 'paid';
            (paid ? () => entryCollected += entryFee : () => entryOutstanding += entryFee)();
            if (r['skins_entry'] == true) {
              final sPaid = r['skins_payment_status'] == 'paid';
              (sPaid ? () => skinsCollected += skinsFee : () => skinsOutstanding += skinsFee)();
            }
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminParticipantsProvider(tournamentId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _TotalsCard(
                  entryFee: entryFee,
                  skinsFee: skinsFee,
                  entryCollected: entryCollected,
                  entryOutstanding: entryOutstanding,
                  skinsCollected: skinsCollected,
                  skinsOutstanding: skinsOutstanding,
                ),
                const SizedBox(height: 18),
                const Text('PLAYERS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                for (final r in rows)
                  _PaymentRow(
                    tournamentId: tournamentId,
                    row: r,
                    entryFee: entryFee,
                    skinsFee: skinsFee,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final double entryFee, skinsFee;
  final double entryCollected, entryOutstanding;
  final double skinsCollected, skinsOutstanding;
  const _TotalsCard({
    required this.entryFee,
    required this.skinsFee,
    required this.entryCollected,
    required this.entryOutstanding,
    required this.skinsCollected,
    required this.skinsOutstanding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CASH AT CHECK-IN',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _Line(
          label: 'Entry fees',
          collected: entryCollected,
          outstanding: entryOutstanding,
        ),
        if (skinsFee > 0) ...[
          const SizedBox(height: 8),
          _Line(
            label: 'Skins',
            collected: skinsCollected,
            outstanding: skinsOutstanding,
          ),
        ],
        const Divider(height: 22, color: AppColors.divider),
        Row(children: [
          const Text('Outstanding',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            '\$${(entryOutstanding + skinsOutstanding).toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFFC9A84C)),
          ),
        ]),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final double collected, outstanding;
  const _Line({
    required this.label,
    required this.collected,
    required this.outstanding,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 80,
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ),
      Expanded(
        child: Text(
          '\$${collected.toStringAsFixed(0)} collected',
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.success),
        ),
      ),
      Text(
        '\$${outstanding.toStringAsFixed(0)} due',
        style: const TextStyle(
            fontWeight: FontWeight.w700, color: AppColors.warning),
      ),
    ]);
  }
}

class _PaymentRow extends ConsumerStatefulWidget {
  final String tournamentId;
  final Map<String, dynamic> row;
  final double entryFee;
  final double skinsFee;
  const _PaymentRow({
    required this.tournamentId,
    required this.row,
    required this.entryFee,
    required this.skinsFee,
  });

  @override
  ConsumerState<_PaymentRow> createState() => _PaymentRowState();
}

class _PaymentRowState extends ConsumerState<_PaymentRow> {
  bool _busy = false;

  Future<void> _update({
    String? entryStatus,
    String? skinsStatus,
  }) async {
    setState(() => _busy = true);
    final ok = await ref.read(adminPaymentProvider(widget.tournamentId).notifier).update(
          tournamentId: widget.tournamentId,
          entryId: widget.row['entry_id'] as String,
          paymentStatus: entryStatus,
          skinsPaymentStatus: skinsStatus,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(adminParticipantsProvider(widget.tournamentId));
      ref.invalidate(adminFinancialsProvider(widget.tournamentId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Update failed'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final name = r['name'] as String? ?? '—';
    final entryPaid = r['payment_status'] == 'paid';
    final inSkins = r['skins_entry'] == true;
    final skinsPaid = r['skins_payment_status'] == 'paid';
    final showSkins = inSkins && widget.skinsFee > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (_busy)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary)),
        ]),
        const SizedBox(height: 10),
        _PaymentToggle(
          label: 'Entry  \$${widget.entryFee.toStringAsFixed(0)}',
          paid: entryPaid,
          onTap: _busy
              ? null
              : () => _update(entryStatus: entryPaid ? 'pending' : 'paid'),
        ),
        if (showSkins) ...[
          const SizedBox(height: 6),
          _PaymentToggle(
            label: 'Skins  \$${widget.skinsFee.toStringAsFixed(0)}',
            paid: skinsPaid,
            onTap: _busy
                ? null
                : () => _update(skinsStatus: skinsPaid ? 'pending' : 'paid'),
          ),
        ],
      ]),
    );
  }
}

class _PaymentToggle extends StatelessWidget {
  final String label;
  final bool paid;
  final VoidCallback? onTap;
  const _PaymentToggle({
    required this.label,
    required this.paid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: paid
              ? AppColors.success.withOpacity(0.10)
              : AppColors.warning.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: paid
                ? AppColors.success.withOpacity(0.4)
                : AppColors.warning.withOpacity(0.4),
          ),
        ),
        child: Row(children: [
          Icon(paid ? Icons.check_circle : Icons.schedule,
              size: 18,
              color: paid ? AppColors.success : AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(
            paid ? 'PAID' : 'TAP TO MARK PAID',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: paid ? AppColors.success : AppColors.warning),
          ),
        ]),
      ),
    );
  }
}
