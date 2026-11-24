import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/sprite_options.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/widgets/onboarding_progress_bar.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../../../core/widgets/sprite_selector.dart';
import '../../../data/repositories/user_repository.dart';

class SpriteSelectScreen extends StatefulWidget {
  const SpriteSelectScreen({super.key});
  @override
  State<SpriteSelectScreen> createState() => _SpriteSelectScreenState();
}

class _SpriteSelectScreenState extends State<SpriteSelectScreen> {
  String _selectedSprite = SpriteOptions.fallback;
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _googleEmail;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _name.text = user.displayName!.toUpperCase();
    }
    _googleEmail = user?.providerData.any((p) => p.providerId == 'google.com') == true
        ? user?.email
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'ENTER A DISPLAY NAME.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final authService = context.read<AuthService>();
    final users = context.read<UserRepository>();
    try {
      // Sign-up may not have managed to create the profile.
      await authService.ensureProfile();
      await users.saveProfile(
        authService.currentUser!.uid,
        displayName: name,
        avatarSpriteId: _selectedSprite,
      );
    } catch (e) {
      debugPrint('Saving profile failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "COULDN'T SAVE. CHECK YOUR CONNECTION.";
      });
      return;
    }
    if (!mounted) return;
    // pushReplacementNamed so back button cannot return here
    Navigator.of(context).pushReplacementNamed(AppRoutes.pairing);
  }

  @override
  Widget build(BuildContext context) {
    // PopScope blocks the system back button on this screen
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: PixelBackdrop(
          child: SafeArea(
            child: PixelColumn(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                          AppSpacing.lg, AppSpacing.lg + 4, AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            child: OnboardingProgressBar(currentStep: 2),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const Text(
                            'CHOOSE YOUR HERO',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.header,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Center(
                            child: Container(
                              width: 128,
                              height: 128,
                              decoration: const PixelInset(),
                              child: Center(
                                child: SpriteIdle(
                                  child: SpriteAvatar(
                                    spriteId: _selectedSprite,
                                    size: 104,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PixelPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SpriteSelector(
                                  selectedId: _selectedSprite,
                                  onSelected: (id) =>
                                      setState(() => _selectedSprite = id),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                PixelField(
                                  label: 'DISPLAY NAME',
                                  hint: 'YOUR NAME',
                                  icon: PixelIcons.user,
                                  controller: _name,
                                  maxLength: 20,
                                  enabled: !_saving,
                                  hasError: _error != null,
                                  textColor: AppColors.yellow,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _continue(),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  PixelNote.error(_error!),
                                ],
                              ],
                            ),
                          ),
                          if (_googleEmail != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Signed in with Google as $_googleEmail',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  PixelActionBar(
                    child: PixelButton(
                      label: 'CONTINUE',
                      icon: PixelIcons.right,
                      busy: _saving,
                      onPressed: _continue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
