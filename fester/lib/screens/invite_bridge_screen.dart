// lib/screens/invite_bridge_screen.dart
// Bridge screen for handling invite links from web to native app
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteBridgeScreen extends StatefulWidget {
  final String? inviteType; // 'staff', 'guest', etc.
  final String? targetId; // userId for staff invite, eventId for guest invite
  final String? eventId; // eventId for staff invite (when event-specific)

  const InviteBridgeScreen({
    super.key,
    this.inviteType,
    this.targetId,
    this.eventId,
  });

  @override
  State<InviteBridgeScreen> createState() => _InviteBridgeScreenState();
}

class _InviteBridgeScreenState extends State<InviteBridgeScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // On native platforms, process immediately
    if (!UniversalPlatform.isWeb) {
      _processInviteNative();
    }
  }

  Future<void> _processInviteNative() async {
    if (widget.inviteType == null || widget.targetId == null) {
      setState(() => _errorMessage = 'Invite link non valido');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        // User not logged in, redirect to login with return path
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      if (widget.inviteType == 'staff') {
        // Staff invite: associate current user with the inviter and specific event
        await _handleStaffInvite(
          widget.targetId!,
          eventId: widget.eventId,
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Errore: $e';
      });
    }
  }

  Future<void> _handleStaffInvite(
    String inviterUserId, {
    String? eventId,
  }) async {
    // Logic to handle staff invite
    // If eventId is provided, redirect directly to that event
    // Otherwise, redirect to event selection
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eventId != null
                ? 'Invito accettato! Reindirizzamento all\'evento...'
                : 'Invito accettato! Seleziona un evento.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      if (eventId != null) {
        context.go('/event/$eventId');
      } else {
        context.go('/event-selection');
      }
    }
  }

  Future<void> _openInNativeApp() async {
    // Construct the native app deep link
    String deepLinkPath;
    if (widget.eventId != null && widget.inviteType == 'staff') {
      // Include eventId for event-specific staff invites
      deepLinkPath = 'fester://invite/${widget.inviteType ?? ""}/${widget.eventId}/${widget.targetId ?? ""}';
    } else {
      deepLinkPath = 'fester://invite/${widget.inviteType ?? ""}/${widget.targetId ?? ""}';
    }
    
    final nativeUri = Uri.parse(deepLinkPath);

    try {
      final canLaunch = await canLaunchUrl(nativeUri);
      if (canLaunch) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App Fester non installata. Continua nel browser.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _continueInBrowser() {
    // Process the invite in browser
    _processInviteNative();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Native platforms: show loading while processing
    if (!UniversalPlatform.isWeb) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child:
              _isProcessing
                  ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Elaborazione invito...'),
                    ],
                  )
                  : _errorMessage != null
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Torna alla Home'),
                      ),
                    ],
                  )
                  : const CircularProgressIndicator(),
        ),
      );
    }

    // Web: Show bridge page with options
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.celebration,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Hai ricevuto un invito!',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                widget.inviteType == 'staff'
                    ? 'Sei stato invitato come membro dello staff'
                    : 'Apri con l\'app Fester per continuare',
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Open in App Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openInNativeApp,
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Apri nell\'App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Continue in Browser Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _continueInBrowser,
                  icon: const Icon(Icons.web),
                  label: const Text('Continua nel Browser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Footer
              Text(
                'Fester 3.0',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
