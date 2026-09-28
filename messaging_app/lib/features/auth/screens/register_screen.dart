import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Step 0 = Email input, Step 1 = OTP code entry, Step 2 = Profile & password
  int _currentStep = 0;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() {
          _canResend = true;
          _resendCountdown = 0;
        });
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  void _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();

    final success = await auth.sendOtp(email);
    if (!mounted) return;

    if (success) {
      if (auth.lastOtpCode != null) {
        _otpController.text = auth.lastOtpCode!;
      }
      _startResendTimer();
      setState(() {
        _currentStep = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastOtpCode != null
              ? 'Verification Code: ${auth.lastOtpCode} (Auto-filled)'
              : 'Verification code sent to $email'),
          backgroundColor: AppTheme.whatsappGreenLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    final isValid = await auth.verifyOtp(email, otp);
    if (!mounted) return;

    if (isValid) {
      setState(() {
        _currentStep = 2;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Invalid or expired OTP code.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resendOtp() async {
    if (!_canResend) return;
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();

    final success = await auth.sendOtp(email);
    if (!mounted) return;

    if (success) {
      if (auth.lastOtpCode != null) {
        _otpController.text = auth.lastOtpCode!;
      }
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastOtpCode != null
              ? 'New OTP: ${auth.lastOtpCode} (Auto-filled)'
              : 'New code sent to $email'),
          backgroundColor: AppTheme.whatsappGreenLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _finishRegistration() async {
    if (!_profileFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    final success = await auth.registerWithOtp(
      email: _emailController.text.trim(),
      otpCode: _otpController.text.trim(),
      username: _usernameController.text.trim(),
      displayName: _displayNameController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register with Email OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(theme, auth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(ThemeData theme, AuthProvider auth) {
    switch (_currentStep) {
      case 0:
        return _buildEmailStep(theme, auth);
      case 1:
        return _buildOtpStep(theme, auth);
      case 2:
      default:
        return _buildProfileStep(theme, auth);
    }
  }

  Widget _buildEmailStep(ThemeData theme, AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.whatsappGreenLight.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                size: 40,
                color: AppTheme.whatsappGreenLight,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Enter your Email',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Messenger will send a 6-digit OTP code to verify your address. Only 1 account can be registered per email.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'name@example.com',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(val.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: auth.isLoading ? null : _sendOtp,
            child: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send Verification Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(ThemeData theme, AuthProvider auth) {
    final email = _emailController.text.trim();

    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.whatsappVibrantGreen.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 40,
                color: AppTheme.whatsappGreenLight,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verify Email Address',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit verification code to:\n$email',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (auth.lastOtpCode != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.whatsappVibrantGreen.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.whatsappVibrantGreen.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.whatsappGreenLight, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your code is ${auth.lastOtpCode} (auto-filled)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AppTheme.whatsappGreenLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
            ),
            validator: (val) {
              if (val == null || val.trim().length != 6) {
                return 'Please enter all 6 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _canResend
                    ? "Didn't receive the code?"
                    : "Resend code in ${_resendCountdown}s",
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (_canResend) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _resendOtp,
                  child: const Text('Resend OTP'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: auth.isLoading ? null : _verifyOtp,
            child: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep(ThemeData theme, AuthProvider auth) {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.whatsappGreenLight.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.whatsappGreenLight.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.whatsappGreenLight, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Verified',
                        style: TextStyle(
                          color: AppTheme.whatsappGreenLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _emailController.text.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Complete Your Profile',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your display name and password to finalize your account.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Display Name
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name / Display Name',
              prefixIcon: Icon(Icons.badge_outlined),
              hintText: 'e.g. Atharv Gujare',
            ),
            textInputAction: TextInputAction.next,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your display name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Username
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.alternate_email),
              hintText: 'e.g. atharv_gujare',
            ),
            textInputAction: TextInputAction.next,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a username';
              }
              final clean = val.trim().toLowerCase();
              if (clean.length < 3 || clean.length > 30) {
                return 'Username must be 3-30 characters';
              }
              final userRegex = RegExp(r'^[a-zA-Z0-9_.]+$');
              if (!userRegex.hasMatch(clean)) {
                return 'Only letters, numbers, underscores, and dots allowed';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter a password';
              }
              if (val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: auth.isLoading ? null : _finishRegistration,
            child: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}
