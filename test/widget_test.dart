import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:inventra/core/theme/app_colors.dart';
import 'package:inventra/core/config/app_config.dart';

void main() {
  test('AppColors tokens are defined', () {
    expect(AppColors.accentTeal, const Color(0xFF00BFA5));
    expect(AppColors.bgDark, const Color(0xFF060D12));
  });

  test('AppConfig constants are configured', () {
    expect(AppConfig.supabaseUrl.isNotEmpty, true);
    expect(AppConfig.supabaseAnonKey.isNotEmpty, true);
  });
}
