import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';
import '../logger_service.dart';

/// Modello per le credenziali SMTP di un evento
class SmtpConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool ssl;
  final String senderName;
  final String senderEmail;

  SmtpConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.ssl = true,
    required this.senderName,
    required this.senderEmail,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'ssl': ssl,
    'sender_name': senderName,
    'sender_email': senderEmail,
  };

  factory SmtpConfig.fromJson(Map<String, dynamic> json) => SmtpConfig(
    host: json['host'] ?? '',
    port: json['port'] ?? 587,
    username: json['username'] ?? '',
    password: json['password'] ?? '',
    ssl: json['ssl'] ?? true,
    senderName: json['sender_name'] ?? '',
    senderEmail: json['sender_email'] ?? '',
  );
}

/// Risultato dell'invio di un messaggio
class SendResult {
  final String recipientEmail;
  final bool success;
  final String? error;

  SendResult({required this.recipientEmail, required this.success, this.error});
}

/// Riepilogo dell'invio massivo
class BulkSendReport {
  final int totalSent;
  final int successCount;
  final int failureCount;
  final List<SendResult> results;

  BulkSendReport({
    required this.totalSent,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });
}

class EmailService {
  static const String _tag = 'EmailService';

  /// Invia una singola email
  Future<SendResult> sendEmail({
    required SmtpConfig config,
    required String recipientEmail,
    required String subject,
    required String htmlBody,
    String? textBody,
    List<Attachment>? attachments,
  }) async {
    if (kIsWeb) {
      final errorMsg =
          '🌐 SMTP non supportato su Web Browser\n'
          'Motivo: I browser bloccano le connessioni socket TCP dirette per sicurezza.\n'
          'Soluzione: Usa l\'app nativa (Android/iOS/Desktop) per inviare email.\n'
          'Server tentato: ${config.host}:${config.port}';

      LoggerService.error(
        'Tentativo invio email da Web bloccato',
        tag: _tag,
        error: errorMsg,
      );

      return SendResult(
        recipientEmail: recipientEmail,
        success: false,
        error: errorMsg,
      );
    }

    try {
      // 465 è tipicamente SSL/TLS implicito (ssl: true)
      // 587 è tipicamente STARTTLS (ssl: false inizialmente)
      final useSsl = config.port == 465 || config.ssl;

      final smtpServer = SmtpServer(
        config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        ssl: useSsl,
        // Se non è SSL diretto sulla 465, abilitiamo STARTTLS
        allowInsecure: config.port != 465,
      );

      final message =
          Message()
            ..from = Address(config.senderEmail, config.senderName)
            ..recipients.add(recipientEmail)
            ..subject = subject
            ..html = htmlBody;

      if (textBody != null) {
        message.text = textBody;
      }

      if (attachments != null) {
        message.attachments.addAll(attachments);
      }

      await send(message, smtpServer);

      LoggerService.info('Email sent to $recipientEmail', tag: _tag);
      return SendResult(recipientEmail: recipientEmail, success: true);
    } catch (e) {
      LoggerService.error(
        'Failed to send email to $recipientEmail',
        tag: _tag,
        error: e,
      );
      return SendResult(
        recipientEmail: recipientEmail,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Invia email a più destinatari
  Future<BulkSendReport> sendBulkEmail({
    required SmtpConfig config,
    required List<String> recipientEmails,
    required String subject,
    required String htmlBody,
    String? textBody,
    List<Attachment>? attachments,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <SendResult>[];
    int successCount = 0;
    int failureCount = 0;

    for (int i = 0; i < recipientEmails.length; i++) {
      final email = recipientEmails[i];

      final result = await sendEmail(
        config: config,
        recipientEmail: email,
        subject: subject,
        htmlBody: htmlBody,
        textBody: textBody,
        attachments: attachments,
      );

      results.add(result);
      if (result.success) {
        successCount++;
      } else {
        failureCount++;
      }

      onProgress?.call(i + 1, recipientEmails.length);

      // Piccola pausa per evitare rate limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return BulkSendReport(
      totalSent: recipientEmails.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }

  /// Testa la connessione SMTP
  Future<bool> testConnection(SmtpConfig config) async {
    if (kIsWeb) {
      LoggerService.error(
        '🌐 ========================================',
        tag: _tag,
      );
      LoggerService.error('❌ SMTP NON SUPPORTATO SU WEB BROWSER', tag: _tag);
      LoggerService.error('🔍 Motivo tecnico:', tag: _tag);
      LoggerService.error(
        '   I browser bloccano le connessioni socket TCP dirette (RawSocket)',
        tag: _tag,
      );
      LoggerService.error(
        '   necessarie per comunicare con i server SMTP.',
        tag: _tag,
      );
      LoggerService.error('📱 Soluzione:', tag: _tag);
      LoggerService.error(
        '   Usa l\'app nativa per Android, iOS o Desktop',
        tag: _tag,
      );
      LoggerService.error(
        '   dove le connessioni socket sono disponibili.',
        tag: _tag,
      );
      LoggerService.error('🖥️  Configurazione tentata:', tag: _tag);
      LoggerService.error('   Host: ${config.host}', tag: _tag);
      LoggerService.error('   Porta: ${config.port}', tag: _tag);
      LoggerService.error('   SSL: ${config.ssl}', tag: _tag);
      LoggerService.error('   Username: ${config.username}', tag: _tag);
      LoggerService.error(
        '========================================',
        tag: _tag,
      );
      return false;
    }

    try {
      final useSsl = config.port == 465 || config.ssl;

      final smtpServer = SmtpServer(
        config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        ssl: useSsl,
        allowInsecure: config.port != 465,
      );

      final message =
          Message()
            ..from = Address(config.senderEmail, config.senderName)
            ..recipients.add(config.senderEmail)
            ..subject = 'Fester SMTP Test'
            ..text = 'This is a test email from Fester.';

      await send(message, smtpServer);
      LoggerService.info('SMTP connection test successful', tag: _tag);
      return true;
    } catch (e) {
      LoggerService.error('SMTP connection test failed', tag: _tag, error: e);
      return false;
    }
  }

  /// Genera l'HTML del biglietto con QR Code
  String generateTicketHtml({
    required String guestName,
    required String eventName,
    required String qrCodeData,
    required String eventDate,
    String? eventLocation,
    String? customCss,
  }) {
    final defaultCss = '''
      body { font-family: 'Segoe UI', Arial, sans-serif; background: #1a1a2e; color: #ffffff; margin: 0; padding: 20px; }
      .ticket { max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #16213e 0%, #0f0f23 100%); border-radius: 20px; overflow: hidden; box-shadow: 0 10px 40px rgba(0,0,0,0.5); }
      .header { background: linear-gradient(90deg, #e94560 0%, #ff6b9d 100%); padding: 30px; text-align: center; }
      .header h1 { margin: 0; font-size: 28px; text-transform: uppercase; letter-spacing: 2px; }
      .content { padding: 30px; text-align: center; }
      .guest-name { font-size: 24px; font-weight: bold; margin-bottom: 20px; color: #e94560; }
      .event-info { margin: 20px 0; padding: 20px; background: rgba(255,255,255,0.05); border-radius: 12px; }
      .event-info p { margin: 8px 0; font-size: 16px; }
      .qr-container { margin: 30px 0; padding: 20px; background: #ffffff; border-radius: 16px; display: inline-block; }
      .qr-container img { width: 200px; height: 200px; }
      .footer { padding: 20px; text-align: center; font-size: 12px; color: #888; border-top: 1px solid rgba(255,255,255,0.1); }
    ''';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Biglietto - $eventName</title>
  <style>${customCss ?? defaultCss}</style>
</head>
<body>
  <div class="ticket">
    <div class="header">
      <h1>$eventName</h1>
    </div>
    <div class="content">
      <div class="guest-name">$guestName</div>
      <div class="event-info">
        <p><strong>📅 Data:</strong> $eventDate</p>
        ${eventLocation != null ? '<p><strong>📍 Luogo:</strong> $eventLocation</p>' : ''}
      </div>
      <div class="qr-container">
        <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$qrCodeData" alt="QR Code">
      </div>
      <p style="font-size: 14px; color: #888;">Mostra questo QR Code all'ingresso</p>
    </div>
    <div class="footer">
      <p>Generato da Fester App</p>
    </div>
  </div>
</body>
</html>
    ''';
  }
}
