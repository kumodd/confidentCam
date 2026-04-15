import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import 'otp_verification_screen.dart';

/// Phone entry screen for authentication.
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+91';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submitPhone() {
    if (_formKey.currentState?.validate() ?? false) {
      // final phone = '$_countryCode${_phoneController.text.trim()}';
      final phone = _phoneController.text.trim();
      context.read<AuthBloc>().add(PhoneSubmitted(phone));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          EasyLoading.show(status: 'Sending code...');
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
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // Header
                    Text(
                      'Welcome to',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: Colors.white70),
                    ).animate().fadeIn(duration: 400.ms),

                    Text(
                      'ConfidentCam',
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: 16),

                    Text(
                      'Enter your phone number to get started with your 30-day camera confidence journey.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white54,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                    const SizedBox(height: 48),

                    // Phone input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Country code picker
                          CountryCodePicker(
                            onChanged: (code) {
                              setState(() {
                                _countryCode = code.dialCode ?? '+1';
                              });
                            },
                            initialSelection: 'US',
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            dialogTextStyle: const TextStyle(
                              color: Colors.black,
                            ),
                            searchStyle: const TextStyle(color: Colors.black),
                          ),

                          // Divider
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white24,
                          ),

                          // Phone number input
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                letterSpacing: 1,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Phone number',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (value.length < 6) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: 24),

                    // Continue button
                    ElevatedButton(
                      onPressed: _submitPhone,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(fontSize: 18),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                    const Spacer(),

                    // Terms
                    Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white38),
                    ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
