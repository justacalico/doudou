import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/jellyfin_models.dart';
import '../services/audio/base_audio_handler.dart';

class DynamicIsle extends StatefulWidget {
  const DynamicIsle({super.key});

  @override
  State<DynamicIsle> createState() => _DynamicIsleState();
}

class _DynamicIsleState extends State<DynamicIsle>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _pulseController;
  late Animation<double> _expandAnimation;
  late Animation<double> _pulseAnimation;
  
  bool _isExpanded = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start pulse animation for playing state
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _expandController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentTrack = appState.audioHandler?.currentTrack;
        
        // Check if playing by looking at the audio handler's current state or user intent
        bool isPlaying = false;
        if (appState.audioHandler != null) {
          // Try to get the playing state from different sources
          try {
            final state = appState.audioHandler!.currentState;
            isPlaying = state == AudioPlayerState.playing;
          } catch (e) {
            // Fallback to user intended playing
            try {
              isPlaying = appState.audioHandler!.userIntendedPlaying ?? false;
            } catch (e2) {
              isPlaying = false;
            }
          }
        }
        
        // Hide when no track is playing
        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_expandAnimation, _pulseAnimation]),
              builder: (context, child) {
                final shouldPulse = isPlaying && !_isExpanded && !_isDragging;
                final scale = shouldPulse ? _pulseAnimation.value : 1.0;
                
                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: _toggleExpanded,
                    onPanStart: (_) => setState(() => _isDragging = true),
                    onPanEnd: (_) => setState(() => _isDragging = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: _isExpanded ? 350 : 150,
                      height: _isExpanded ? 90 : 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPlaying 
                            ? CupertinoColors.systemPurple.withOpacity(0.6)
                            : CupertinoColors.systemGrey4.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                          if (isPlaying)
                            BoxShadow(
                              color: CupertinoColors.systemPurple.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _isExpanded 
                          ? _buildExpandedContent(context, appState, currentTrack, isPlaying)
                          : _buildCompactContent(context, appState, currentTrack, isPlaying),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactContent(BuildContext context, AppState appState, Track currentTrack, bool isPlaying) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform indicator
          SizedBox(
            width: 24,
            height: 24,
            child: _buildWaveform(isPlaying),
          ),
          
          const SizedBox(width: 8),
          
          // Track title (truncated)
          Expanded(
            child: Text(
              currentTrack.name,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Play/pause icon
          Icon(
            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            color: CupertinoColors.systemPurple,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context, AppState appState, Track currentTrack, bool isPlaying) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Album art
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF2C2C2E),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: currentTrack.imageUrl != null
                ? Image.network(
                    appState.getImageUrl(currentTrack.imageUrl!, width: 132, height: 132),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      CupertinoIcons.music_note,
                      color: CupertinoColors.systemGrey,
                      size: 24,
                    ),
                  )
                : const Icon(
                    CupertinoIcons.music_note,
                    color: CupertinoColors.systemGrey,
                    size: 24,
                  ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Track info and controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Track name
                Text(
                  currentTrack.name,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 2),
                
                // Artist name
                Text(
                  currentTrack.artistName ?? 'Unknown Artist',
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                // Mini progress bar
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: StreamBuilder<Duration>(
                    stream: appState.audioHandler?.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = appState.audioHandler?.duration ?? Duration.zero;
                      final progress = duration.inMilliseconds > 0 
                        ? position.inMilliseconds / duration.inMilliseconds 
                        : 0.0;
                      
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemPurple,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Control buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button
              GestureDetector(
                onTap: () => appState.skipToPrevious(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.backward_fill,
                    color: CupertinoColors.white,
                    size: 16,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Play/pause button
              GestureDetector(
                onTap: () => appState.playPause(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.systemPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                    color: CupertinoColors.white,
                    size: 18,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Next button
              GestureDetector(
                onTap: () => appState.skipToNext(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.forward_fill,
                    color: CupertinoColors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          width: 3,
          height: isPlaying ? (8 + (index % 2 * 8)).toDouble() : 6,
          decoration: BoxDecoration(
            color: isPlaying 
              ? CupertinoColors.systemPurple
              : CupertinoColors.systemGrey,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}