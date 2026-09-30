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

import 'core/network/signalr_service.dart';
import 'features/chats/providers/chat_provider.dart';
import 'features/calls/providers/call_provider.dart';
import 'features/calls/widgets/incoming_call_dialog.dart';

import 'core/theme/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  await NotificationService.instance.initialize();

  // Initialize Core Services
  final localStorage = await LocalStorage.create();
  final apiClient = ApiClient(localStorage);
  final authApiService = AuthApiService(apiClient);
  final authProvider = AuthProvider(authApiService, localStorage);
  final userApiService = UserApiService(apiClient);
  final userSearchProvider = UserSearchProvider(userApiService);
  final signalRService = SignalRService(localStorage);
  final chatProvider = ChatProvider(apiClient, signalRService, authProvider);
  final callProvider = CallProvider(signalRService);
  final themeProvider = ThemeProvider();

  // Attempt auto-login with stored tokens
  await authProvider.tryAutoLogin();

  if (authProvider.isAuthenticated) {
    chatProvider.connectRealTime();
    chatProvider.loadConversations();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UserSearchProvider>.value(value: userSearchProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ChangeNotifierProvider<CallProvider>.value(value: callProvider),
      ],
      child: const MessengerApp(),
    ),
  );
}

class MessengerApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MessengerApp({super.key});

  @override
  State<MessengerApp> createState() => _MessengerAppState();
}

class _MessengerAppState extends State<MessengerApp> {
  CallProvider? _callProvider;
  bool _showingIncomingDialog = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newCallProvider = context.watch<CallProvider>();
    if (_callProvider != newCallProvider) {
      _callProvider = newCallProvider;
    }

    if (_callProvider?.status == CallStatus.incoming &&
        _callProvider?.incomingCall != null &&
        !_showingIncomingDialog) {
      _showingIncomingDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = MessengerApp.navigatorKey.currentContext;
        if (navContext != null && _callProvider?.incomingCall != null) {
          IncomingCallDialog.show(navContext, _callProvider!.incomingCall!);
        }
      });
    } else if (_callProvider?.status != CallStatus.incoming) {
      _showingIncomingDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: MessengerApp.navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

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
