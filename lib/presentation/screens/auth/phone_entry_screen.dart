import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
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
      final rawPhone = _phoneController.text.trim();
      final localNumber =
          rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
      final phone = '$_countryCode$localNumber';
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
              builder: (_) => BlocProvider.value(
                value: context.read<AuthBloc>(),
                child: OtpVerificationScreen(phone: state.phone),
              ),
            ),
          );
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'WELCOME TO',
                    style: AppTypography.uppercaseLabel(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ConfidentCam',
                    style: AppTypography.headingLarge(
                      fontSize: 32,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your phone number to get started with your 30-day camera confidence journey.',
                    style: AppTypography.body(fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  SageCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'PHONE NUMBER',
                          style: AppTypography.uppercaseLabel(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: AppRadii.inputBorder,
                            border: Border.all(
                              color: AppColors.divider,
                              width: 1.3,
                            ),
                          ),
                          child: Row(
                            children: [
                              CountryCodePicker(
                                onChanged: (code) {
                                  setState(() {
                                    _countryCode = code.dialCode ?? '+1';
                                  });
                                },
                                initialSelection: 'IN',
                                showCountryOnly: false,
                                showOnlyCountryWhenClosed: false,
                                alignLeft: false,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                textStyle: GoogleFonts.manrope(
                                  color: AppColors.primaryText,
                                  fontSize: 16,
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
                              Container(
                                width: 1.2,
                                height: 28,
                                color: AppColors.divider,
                              ),
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
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
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
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitPhone,
                          child: Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      fontSize: 12.5,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
