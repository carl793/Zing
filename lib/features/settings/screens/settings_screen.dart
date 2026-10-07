import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/sprite_options.dart';
import '../../../core/models/couple_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/couple_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/sprite_selector.dart';
import '../../../core/services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _me;
  CoupleModel? _couple;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _cityCtrl;
  String? _selectedSprite;
  int _cityResolveSequence = 0;

  bool _bgmOn = AudioService.instance.bgmEnabled;
  bool _sfxOn = AudioService.instance.sfxEnabled;
  bool _alertsOn = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final fs = context.read<FirestoreService>();
    final uid = auth.currentUser!.uid;
    final mySnap = await fs.doc('users/$uid').get();
    final me = UserModel.fromMap(uid, mySnap.data()!);
    _me = me;
    _nameCtrl.text = me.displayName;
    _cityCtrl.text = me.homeCity;
    _selectedSprite = me.avatarSpriteId.isNotEmpty
        ? me.avatarSpriteId
        : SpriteOptions.all.first;

    if (me.coupleId != null) {
      final cSnap = await fs.doc('couples/${me.coupleId}').get();
      if (cSnap.exists) {
        _couple = CoupleModel.fromMap(cSnap.id, cSnap.data()!);
        _alertsOn = _couple!.settings.reunionAlerts;
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.coral,
            content: Text(
              'NAME CANNOT BE EMPTY.',
              style: AppTextStyles.caption.copyWith(color: AppColors.yellow),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    final fs = context.read<FirestoreService>();
    final uid = _me!.uid;
    setState(() => _saving = true);
    var saveSucceeded = true;
    final city = _cityCtrl.text.trim();
    final cityChanged = city.toLowerCase() != _me!.homeCity.toLowerCase();
    final sprite = _selectedSprite ?? SpriteOptions.all.first;
    try {
      final updates = <String, dynamic>{
        'displayName': name,
        'avatarSpriteId': sprite,
        'homeCity': city,
        if (cityChanged) 'homeLocation': FieldValue.delete(),
      };
      await fs.updateDoc('users/$uid', updates);
      _me = UserModel.fromMap(uid, {
        ..._me!.toMap(),
        ...updates,
        if (cityChanged) 'homeLocation': null,
      });
    } catch (e) {
      debugPrint('Settings save error: $e');
      saveSucceeded = false;
    }
    if (mounted) setState(() => _saving = false);

    if (saveSucceeded &&
        city.isNotEmpty &&
        (cityChanged || _me!.homeLocation == null)) {
      final sequence = ++_cityResolveSequence;
      unawaited(_resolveHomeCity(uid, city, sequence));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.purple,
          content: Text(
            !saveSucceeded
                ? 'COULD NOT SAVE SETTINGS. TRY AGAIN.'
                : 'SETTINGS SAVED.',
            style: AppTextStyles.caption.copyWith(color: AppColors.yellow),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resolveHomeCity(String uid, String city, int sequence) async {
    final service = context.read<LocationService>();
    final location = await service.geocodeHomeCity(city);
    if (location == null ||
        !mounted ||
        sequence != _cityResolveSequence ||
        _cityCtrl.text.trim().toLowerCase() != city.toLowerCase()) {
      return;
    }
    try {
      await context.read<FirestoreService>().updateDoc('users/$uid', {
        'homeLocation': location,
      });
      if (!mounted || sequence != _cityResolveSequence) return;
      _me = UserModel.fromMap(uid, {
        ..._me!.toMap(),
        'homeCity': city,
        'homeLocation': location,
      });
    } catch (e) {
      debugPrint('Saving home city coordinates failed: $e');
    }
  }

  Future<void> _toggleBgm(bool val) async {
    setState(() => _bgmOn = val);
    await AudioService.instance.setBgmEnabled(val);
  }

  Future<void> _toggleSfx(bool val) async {
    setState(() => _sfxOn = val);
    await AudioService.instance.setSfxEnabled(val);
  }

  Future<void> _toggleAlerts(bool val) async {
    setState(() => _alertsOn = val);
    if (_me?.coupleId != null) {
      await context.read<FirestoreService>().updateDoc(
        'couples/${_me!.coupleId}',
        {'settings.reunionAlerts': val},
      );
    }
  }

  Future<void> _unlink() async {
    if (_me?.coupleId == null || _couple == null) return;
    final confirmed = await showConfirmDialog(
      context: context,
      message:
          'UNLINK FROM YOUR PARTNER?\n\nAll memories and chests are preserved, '
          'but you will both need to re-pair to reconnect.',
      confirmLabel: '[ YES, UNLINK ]',
      cancelLabel: '[ KEEP LINKED ]',
    );
    if (!confirmed || !mounted) return;
    await context.read<CoupleService>().unlinkPartners(
      coupleId: _me!.coupleId!,
      memberUids: _couple!.memberUids,
    );
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.pairing, (_) => false);
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    await auth.logout();
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(child: CircularProgressIndicator(color: AppColors.yellow)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──
              Text(
                'SYSTEM CONFIG',
                textAlign: TextAlign.center,
                style: AppTextStyles.header.copyWith(
                  fontSize: 15,
                  color: AppColors.cyan,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Profile ──
              _Section(
                title: 'PLAYER PROFILE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DISPLAY NAME', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    _InsetTextField(controller: _nameCtrl, hint: 'YOUR NAME'),
                    const SizedBox(height: AppSpacing.md),
                    Text('HERO SPRITE', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    SpriteSelector(
                      selectedId: _selectedSprite ?? SpriteOptions.fallback,
                      onSelected: (sprite) =>
                          setState(() => _selectedSprite = sprite),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Location fallback ──
              _Section(
                title: 'DISTANCE ENGINE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOME CITY (LOCATION FALLBACK)',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 6),
                    _InsetTextField(
                      controller: _cityCtrl,
                      hint: 'e.g. MANILA, PHILIPPINES',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'USED WHEN GPS IS OFF. SHOWN AS APPROXIMATE DISTANCE.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray,
                        fontSize: 7,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Row(
                      label: 'UNIT PREFERENCE',
                      child: Row(
                        children: [
                          _UnitChip(
                            label: 'KM',
                            active: (_couple?.unitPref ?? 'km') == 'km',
                            onTap: () => _setUnit('km'),
                          ),
                          const SizedBox(width: 8),
                          _UnitChip(
                            label: 'MI',
                            active: (_couple?.unitPref ?? 'km') == 'mi',
                            onTap: () => _setUnit('mi'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Audio ──
              _Section(
                title: 'AUDIO & ALERTS',
                child: Column(
                  children: [
                    _ToggleRow(
                      label: '8-BIT BGM',
                      value: _bgmOn,
                      onChanged: _toggleBgm,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ToggleRow(
                      label: 'CHIPTUNE SFX',
                      value: _sfxOn,
                      onChanged: _toggleSfx,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ToggleRow(
                      label: 'REUNION COUNTDOWN ALERTS',
                      value: _alertsOn,
                      onChanged: _toggleAlerts,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Room info ──
              if (_me?.coupleId != null && _couple != null)
                _Section(
                  title: 'ROOM INFO',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ROOM ID', style: AppTextStyles.label),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.charcoal,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _couple!.pairingCode,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '(REFERENCE ONLY)',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 5,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),

              // ── Save button ──
              PixelButton(
                label: _saving ? 'SAVING...' : '[ SAVE SETTINGS ]',
                style: PixelButtonStyle.yellow,
                onPressed: _saving ? null : _saveProfile,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Danger zone ──
              _Section(
                title: 'DANGER ZONE',
                borderColor: AppColors.coral,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PixelButton(
                      label: '[ UNLINK PARTNER ROOM ]',
                      style: PixelButtonStyle.outlineDanger,
                      backgroundColor: AppColors.charcoal,
                      onPressed: _unlink,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PixelButton(label: '[ LOGOUT ]', onPressed: _logout),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setUnit(String unit) async {
    if (_me?.coupleId == null) return;
    setState(() {
      if (_couple != null) {
        _couple = CoupleModel.fromMap(_couple!.coupleId, {
          ..._couple!.toMap(),
          'unitPref': unit,
        });
      }
    });
    await context.read<FirestoreService>().updateDoc(
      'couples/${_me!.coupleId}',
      {'unitPref': unit},
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Color borderColor;
  const _Section({
    required this.title,
    required this.child,
    this.borderColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.label.copyWith(
              color: AppColors.cyan,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InsetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _InsetTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        style: AppTextStyles.body.copyWith(
          color: AppColors.yellow,
          fontSize: 8,
        ),
        cursorColor: AppColors.cyan,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body.copyWith(
            color: const Color(0xFF555577),
            fontSize: 8,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: AppColors.cyan,
              fontSize: 7,
            ),
          ),
        ),
        _PixelSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PixelSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PixelSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.playSfx(AppSfx.tap);
        onChanged(!value);
      },
      child: Container(
        width: 38,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Row(
          mainAxisAlignment: value
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              color: value ? AppColors.yellow : AppColors.gray,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _UnitChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.yellow : AppColors.charcoal,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 7,
            color: active ? Colors.black : AppColors.cyan,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.cyan,
            fontSize: 7,
          ),
        ),
        child,
      ],
    );
  }
}

// Add toMap() to CoupleModel if missing — used by _setUnit above
extension CoupleModelX on CoupleModel {
  Map<String, dynamic> toMap() => {
    'memberUids': memberUids,
    'pairingCode': pairingCode,
    'status': status.name,
    'unitPref': unitPref,
    'linkedAt': linkedAt,
    'settings': settings.toMap(),
    'reunionQuest': reunionQuest.toMap(),
  };
}
