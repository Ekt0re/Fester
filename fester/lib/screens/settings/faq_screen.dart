import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          'FAQ',
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
            'Come creo un nuovo evento?',
            'Dalla schermata principale, tocca il pulsante "+" in basso a destra e segui la procedura guidata.',
          ),
          _buildFAQItem(
            theme,
            'Come aggiungo membri allo staff?',
            'Vai nella dashboard dell\'evento, seleziona "Gestisci staff" e tocca "Aggiungi membro".',
          ),
          _buildFAQItem(
            theme,
            'Posso modificare il menù dopo aver creato l\'evento?',
            'Sì, puoi modificare il menù in qualsiasi momento dalla sezione "Gestione Menù".',
          ),
          _buildFAQItem(
            theme,
            'Come funzionano le notifiche?',
            'Le notifiche ti avvisano di nuovi ingressi, ordini o messaggi importanti. Puoi configurarle nelle impostazioni.',
          ),
          _buildFAQItem(
            theme,
            'È possibile esportare i dati?',
            'Sì, dalla sezione statistiche puoi esportare i report in vari formati.',
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
