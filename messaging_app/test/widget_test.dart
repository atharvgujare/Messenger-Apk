import 'package:flutter_test/flutter_test.dart';
import 'package:messaging_app/features/auth/screens/login_screen.dart';
import 'package:messaging_app/features/auth/providers/auth_provider.dart';
import 'package:messaging_app/features/auth/services/auth_api_service.dart';
import 'package:messaging_app/core/network/api_client.dart';
import 'package:messaging_app/core/storage/local_storage.dart';
import 'package:messaging_app/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Renders Login Screen with Messenger header and inputs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorage(prefs);
    final apiClient = ApiClient(localStorage);
    final authApiService = AuthApiService(apiClient);
    final authProvider = AuthProvider(authApiService, localStorage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('Welcome to Messenger'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register now'), findsOneWidget);
  });
}
