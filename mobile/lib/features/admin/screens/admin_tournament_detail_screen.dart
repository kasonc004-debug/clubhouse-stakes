import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/financials_model.dart';
import '../providers/admin_provider.dart';

class AdminTournamentDetailScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String tournamentName;
  const AdminTournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  ConsumerState<AdminTournamentDetailScreen> createState() =>
      _AdminTournamentDetailScreenState();
}

class _AdminTournamentDetailScreenState
    extends ConsumerState<AdminTournamentDetailScreen> {
  // Local editing state
  late double _houseCutPct;
  late double _skinsFee;
  late List<PayoutPlace> _payoutPlaces;
  bool _loaded = false;
  bool _dirty = false;

  void _initFromModel(FinancialsModel m) {
    if (_loaded) return;
    _houseCutPct  = m.houseCutPct;
    _skinsFee     = m.skinsFee;
    _payoutPlaces = List.from(m.payoutPlaces);
    _loaded = true;
  }

  double get _payoutTotal =>
      _payoutPlaces.fold(0, (sum, p) => sum + p.pct);

  double get _liveHouseCutAmount {
    final total = ref
        .read(adminFinancialsProvider(widget.tournamentId))
        .valueOrNull
        ?.totalCollected ?? 0;
    return total * (_houseCutPct / 100);
  }

  double get _livePrizePool {
    final total = ref
        .read(adminFinancialsProvider(widget.tournamentId))
        .valueOrNull
        ?.totalCollected ?? 0;
    return total * (1 - _houseCutPct / 100);
  }

  Future<void> _save() async {
    final ok = await ref
        .read(updateFinancialsProvider(widget.tournamentId).notifier)
        .save(
          widget.tournamentId,
          houseCutPct:  _houseCutPct,
          skinsFee:     _skinsFee,
          payoutPlaces: _payoutPlaces,
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _dirty = false);
      ref.invalidate(adminFinancialsProvider(widget.tournamentId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      final err = ref
          .read(updateFinancialsProvider(widget.tournamentId))
          .error
          ?.toString() ?? 'Failed to save';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _setStatus(String status) async {
    final ok = await ref
        .read(updateStatusProvider(widget.tournamentId).notifier)
        .setStatus(widget.tournamentId, status);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(adminFinancialsProvider(widget.tournamentId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status set to $status'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final financialsAsync = ref.watch(adminFinancialsProvider(widget.tournamentId));
    final saving = ref.watch(updateFinancialsProvider(widget.tournamentId)).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_dirty)
            TextButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('SAVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: financialsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: Colors.red))),
        data: (fin) {
          _initFromModel(fin);
          return _buildBody(fin);
        },
      ),
    );
  }

  Widget _buildBody(FinancialsModel fin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminHero(fin: fin),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
          _MoneyTrackerCard(
                fin: fin,
                houseCutPct: _houseCutPct,
                liveCutAmount: _liveHouseCutAmount,
                livePrizePool: _livePrizePool,
                onCutChanged: (v) => setState(() {
                  _houseCutPct = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              if (fin.skinsFee > 0 || true) // always show skins config
                _SkinsConfigCard(
                  skinsFee: _skinsFee,
                  onChanged: (v) => setState(() {
                    _skinsFee = v;
                    _dirty = true;
                  }),
                ),
              const SizedBox(height: 16),
              _PayoutStructureCard(
                payoutPlaces: _payoutPlaces,
                prizePool: _livePrizePool,
                onChanged: (places) => setState(() {
                  _payoutPlaces = places;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              _StatusCard(
                status: fin.status,
                onSetStatus: _setStatus,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/admin/tournament/${widget.tournamentId}/scores',
                    extra: fin.name,
                  ),
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: const Text('Edit Player Scores'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin Hero Header ─────────────────────────────────────────────────────────

class _AdminHero extends StatelessWidget {
  final FinancialsModel fin;
  const _AdminHero({required this.fin});

  Color _statusColor() {
    switch (fin.status) {
      case 'active':    return Colors.greenAccent;
      case 'completed': return Colors.grey.shade400;
      default:          return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3A2D), Color(0xFF2D5A3D), Color(0xFF1B3A2D)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor().withValues(alpha: 0.6)),
                ),
                child: Text(
                  fin.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor(),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Tournament name
              Text(
                fin.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              // Quick stats row
              Row(
                children: [
                  _HeroStat(
                    label: 'Players',
                    value: '${fin.playerCount}/${fin.maxPlayers}',
                  ),
                  _HeroVDivider(),
                  _HeroStat(
                    label: 'Collected',
                    value: '\$${fin.totalCollected.toStringAsFixed(0)}',
                  ),
                  _HeroVDivider(),
                  _HeroStat(
                    label: 'Prize Pool',
                    value: '\$${fin.prizePool.toStringAsFixed(0)}',
                    highlight: true,
                  ),
                  if (fin.skinsFee > 0) ...[
                    _HeroVDivider(),
                    _HeroStat(
                      label: 'Skins Pot',
                      value: '\$${fin.skinsTotal.toStringAsFixed(0)}',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _HeroStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: highlight ? AppColors.gold : Colors.white)),
        ],
      ),
    );
  }
}

class _HeroVDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.2),
      );
}

// ── Money Tracker ─────────────────────────────────────────────────────────────

class _MoneyTrackerCard extends StatelessWidget {
  final FinancialsModel fin;
  final double houseCutPct;
  final double liveCutAmount;
  final double livePrizePool;
  final ValueChanged<double> onCutChanged;

  const _MoneyTrackerCard({
    required this.fin,
    required this.houseCutPct,
    required this.liveCutAmount,
    required this.livePrizePool,
    required this.onCutChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Money Tracker',
      icon: Icons.attach_money,
      child: Column(
        children: [
          Row(
            children: [
              _MoneyTile(
                label: 'Entry Fee',
                value: '\$${fin.signUpFee.toStringAsFixed(0)} / ${fin.feePer}',
                sub: '${fin.playerCount} of ${fin.maxPlayers} paid',
              ),
              _MoneyTile(
                label: 'Total Collected',
                value: '\$${fin.totalCollected.toStringAsFixed(2)}',
                highlight: true,
              ),
            ],
          ),
          if (fin.skinsFee > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  _MoneyTile(
                    label: 'Skins Entries',
                    value: '${fin.skinsCount} players',
                    sub: '\$${fin.skinsFee.toStringAsFixed(0)} each',
                  ),
                  _MoneyTile(
                    label: 'Skins Pool',
                    value: '\$${fin.skinsTotal.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text('House Cut',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Text('${houseCutPct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary)),
                const SizedBox(width: 8),
                Text('= \$${liveCutAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Slider(
            value: houseCutPct.clamp(0, 50),
            min: 0,
            max: 50,
            divisions: 100,
            activeColor: AppColors.primary,
            label: '${houseCutPct.toStringAsFixed(1)}%',
            onChanged: (v) => onCutChanged(
                double.parse(v.toStringAsFixed(1))),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Prize Pool',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text('\$${livePrizePool.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final bool highlight;
  const _MoneyTile({
    required this.label,
    required this.value,
    this.sub,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: highlight ? AppColors.primary : null)),
            if (sub != null)
              Text(sub!,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ── Skins Config ──────────────────────────────────────────────────────────────

class _SkinsConfigCard extends StatefulWidget {
  final double skinsFee;
  final ValueChanged<double> onChanged;
  const _SkinsConfigCard({required this.skinsFee, required this.onChanged});

  @override
  State<_SkinsConfigCard> createState() => _SkinsConfigCardState();
}

class _SkinsConfigCardState extends State<_SkinsConfigCard> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.skinsFee > 0
            ? widget.skinsFee.toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Skins Game',
      icon: Icons.casino_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Entry Fee',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text(
                      'Set to 0 to disable skins for this tournament.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'))
                ],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: '\$',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 8),
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v) ?? 0;
                  widget.onChanged(parsed);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payout Structure ──────────────────────────────────────────────────────────

class _PayoutStructureCard extends StatelessWidget {
  final List<PayoutPlace> payoutPlaces;
  final double prizePool;
  final ValueChanged<List<PayoutPlace>> onChanged;

  const _PayoutStructureCard({
    required this.payoutPlaces,
    required this.prizePool,
    required this.onChanged,
  });

  double get _total => payoutPlaces.fold(0, (s, p) => s + p.pct);
  bool   get _valid => _total <= 100.001;

  void _updatePct(int index, double pct) {
    final updated = List<PayoutPlace>.from(payoutPlaces);
    updated[index] = updated[index].copyWith(pct: pct);
    onChanged(updated);
  }

  void _addPlace() {
    final next = (payoutPlaces.isEmpty ? 0 : payoutPlaces.last.place) + 1;
    onChanged([...payoutPlaces, PayoutPlace(place: next, pct: 0)]);
  }

  void _removePlace(int index) {
    final updated = List<PayoutPlace>.from(payoutPlaces)..removeAt(index);
    onChanged(updated);
  }

  String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Payout Structure',
      icon: Icons.emoji_events_outlined,
      trailing: !_valid
          ? const Text('Must be ≤ 100%',
              style: TextStyle(color: Colors.red, fontSize: 12))
          : Text('${_total.toStringAsFixed(1)}% allocated',
              style: TextStyle(
                  fontSize: 12,
                  color: _total == 100 ? AppColors.primary : Colors.orange)),
      child: Column(
        children: [
          ...payoutPlaces.asMap().entries.map((entry) {
            final i = entry.key;
            final place = entry.value;
            final payout = prizePool * (place.pct / 100);
            return _PayoutRow(
              label: _ordinal(place.place),
              pct: place.pct,
              payoutAmount: payout,
              onPctChanged: (v) => _updatePct(i, v),
              onRemove: payoutPlaces.length > 1
                  ? () => _removePlace(i)
                  : null,
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: OutlinedButton.icon(
              onPressed: _addPlace,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Place'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          if (prizePool > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('Projected Payouts',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: payoutPlaces.map((p) {
                      final amt = prizePool * (p.pct / 100);
                      return _PayoutChip(
                          label: _ordinal(p.place),
                          amount: amt);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayoutRow extends StatefulWidget {
  final String label;
  final double pct;
  final double payoutAmount;
  final ValueChanged<double> onPctChanged;
  final VoidCallback? onRemove;

  const _PayoutRow({
    required this.label,
    required this.pct,
    required this.payoutAmount,
    required this.onPctChanged,
    this.onRemove,
  });

  @override
  State<_PayoutRow> createState() => _PayoutRowState();
}

class _PayoutRowState extends State<_PayoutRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.pct > 0 ? widget.pct.toStringAsFixed(1) : '');
  }

  @override
  void didUpdateWidget(_PayoutRow old) {
    super.didUpdateWidget(old);
    if (old.pct != widget.pct) {
      final newText = widget.pct > 0 ? widget.pct.toStringAsFixed(1) : '';
      if (_ctrl.text != newText) {
        _ctrl.text = newText;
        _ctrl.selection = TextSelection.collapsed(offset: newText.length);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(widget.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Expanded(
            child: Slider(
              value: widget.pct.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 200,
              activeColor: AppColors.primary,
              label: '${widget.pct.toStringAsFixed(1)}%',
              onChanged: (v) => widget.onPctChanged(
                  double.parse(v.toStringAsFixed(1))),
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,1}'))
              ],
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                suffixText: '%',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 8),
                isDense: true,
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) widget.onPctChanged(parsed);
              },
            ),
          ),
          const SizedBox(width: 8),
          if (widget.onRemove != null)
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _PayoutChip extends StatelessWidget {
  final String label;
  final double amount;
  const _PayoutChip({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        '$label  \$${amount.toStringAsFixed(0)}',
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.primary),
      ),
    );
  }
}

// ── Status Card ───────────────────────────────────────────────────────────────

class _StatusCard extends ConsumerWidget {
  final String status;
  final Future<void> Function(String) onSetStatus;
  const _StatusCard({required this.status, required this.onSetStatus});

  Color _statusColor() {
    switch (status) {
      case 'active':    return Colors.green;
      case 'completed': return Colors.grey;
      default:          return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Tournament Status',
      icon: Icons.flag_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _statusColor().withOpacity(0.4)),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _statusColor()),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: [
            if (status == 'upcoming')
              Expanded(
                child: _ActionButton(
                  label: 'Set Active',
                  icon: Icons.play_arrow,
                  color: Colors.green,
                  onTap: () => onSetStatus('active'),
                ),
              ),
            if (status == 'upcoming') const SizedBox(width: 12),
            if (status != 'completed')
              Expanded(
                child: _ActionButton(
                  label: 'Mark Complete',
                  icon: Icons.check_circle_outline,
                  color: AppColors.primary,
                  onTap: () => onSetStatus('completed'),
                ),
              ),
            if (status == 'completed')
              Expanded(
                child: _ActionButton(
                  label: 'Reopen',
                  icon: Icons.refresh,
                  color: Colors.orange,
                  onTap: () => onSetStatus('active'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

// ── Shared Section Card ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}
