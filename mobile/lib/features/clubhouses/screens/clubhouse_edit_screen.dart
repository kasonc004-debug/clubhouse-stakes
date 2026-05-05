import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/image_uploader.dart';
import '../../../core/widgets/cs_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/course_provider.dart';
import '../../courses/widgets/course_picker.dart';
import '../../players/providers/player_provider.dart';
import '../models/clubhouse_model.dart';
import '../providers/clubhouse_provider.dart';

/// Create-or-edit form for the host's own clubhouse page.
class ClubhouseEditScreen extends ConsumerStatefulWidget {
  final ClubhouseModel? existing;
  const ClubhouseEditScreen({super.key, this.existing});

  @override
  ConsumerState<ClubhouseEditScreen> createState() => _ClubhouseEditScreenState();
}

class _ClubhouseEditScreenState extends ConsumerState<ClubhouseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name    = TextEditingController(text: widget.existing?.name ?? '');
  late final _course  = TextEditingController(text: widget.existing?.courseName ?? '');
  late final _city    = TextEditingController(text: widget.existing?.city ?? '');
  late final _state   = TextEditingController(text: widget.existing?.state ?? '');
  late final _country = TextEditingController(text: widget.existing?.country ?? '');
  late final _about   = TextEditingController(text: widget.existing?.about ?? '');
  late final _logo    = TextEditingController(text: widget.existing?.logoUrl ?? '');
  late final _banner  = TextEditingController(text: widget.existing?.bannerUrl ?? '');

  late String _primary = widget.existing?.primaryColor ?? '#1B3D2C';
  late String _accent  = widget.existing?.accentColor  ?? '#C9A84C';
  late bool   _isPublic = widget.existing?.isPublic ?? true;

  // Course (from golfcourseapi). Only meaningful on the create flow; on edit
  // we don't expose a way to change it for now.
  CourseSummary? _pickedCourse;
  bool _loadingCourse = false;

  bool _uploadingLogo   = false;
  bool _uploadingBanner = false;

  // Owner picker — admin-only on create, owner/admin on edit (for transfers).
  PlayerProfile? _selectedOwner;        // null → keep current / default to me
  String?        _ownerSearchQuery;
  Timer?         _ownerDebounce;
  final _ownerSearchCtrl = TextEditingController();
  bool _ownerPickerOpen = false;

  @override
  void dispose() {
    _ownerDebounce?.cancel();
    _ownerSearchCtrl.dispose();
    for (final c in [_name, _course, _city, _state, _country, _about, _logo, _banner]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndUpload({required bool banner}) async {
    setState(() => banner ? _uploadingBanner = true : _uploadingLogo = true);
    try {
      final url = await ref.read(imageUploaderProvider).pickAndUpload(
            maxWidth: banner ? 2000 : 600,
          );
      if (!mounted || url == null) return;
      setState(() => banner ? _banner.text = url : _logo.text = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) {
        setState(() => banner ? _uploadingBanner = false : _uploadingLogo = false);
      }
    }
  }

  Future<void> _onCoursePicked(CourseSummary c) async {
    setState(() {
      _pickedCourse = c;
      _loadingCourse = true;
    });
    try {
      final detail =
          await ref.read(courseDetailProvider(c.id.toString()).future);
      if (!mounted) return;
      setState(() {
        _course.text = detail.displayName;
        if (detail.city != null && detail.city!.isNotEmpty) {
          _city.text = detail.city!;
        } else if (c.city != null) {
          _city.text = c.city!;
        }
        if (detail.state != null && detail.state!.isNotEmpty) {
          _state.text = detail.state!;
        } else if (c.state != null) {
          _state.text = c.state!;
        }
        if (detail.country != null && detail.country!.isNotEmpty) {
          _country.text = detail.country!;
        } else if (c.country != null) {
          _country.text = c.country!;
        }
      });
    } catch (_) {
      // If the detail fetch fails, fall back to summary fields.
      if (!mounted) return;
      setState(() {
        _course.text = c.displayName;
        if (c.city != null) _city.text = c.city!;
        if (c.state != null) _state.text = c.state!;
        if (c.country != null) _country.text = c.country!;
      });
    } finally {
      if (mounted) setState(() => _loadingCourse = false);
    }
  }

  void _clearCourse() {
    setState(() {
      _pickedCourse = null;
      _course.clear();
    });
  }

  Widget _ownerSection() {
    final isCreate = widget.existing == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('OWNER',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_selectedOwner != null)
            _PickedOwnerCard(
              player: _selectedOwner!,
              onClear: () => setState(() {
                _selectedOwner = null;
                _ownerSearchCtrl.clear();
                _ownerSearchQuery = null;
                _ownerPickerOpen = false;
              }),
            )
          else
            Row(children: [
              const Icon(Icons.person_outline, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCreate
                      ? (widget.existing == null
                          ? 'You\'ll be the owner unless you pick someone below.'
                          : '')
                      : 'Current owner: ${widget.existing!.ownerName ?? 'unknown'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _ownerPickerOpen = !_ownerPickerOpen),
                icon: Icon(
                    _ownerPickerOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.search,
                    size: 16),
                label: Text(_ownerPickerOpen ? 'Close' : 'Pick'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          if (_ownerPickerOpen && _selectedOwner == null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _ownerSearchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) {
                _ownerDebounce?.cancel();
                _ownerDebounce =
                    Timer(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() => _ownerSearchQuery =
                        v.trim().length >= 2 ? v.trim() : null);
                  }
                });
              },
            ),
            if (_ownerSearchQuery != null) ...[
              const SizedBox(height: 8),
              _OwnerSearchResults(
                query: _ownerSearchQuery!,
                onPick: (p) => setState(() {
                  _selectedOwner = p;
                  _ownerPickerOpen = false;
                }),
              ),
            ],
          ],
          if (!isCreate && _selectedOwner != null) ...[
            const SizedBox(height: 10),
            const Text(
              'Saving will transfer ownership of this clubhouse. The new owner '
              'gets full edit + ownership rights; you keep access only if you\'re '
              'a system admin or staff.',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.textSecondary),
            ),
          ],
        ]),
      ),
    ]);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'name':         _name.text.trim(),
      'course_name':  _course.text.trim().isEmpty ? null : _course.text.trim(),
      'city':         _city.text.trim().isEmpty ? null : _city.text.trim(),
      'state':        _state.text.trim().isEmpty ? null : _state.text.trim(),
      'country':      _country.text.trim().isEmpty ? null : _country.text.trim(),
      'about':        _about.text.trim().isEmpty ? null : _about.text.trim(),
      'logo_url':     _logo.text.trim().isEmpty ? null : _logo.text.trim(),
      'banner_url':   _banner.text.trim().isEmpty ? null : _banner.text.trim(),
      'primary_color': _primary,
      'accent_color':  _accent,
      'is_public':         _isPublic,
      if (_pickedCourse != null) 'course_api_id': _pickedCourse!.id.toString(),
      if (_selectedOwner != null) 'owner_id': _selectedOwner!.id,
    };

    final notifier = ref.read(clubhouseEditProvider.notifier);
    final result = widget.existing == null
        ? await notifier.create(data)
        : await notifier.update(widget.existing!.id, data);
    if (!mounted) return;

    if (result != null) {
      ref.invalidate(myClubhousesProvider);
      ref.invalidate(publicClubhousesProvider);
      ref.invalidate(clubhouseBySlugProvider(result.slug));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existing == null ? 'Clubhouse created!' : 'Saved!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      context.pop();
    } else {
      final err = ref.read(clubhouseEditProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Save failed'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubhouseEditProvider);
    final loading = state.isLoading;
    final me = ref.watch(authProvider).user;
    // Show the owner picker when:
    //  - creating (admin assigning to a course pro / external owner), OR
    //  - editing AND the current user is the owner OR a system admin (transfer flow)
    final isAdmin = me?.isAdmin == true;
    final isOwnerOnEdit =
        widget.existing != null && me != null && me.id == widget.existing!.ownerId;
    final showOwnerPicker = (widget.existing == null && isAdmin) ||
        (widget.existing != null && (isAdmin || isOwnerOnEdit));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Clubhouse' : 'Edit Clubhouse'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Clubhouse name *',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Course search via golfcourseapi — fills city/state/country.
            if (_course.text.isEmpty)
              CourseSearchField(
                label: 'Course *',
                onPicked: _onCoursePicked,
              )
            else
              _PickedCourseCard(
                courseName: _course.text,
                location: [
                  _city.text, _state.text, _country.text,
                ].where((s) => s.isNotEmpty).join(', '),
                loading: _loadingCourse,
                onClear: _clearCourse,
              ),
            const SizedBox(height: 14),

            // Location — auto-filled from the course pick, still editable.
            Row(children: [
              Expanded(child: TextFormField(controller: _city,
                decoration: const InputDecoration(labelText: 'City'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _state,
                decoration: const InputDecoration(labelText: 'State'))),
            ]),
            const SizedBox(height: 14),
            TextFormField(controller: _country,
              decoration: const InputDecoration(labelText: 'Country')),
            const SizedBox(height: 18),

            // Owner picker (admin / current owner only)
            if (showOwnerPicker) _ownerSection(),
            if (showOwnerPicker) const SizedBox(height: 18),

            // Single Public / Private toggle for the clubhouse page.
            _ToggleCard(
              title: 'Public clubhouse',
              subtitle: _isPublic
                  ? 'Anyone can find this clubhouse and view its tournaments.'
                  : 'Only members and people you invite can view this page.',
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            const SizedBox(height: 18),

            const Text('BRANDING',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),

            _ImagePickerRow(
              label: 'Logo',
              icon: Icons.image_outlined,
              url: _logo.text,
              uploading: _uploadingLogo,
              onPick: () => _pickAndUpload(banner: false),
              onClear: () => setState(() => _logo.clear()),
              square: true,
            ),
            const SizedBox(height: 10),
            _ImagePickerRow(
              label: 'Banner',
              icon: Icons.panorama_outlined,
              url: _banner.text,
              uploading: _uploadingBanner,
              onPick: () => _pickAndUpload(banner: true),
              onClear: () => setState(() => _banner.clear()),
              square: false,
            ),
            const SizedBox(height: 14),

            _ColorRow(
              label: 'Primary color',
              value: _primary,
              onChanged: (v) => setState(() => _primary = v),
            ),
            const SizedBox(height: 8),
            _ColorRow(
              label: 'Accent color',
              value: _accent,
              onChanged: (v) => setState(() => _accent = v),
            ),
            const SizedBox(height: 18),

            TextFormField(
              controller: _about,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'About',
                alignLabelWithHint: true,
                helperText:
                    'Tell visitors about your clubhouse, tee times, dress code, etc.',
              ),
            ),
            const SizedBox(height: 24),

            CSButton(label: 'Save', loading: loading, onPressed: _save),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      );
}

class _ColorRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _ColorRow({required this.label, required this.value, required this.onChanged});

  // Compact, opinionated palette so admins don't have to know hex.
  static const _palette = <String>[
    '#1B3D2C', '#2A5940', '#4F7942', '#6CA66C',
    '#0D47A1', '#1565C0', '#2196F3',
    '#5E35B1', '#7B1FA2',
    '#C9A84C', '#E2A33A', '#D84315',
    '#37474F', '#212121',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(value.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in _palette)
            GestureDetector(
              onTap: () => onChanged(c),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _hex(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.toUpperCase() == value.toUpperCase()
                        ? Colors.white
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: c.toUpperCase() == value.toUpperCase()
                      ? [
                          BoxShadow(
                              color: _hex(c).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _PickedCourseCard extends StatelessWidget {
  final String courseName;
  final String location;
  final bool loading;
  final VoidCallback onClear;
  const _PickedCourseCard({
    required this.courseName,
    required this.location,
    required this.loading,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.4), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.golf_course,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('COURSE',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    if (location.isNotEmpty)
                      Text(location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                  ]),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
              ),
          ]),
          if (!loading) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Change course'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ]),
      );
}

class _PickedOwnerCard extends StatelessWidget {
  final PlayerProfile player;
  final VoidCallback onClear;
  const _PickedOwnerCard({required this.player, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.person, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    'HCP ${player.handicap.toStringAsFixed(1)}'
                    '${player.city != null ? ' · ${player.city}' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ]),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
            tooltip: 'Clear',
          ),
        ]),
      );
}

class _OwnerSearchResults extends ConsumerWidget {
  final String query;
  final void Function(PlayerProfile) onPick;
  const _OwnerSearchResults({required this.query, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playerSearchProvider(query));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 10),
          Text('Searching…',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
      error: (e, _) => Text('Search failed: $e',
          style: const TextStyle(fontSize: 12, color: AppColors.error)),
      data: (players) {
        if (players.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No players found.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < players.length && i < 8; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.divider),
                ListTile(
                  dense: true,
                  title: Text(players[i].name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    'HCP ${players[i].handicap.toStringAsFixed(1)}'
                    '${players[i].city != null ? ' · ${players[i].city}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.add, size: 18),
                  onTap: () => onPick(players[i]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String url;
  final bool uploading;
  final bool square;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _ImagePickerRow({
    required this.label,
    required this.icon,
    required this.url,
    required this.uploading,
    required this.square,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: square ? 64 : 96,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Icon(icon, color: AppColors.textSecondary),
                )
              : Icon(icon, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              hasImage ? 'Tap to replace.' : 'Pick from your library.',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ]),
        ),
        if (uploading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary)),
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.upload_outlined, size: 22),
            onPressed: onPick,
            tooltip: 'Upload',
          ),
          if (hasImage)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClear,
              tooltip: 'Remove',
            ),
        ],
      ]),
    );
  }
}

Color _hex(String s) {
  final h = s.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'ff$h' : h, radix: 16) ?? 0xff1B3D2C;
  return Color(v);
}
