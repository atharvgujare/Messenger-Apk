import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../providers/auth_provider.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _countryCode = '+91';
  bool _codeSent = false;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _secondsRemaining = 60;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _fullPhoneNumber {
    var raw = _phoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (raw.startsWith('+')) return raw;
    return '$_countryCode$raw';
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
                    defaultTargetPlatform == TargetPlatform.linux || 
                    defaultTargetPlatform == TargetPlatform.macOS)) {
      setState(() {
        _errorMessage = 'SMS authentication is supported on Android & iOS mobile devices. Please run on Android or use Email/Password on Desktop.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution on Android devices via Google Play Services
          if (mounted) {
            setState(() {
              _isVerifying = true;
            });
            await _signInWithCredential(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isSending = false;
            _errorMessage = e.message ?? 'Verification failed. Please check phone number.';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isSending = false;
            _codeSent = true;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent successfully to $_fullPhoneNumber'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = 'Failed to request OTP: ${e.toString()}';
      });
    }
  }

  Future<void> _verifyOtpAndLogin() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit OTP code.');
      return;
    }

    if (_verificationId == null) {
      setState(() => _errorMessage = 'Session expired. Please request a new code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e.message ?? 'Invalid OTP code. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Verification error: ${e.toString()}';
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.phoneLogin(
        phoneNumber: _fullPhoneNumber,
        firebaseIdToken: idToken,
        displayName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = authProvider.errorMessage ?? 'Backend authentication failed.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Authentication error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Number Login'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_chat_read_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _codeSent ? 'Enter 6-Digit OTP' : 'Verify Your Phone Number',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Google sent a 6-digit code via SMS to $_fullPhoneNumber'
                        : 'Messenger will send an SMS OTP to verify your mobile device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  if (!_codeSent) ...[
                    // Optional Display Name for first-time signup
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name (Optional)',
                        hintText: 'e.g. Atharv Gujare',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Phone input with country code
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 85,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _countryCode,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                                DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                                DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                                DropdownMenuItem(value: '+971', child: Text('🇦🇪 +971')),
                                DropdownMenuItem(value: '+61', child: Text('🇦🇺 +61')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _countryCode = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '9876543210',
                              prefixIcon: Icon(Icons.phone_android_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Enter phone number';
                              }
                              final clean = val.replaceAll(' ', '').replaceAll('-', '');
                              if (clean.length < 8) {
                                return 'Invalid phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSending ? null : _sendVerificationCode,
                      child: _isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Send Verification SMS'),
                    ),
                  ] else ...[
                    // OTP Input
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.security_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _otpController.clear(),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.trim().length == 6) {
                          _verifyOtpAndLogin();
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyOtpAndLogin,
                      child: _isVerifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Verify & Continue'),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _codeSent = false;
                              _otpController.clear();
                              _errorMessage = null;
                            });
                          },
                          child: const Text('Edit Phone Number'),
                        ),
                        TextButton(
                          onPressed: (_secondsRemaining == 0 && !_isSending)
                              ? _sendVerificationCode
                              : null,
                          child: Text(
                            _secondsRemaining > 0
                                ? 'Resend in ${_secondsRemaining}s'
                                : 'Resend Code',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
