import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Banner animado que aparece/desaparece según el estado de conectividad.
/// Diseño: pill flotante con animación de slide-down.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService().isOffline,
      builder: (_, isOffline, __) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: isOffline
              ? _OfflinePill(key: const ValueKey('offline'))
              : const SizedBox.shrink(key: ValueKey('online')),
        );
      },
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentAmberDim,
        border: const Border(
          bottom: BorderSide(color: AppColors.accentAmber, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.accentAmber,
            size: 15,
          ),
          const SizedBox(width: 8),
          Text(
            'Sin conexión — mostrando datos en caché',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.accentAmber,
            ),
          ),
        ],
      ),
    );
  }
}
