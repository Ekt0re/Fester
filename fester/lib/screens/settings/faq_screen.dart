import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'faq.title'.tr(),
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFAQItem(
            theme,
            'faq.q1'.tr(),
            'faq.a1'.tr(),
          ),
          _buildFAQItem(
            theme,
            'faq.q2'.tr(),
            'faq.a2'.tr(),
          ),
          _buildFAQItem(
            theme,
            'faq.q3'.tr(),
            'faq.a3'.tr(),
          ),
          _buildFAQItem(
            theme,
            'faq.q4'.tr(),
            'faq.a4'.tr(),
          ),
          _buildFAQItem(
            theme,
            'faq.q5'.tr(),
            'faq.a5'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(ThemeData theme, String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
