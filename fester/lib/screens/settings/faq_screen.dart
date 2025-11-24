import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFAQItem(
            context,
            'How do I create an event?',
            'To create an event, tap the "+" button on the dashboard and follow the step-by-step wizard. You\'ll need to provide event details, set dates, and configure guest options.',
          ),
          const SizedBox(height: 12),
          _buildFAQItem(
            context,
            'How do I scan QR codes?',
            'Use the QR scanner feature from the dashboard. Point your camera at the QR code and the app will automatically recognize and process it.',
          ),
          const SizedBox(height: 12),
          _buildFAQItem(
            context,
            'Can I export guest lists?',
            'Yes! You can export guest lists as PDF or CSV files from the guest list screen. Look for the export button in the top-right corner.',
          ),
          const SizedBox(height: 12),
          _buildFAQItem(
            context,
            'How do I manage staff permissions?',
            'Staff permissions can be managed through the Staff section. You can add staff members and assign different roles and access levels.',
          ),
          const SizedBox(height: 12),
          _buildFAQItem(
            context,
            'Is my data secure?',
            'Yes, we use industry-standard encryption and secure servers to protect your data. All connections are encrypted.',
          ),
          const SizedBox(height: 12),
          _buildFAQItem(
            context,
            'How do I contact support?',
            'You can contact support through the Settings screen under "Contact Support" or email us directly at support@fester.app.',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
