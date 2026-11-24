import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import 'otp_verification_screen.dart';
import 'email_confirmation_screen.dart';

/// Unified login screen in the minimalist sage & olive design system.
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
  final bool _isSignUp = false;
  // ignore: unused_field
  final bool _obscurePassword = true;

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
      tabs.add(Tab(text: 'Phone'));
    }
    if (AppConfig.enableEmailAuth) {
      tabs.add(Tab(text: 'Email'));
    }
    return tabs;
  }

  void _submitPhone() {
    if (_phoneFormKey.currentState?.validate() ?? false) {
      final rawPhone = _phoneController.text.trim();
      final localNumber =
          rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
      final phone = '$_countryCode$localNumber';
      context.read<AuthBloc>().add(PhoneSubmitted(phone));
    }
  }

  void _submitEmail() {
    if (_emailFormKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      context.read<AuthBloc>().add(EmailOtpRequested(email));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          EasyLoading.show(status: 'Sending verification code...');
        } else {
          EasyLoading.dismiss();
        }

        if (state is AuthCodeSent) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<AuthBloc>(),
                child: OtpVerificationScreen(
                  phone: state.phone,
                  isEmail: state.isEmail,
                ),
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
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Top brand bar + hero arc header
                _buildHeader(),

                const SizedBox(height: 28),

                // Status banner card
                SageStatusCard(
                  title: '30-Day Camera Confidence',
                  subtitle:
                      'Daily guided warmups, AI teleprompter scripts, and structured practice',
                  actionLabel: 'Ready',
                ),

                const SizedBox(height: 20),

                // Auth card
                SageCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: AppColors.primaryOlive,
                          ),
                          Text(
                            'AUTHENTICATION',
                            style: AppTypography.uppercaseLabel(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1.2,
                        color: AppColors.divider,
                      ),
                      const SizedBox(height: 18),
                      if (_getEnabledTabCount() > 1) ...[
                        _buildTabBar(),
                        const SizedBox(height: 20),
                      ],
                      _buildAuthContent(),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Terms
                _buildTerms(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ConfidentCam',
              style: AppTypography.headingLarge(fontSize: 24),
            ),
            OlivePillBadge(
              label: '30-Day Program',
              icon: Icons.videocam_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        OliveArcGauge(
          progress: 1.0,
          primaryValue: '30',
          primaryUnit: 'd',
          statusLabel: 'CAMERA CONFIDENCE',
          pillText: 'Daily Practice',
          size: 224,
        ).animate().fadeIn(duration: 450.ms),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: _buildTabs(),
        indicator: BoxDecoration(
          color: AppColors.navPill,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primaryText,
        unselectedLabelColor: AppColors.secondaryText,
        labelStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
      ),
    );
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
      height: AppConfig.enableEmailAuth && _isSignUp ? 360 : 290,
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
          Text(
            'PHONE NUMBER',
            style: AppTypography.uppercaseLabel(
              fontSize: 11,
              color: AppColors.secondaryText,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadii.inputBorder,
              border: Border.all(color: AppColors.divider, width: 1.3),
            ),
            child: Row(
              children: [
                CountryCodePicker(
                  onChanged: (code) =>
                      setState(() => _countryCode = code.dialCode ?? '+1'),
                  initialSelection: 'IN',
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: GoogleFonts.manrope(
                    color: AppColors.primaryText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                  dialogBackgroundColor: AppColors.background,
                  dialogTextStyle: GoogleFonts.inter(
                    color: AppColors.primaryText,
                  ),
                  searchStyle: GoogleFonts.inter(
                    color: AppColors.primaryText,
                  ),
                ),
                Container(width: 1.2, height: 28, color: AppColors.divider),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.manrope(
                      color: AppColors.primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Phone number',
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.mutedText,
                        fontSize: 15,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
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
          const SizedBox(height: 22),
          _buildSubmitButton(
            'Continue with Phone',
            _submitPhone,
            Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'EMAIL ADDRESS',
            style: AppTypography.uppercaseLabel(
              fontSize: 11,
              color: AppColors.secondaryText,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _emailController,
            hint: 'Enter your email address',
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
          const SizedBox(height: 10),
          Text(
            'We will send a 6-digit verification code to your email',
            style: AppTypography.body(
              fontSize: 12.5,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          _buildSubmitButton(
            'Continue with Email',
            _submitEmail,
            Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
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
        color: AppColors.background,
        borderRadius: AppRadii.inputBorder,
        border: Border.all(color: AppColors.divider, width: 1.3),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          color: AppColors.primaryText,
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppColors.mutedText),
          prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 20),
          suffixIcon: suffixIcon,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
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
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryOlive,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.buttonBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.background,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: AppColors.background, size: 19),
        ],
      ),
    );
  }

  Widget _buildTerms() {
    return Text(
      'By continuing, you agree to our Terms of Service and Privacy Policy',
      style: AppTypography.body(
        fontSize: 12.5,
        color: AppColors.mutedText,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text('Sign In Issue', style: AppTypography.headingMedium()),
          ],
        ),
        content: Text(
          message,
          style: AppTypography.body(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
