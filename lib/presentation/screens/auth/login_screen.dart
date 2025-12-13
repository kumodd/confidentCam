import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:country_code_picker/country_code_picker.dart';

import '../../../core/config/app_config.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import 'otp_verification_screen.dart';
import 'email_confirmation_screen.dart';

/// Modern unified login screen with phone and email options.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Phone auth
  final _phoneController = TextEditingController();
  String _countryCode = '+91';
  final _phoneFormKey = GlobalKey<FormState>();

  // Email auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final tabCount = _getEnabledTabCount();
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int _getEnabledTabCount() {
    int count = 0;
    if (AppConfig.enablePhoneAuth) count++;
    if (AppConfig.enableEmailAuth) count++;
    return count > 0 ? count : 1;
  }

  List<Widget> _buildTabs() {
    final tabs = <Widget>[];
    if (AppConfig.enablePhoneAuth) {
      tabs.add(const Tab(text: 'Phone'));
    }
    if (AppConfig.enableEmailAuth) {
      tabs.add(const Tab(text: 'Email'));
    }
    return tabs;
  }

  void _submitPhone() {
    if (_phoneFormKey.currentState?.validate() ?? false) {
      final phone = _phoneController.text.trim();
      context.read<AuthBloc>().add(PhoneSubmitted(phone));
    }
  }

  void _submitEmail() {
    if (_emailFormKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        context.read<AuthBloc>().add(
          EmailSignUpRequested(email: email, password: password),
        );
      } else {
        context.read<AuthBloc>().add(
          EmailSignInRequested(email: email, password: password),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          EasyLoading.show(
            status: _isSignUp ? 'Creating account...' : 'Signing in...',
          );
        } else {
          EasyLoading.dismiss();
        }

        if (state is AuthCodeSent) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => BlocProvider.value(
                    value: context.read<AuthBloc>(),
                    child: OtpVerificationScreen(phone: state.phone),
                  ),
            ),
          );
        } else if (state is EmailConfirmationRequired) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmailConfirmationScreen(email: state.email),
            ),
          );
        } else if (state is AuthFailure) {
          _showErrorDialog(state.message);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0A14), Color(0xFF1A1A2E), Color(0xFF16162A)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Animated background shapes
                _buildAnimatedBackground(),

                // Main content
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),

                      // Logo and branding
                      _buildHeader(),

                      const SizedBox(height: 48),

                      // Tab bar (if multiple auth methods)
                      if (_getEnabledTabCount() > 1) _buildTabBar(),

                      const SizedBox(height: 24),

                      // Auth forms
                      _buildAuthContent(),

                      const SizedBox(height: 32),

                      // Terms
                      _buildTerms(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.2, 1.2),
              duration: 4.seconds,
            ),
        Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.3, 1.3),
              duration: 5.seconds,
              delay: 1.seconds,
            ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App icon
        Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 40,
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.8, 0.8)),

        const SizedBox(height: 24),

        Text(
          'ConfidentCam',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: 8),

        Text(
          'Build camera confidence in 30 days',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: _buildTabs(),
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        dividerColor: Colors.transparent,
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildAuthContent() {
    if (_getEnabledTabCount() == 1) {
      if (AppConfig.enablePhoneAuth) {
        return _buildPhoneForm();
      } else {
        return _buildEmailForm();
      }
    }

    return SizedBox(
      height: AppConfig.enableEmailAuth && _isSignUp ? 400 : 320,
      child: TabBarView(
        controller: _tabController,
        children: [
          if (AppConfig.enablePhoneAuth) _buildPhoneForm(),
          if (AppConfig.enableEmailAuth) _buildEmailForm(),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone input card
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                CountryCodePicker(
                  onChanged:
                      (code) =>
                          setState(() => _countryCode = code.dialCode ?? '+1'),
                  initialSelection: 'IN',
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 16),
                  dialogTextStyle: const TextStyle(color: Colors.black),
                  searchStyle: const TextStyle(color: Colors.black),
                ),
                Container(width: 1, height: 30, color: Colors.white12),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'Phone number',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      if (value.length < 10) {
                        return 'Enter valid phone number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildSubmitButton(
            'Continue with Phone',
            _submitPhone,
            Icons.arrow_forward,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }

  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email input
          _buildTextField(
            controller: _emailController,
            hint: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password input
          _buildTextField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white38,
              ),
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          _buildSubmitButton(
            _isSignUp ? 'Create Account' : 'Sign In',
            _submitEmail,
            _isSignUp ? Icons.person_add : Icons.login,
          ),

          const SizedBox(height: 16),

          // Toggle sign up / sign in
          TextButton(
            onPressed: () => setState(() => _isSignUp = !_isSignUp),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white38),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSubmitButton(
    String text,
    VoidCallback onPressed,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTerms() {
    return Text(
      'By continuing, you agree to our Terms of Service and Privacy Policy',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.white38),
      textAlign: TextAlign.center,
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                SizedBox(width: 12),
                Text('Error', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
