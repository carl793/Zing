import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/remote_photo.dart';

/// Full-screen photo viewer pushed as a new route (pure black background).
class PhotoLightboxScreen extends StatelessWidget {
  final String url;
  const PhotoLightboxScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: AppColors.coral, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      '[ X ]',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.coral,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.cyan, width: 2),
                ),
                child: InteractiveViewer(
                  child: RemotePhoto(url, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}