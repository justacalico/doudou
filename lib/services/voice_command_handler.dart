import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'voice_command_service.dart';

/// Widget that handles Google Assistant voice commands
/// Wraps the app and listens for voice command events
class VoiceCommandHandler extends StatefulWidget {
  final Widget child;

  const VoiceCommandHandler({super.key, required this.child});

  @override
  State<VoiceCommandHandler> createState() => _VoiceCommandHandlerState();
}

class _VoiceCommandHandlerState extends State<VoiceCommandHandler> {
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  StreamSubscription<VoiceCommand>? _commandSubscription;

  @override
  void initState() {
    super.initState();
    _initializeVoiceCommands();
  }

  Future<void> _initializeVoiceCommands() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _voiceCommandService.initialize();

        // Listen for voice commands
        _commandSubscription = _voiceCommandService.commandStream.listen(
          _handleVoiceCommand,
          onError: (error) {
            // Error in command stream
          },
        );

        // Check for pending command from cold start
        if (_voiceCommandService.pendingCommand != null) {
          // Delay to ensure app state is ready
          await Future.delayed(const Duration(milliseconds: 500));
          _handleVoiceCommand(_voiceCommandService.pendingCommand!);
          _voiceCommandService.clearPendingCommand();
        }
      } catch (e) {
        // Failed to initialize
      }
    }
  }

  void _handleVoiceCommand(VoiceCommand command) {
    // Get app state and handle the command
    final appState = Provider.of<AppState>(context, listen: false);

    // Check if app state is ready
    if (!appState.isInitialized) {
      // Retry after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _handleVoiceCommand(command);
        }
      });
      return;
    }

    // Check if user is logged in (required for most commands)
    if (!appState.isLoggedIn && command.type != VoiceCommandType.unknown) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a server in Settings to use voice commands')),
        );
      }
      return;
    }

    // Pass command to app state for handling
    appState.handleVoiceCommand(command);
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension to easily access voice command service
extension VoiceCommandExtension on BuildContext {
  /// Get the voice command service
  VoiceCommandService get voiceCommands => VoiceCommandService();
}
