import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:ui';
import '../../../providers/app_state.dart';
import '../../../models/jellyfin_models.dart';
import '../../playing/now_playing.dart';
import '../../../widgets/cached_image_widget.dart';
import '../../../widgets/apple_design/apple_theme.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final audioHandler = appState.audioHandler;
        
        // Return empty widget if no audio handler
        if (audioHandler == null) {
          return const SizedBox.shrink();
        }

        // Use the currentTrackStream for reliable real-time updates
        return StreamBuilder<Track?>(
          stream: appState.currentTrackStream,
          builder: (context, currentTrackSnapshot) {
            // Get current track from the stream or fallback to direct access
            final currentTrack = currentTrackSnapshot.data ?? audioHandler.currentTrack;
            
            // Return empty widget if no track is playing
            if (currentTrack == null) {
              return const SizedBox.shrink();
            }

            // Determine if we're on a desktop platform
            final isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.linux ||
                                          defaultTargetPlatform == TargetPlatform.macOS ||
                                          defaultTargetPlatform == TargetPlatform.windows) || kIsWeb;
            
            if (isDesktop) {
              return _buildDesktopMiniPlayer(context, appState, audioHandler, currentTrack);
            }
            
            return _buildMobileMiniPlayer(context, appState, audioHandler, currentTrack, isDark);
          },
        );
      },
    );
  }

  Widget _buildMobileMiniPlayer(
    BuildContext context, 
    AppState appState, 
    dynamic audioHandler, 
    Track currentTrack,
    bool isDark,
  ) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: () => _navigateToNowPlaying(context),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  // iOS 26 liquid glass effect
                  color: (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
                      .withOpacity(isDark ? 0.15 : 0.08),
                  border: Border.all(
                    color: (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
                        .withOpacity(0.12),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Album Art with enhanced shadow
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AlbumArtWidget(
                            imageUrl: currentTrack.imageUrl != null
                                ? appState.getImageUrl(
                                    currentTrack.imageUrl!,
                                    width: 100,
                                    height: 100,
                                  )
                                : null,
                            size: 52,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      
                      // Track Info with enhanced typography
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentTrack.name,
                              style: TextStyle(
                                fontFamily: AppleDesignSystem.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark 
                                    ? const Color(0xFFFFFFFF) 
                                    : const Color(0xFF000000),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentTrack.artistName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                currentTrack.artistName!,
                                style: TextStyle(
                                  fontFamily: AppleDesignSystem.fontFamily,
                                  fontSize: 13,
                                  color: (isDark 
                                      ? const Color(0xFFFFFFFF) 
                                      : const Color(0xFF000000))
                                      .withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Control Buttons with liquid glass style
                      StreamBuilder<PlayerState>(
                        stream: appState.playerStateStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data?.playing == true;
                          final processingState = snapshot.data?.processingState ?? ProcessingState.idle;
                          
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Play/Pause Button
                              _LiquidGlassControlButton(
                                icon: isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                isLoading: processingState == ProcessingState.loading ||
                                           processingState == ProcessingState.buffering,
                                onTap: () {
                                  if (kDebugMode) {
                                    print('=== MINI PLAYER PLAY/PAUSE BUTTON TAPPED ===');
                                    print('isPlaying: $isPlaying');
                                    print('processingState: $processingState');
                                    print('audioHandler.userIntendedPlaying: ${audioHandler.userIntendedPlaying}');
                                  }
                                  appState.playPause();
                                },
                                isDark: isDark,
                              ),
                              const SizedBox(width: 4),
                              // Next Button
                              _LiquidGlassControlButton(
                                icon: CupertinoIcons.forward_fill,
                                onTap: audioHandler.hasNext == true
                                    ? () => appState.skipToNext()
                                    : null,
                                isDark: isDark,
                                disabled: audioHandler.hasNext != true,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopMiniPlayer(
    BuildContext context, 
    AppState appState, 
    dynamic audioHandler, 
    Track currentTrack,
  ) {
    return SizedBox(
      height: 70,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppleDesignSystem.blurThin,
            sigmaY: AppleDesignSystem.blurThin,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppleColors.glassDark,
            ),
            child: GestureDetector(
              onTap: () => _navigateToNowPlaying(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    AlbumArtWidget(
                      imageUrl: currentTrack.imageUrl != null
                          ? appState.getImageUrl(
                              currentTrack.imageUrl!,
                              width: 100,
                              height: 100,
                            )
                          : null,
                      size: 50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentTrack.name,
                            style: AppleTextStyles.headline(
                              color: AppleColors.labelPrimaryDark,
                            ).copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (currentTrack.artistName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              currentTrack.artistName!,
                              style: AppleTextStyles.footnote(
                                color: AppleColors.labelSecondaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    StreamBuilder<PlayerState>(
                      stream: appState.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing == true;
                        final processingState = snapshot.data?.processingState ?? ProcessingState.idle;
                        
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => appState.playPause(),
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: processingState == ProcessingState.loading ||
                                        processingState == ProcessingState.buffering
                                    ? const CupertinoActivityIndicator(
                                        color: Color(0xFFFFFFFF),
                                      )
                                    : Icon(
                                        isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                        size: 24,
                                        color: const Color(0xFFFFFFFF),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: audioHandler.hasNext == true
                                  ? () => appState.skipToNext()
                                  : null,
                              child: Icon(
                                CupertinoIcons.forward_fill,
                                size: 24,
                                color: audioHandler.hasNext == true 
                                    ? const Color(0xFFFFFFFF)
                                    : CupertinoColors.systemGrey2,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToNowPlaying(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const NowPlayingScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

class _LiquidGlassControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;
  final bool isLoading;
  final bool disabled;

  const _LiquidGlassControlButton({
    required this.icon,
    this.onTap,
    required this.isDark,
    this.isLoading = false,
    this.disabled = false,
  });

  @override
  State<_LiquidGlassControlButton> createState() => _LiquidGlassControlButtonState();
}

class _LiquidGlassControlButtonState extends State<_LiquidGlassControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => _controller.forward(),
      onTapUp: widget.disabled ? null : (_) => _controller.reverse(),
      onTapCancel: widget.disabled ? null : () => _controller.reverse(),
      onTap: widget.disabled ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: widget.isLoading
                ? CupertinoActivityIndicator(
                    color: widget.isDark 
                        ? const Color(0xFFFFFFFF) 
                        : const Color(0xFF000000),
                  )
                : Icon(
                    widget.icon,
                    size: 24,
                    color: widget.disabled
                        ? (widget.isDark 
                            ? const Color(0xFFFFFFFF) 
                            : const Color(0xFF000000)).withOpacity(0.3)
                        : (widget.isDark 
                            ? const Color(0xFFFFFFFF) 
                            : const Color(0xFF000000)),
                  ),
          ),
        ),
      ),
    );
  }
}
