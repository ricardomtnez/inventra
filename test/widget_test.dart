import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:inventra/core/theme/app_theme.dart';
import 'package:inventra/core/config/app_config.dart';

void main() {
  test('AppTheme configurations', () {
    expect(AppTheme.accentColor, const Color(0xFF2563EB));
    expect(AppTheme.primaryColor, const Color(0xFF0F172A));
  });

  test('AppConfig constants are configured', () {
    expect(AppConfig.supabaseUrl.isNotEmpty, true);
    expect(AppConfig.supabaseAnonKey.isNotEmpty, true);
  });
}

