import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TermsScreen extends StatelessWidget {
  final bool privacy;
  const TermsScreen({super.key, this.privacy = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(privacy ? 'Privacy Policy' : 'Terms of Service'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          privacy ? _privacy : _terms,
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

const _terms = '''CLUBHOUSE STAKES — TERMS OF SERVICE
Last updated: 2026

1. ACCEPTANCE
By creating an account or using Clubhouse Stakes ("the Service"), you agree to these Terms.

2. ELIGIBILITY
You must be at least 18 years old (or the legal age of majority in your jurisdiction) to register for paid tournaments. By signing up, you represent that you meet this requirement and that participation in skill-based golf contests is legal in your location.

3. SKILL-BASED CONTESTS
Tournaments offered through the Service are skill-based competitions. Outcomes are determined by golf scores, not chance. Sign-up fees fund the prize pool plus a service fee.

4. ACCOUNTS
You are responsible for keeping your password and account credentials secure. You agree to provide accurate information including your handicap. False handicaps may result in disqualification and forfeiture of fees.

5. PAYMENTS AND REFUNDS
All entry fees are processed at registration. Refunds are issued only when a tournament is cancelled by the host or when you withdraw before the registration cutoff posted on the tournament page.

6. SCORING AND DISPUTES
Scores entered through the app are subject to verification. The tournament host or platform admins may correct scores or disqualify entries that violate posted rules. Disputes must be raised within 48 hours of round completion.

7. CONDUCT
You agree not to cheat, manipulate scores, share accounts, or otherwise interfere with fair competition. Violations may result in account termination and forfeiture of any pending payouts.

8. CLUBHOUSE / HOST CONTENT
Clubs and tournament hosts are responsible for the accuracy of course information, rules, and payouts they post. Clubhouse Stakes is a platform; we do not guarantee third-party content.

9. LIMITATION OF LIABILITY
The Service is provided "as is." To the maximum extent permitted by law, Clubhouse Stakes is not liable for indirect or consequential damages arising from use of the Service.

10. CHANGES
We may update these Terms. Continued use after an update constitutes acceptance.

11. CONTACT
Questions: support@clubhousestakes.com
''';

const _privacy = '''CLUBHOUSE STAKES — PRIVACY POLICY
Last updated: 2026

1. INFORMATION WE COLLECT
- Account info: name, email, password (hashed), city, handicap, profile picture.
- Tournament data: registrations, scores, payouts, skins entries.
- Device info: standard request metadata (IP, user agent) for security and analytics.

2. HOW WE USE IT
- Operate the Service: run tournaments, score rounds, process payouts.
- Account security and fraud prevention.
- Improve the product and notify you about events you have signed up for.

3. SHARING
- With other users: your name, profile picture, handicap, and tournament results are visible to other participants.
- With service providers: hosting, payments, email — only as needed to run the Service.
- We do not sell your personal information.

4. RETENTION
We retain account data while your account is active. You can request deletion by emailing support@clubhousestakes.com; we keep limited records as required by law (tax / payment compliance).

5. SECURITY
Passwords are hashed. Tokens are stored in your device's secure storage. We use HTTPS for all API traffic.

6. CHILDREN
The Service is not directed at users under 18.

7. CONTACT
support@clubhousestakes.com
''';
