import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SendReviewStep extends StatelessWidget {
  final int recipientCount;
  final String templateName;
  final String subject;
  final bool isSending;
  final VoidCallback onSend;

  const SendReviewStep({
    super.key,
    required this.recipientCount,
    required this.templateName,
    required this.subject,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: Color(0xFFE94560),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pronto per l\'invio!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                _buildInfoRow(
                  Icons.people_outline,
                  'Destinatari',
                  recipientCount.toString(),
                ),
                const Divider(height: 32),
                _buildInfoRow(Icons.article_outlined, 'Template', templateName),
                const Divider(height: 32),
                _buildInfoRow(
                  Icons.subject,
                  'Oggetto',
                  subject.isEmpty ? '(Default)' : subject,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              child:
                  isSending
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'INVIA ORA',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'L\'invio potrebbe richiedere alcuni minuti.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
