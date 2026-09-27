import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_api_service.dart';
import 'features/chats/screens/home_shell_screen.dart';
import 'features/users/providers/user_search_provider.dart';
import 'features/users/services/user_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services
  final localStorage = await LocalStorage.create();
  final apiClient = ApiClient(localStorage);
  final authApiService = AuthApiService(apiClient);
  final authProvider = AuthProvider(authApiService, localStorage);
  final userApiService = UserApiService(apiClient);
  final userSearchProvider = UserSearchProvider(userApiService);

  // Attempt auto-login with stored tokens
  await authProvider.tryAutoLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UserSearchProvider>.value(value: userSearchProvider),
      ],
      child: const MessengerApp(),
    ),
  );
}

class MessengerApp extends StatelessWidget {
  const MessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isInitialized && auth.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (auth.isAuthenticated) {
            return const HomeShellScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
