import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lyrics_service.dart';
import '../providers/app_state.dart';

/// Shows the synchronized lyrics overlay with karaoke-style highlighting
void showSyncedLyricsOverlay(BuildContext context, String trackName, String artistName) {
  showCupertinoModalPopup(
    context: context,
    barrierColor: Colors.black.withOpacity(0.3),
    builder: (context) => SyncedLyricsOverlay(
      trackName: trackName,
      artistName: artistName,
    ),
  );
}

class SyncedLyricsOverlay extends StatefulWidget {
  final String trackName;
  final String artistName;

  const SyncedLyricsOverlay({
    super.key,
    required this.trackName,
    required this.artistName,
  });

  @override
  State<SyncedLyricsOverlay> createState() => _SyncedLyricsOverlayState();
}

class _SyncedLyricsOverlayState extends State<SyncedLyricsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  LyricsResult? _lyricsResult;
  bool _isLoading = true;
  int _currentLineIndex = -1;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _lineKeys = [];
  
  // Throttling for position updates
  Duration _lastPosition = Duration.zero;
  bool _isUpdatingLine = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    _loadLyrics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final result = await LyricsService.fetchLyrics(widget.trackName, widget.artistName);
      
      setState(() {
        _lyricsResult = result;
        _isLoading = false;
        
        // Initialize line keys for scrolling
        if (result?.syncedLyrics != null) {
          _lineKeys.clear();
          for (int i = 0; i < result!.syncedLyrics!.length; i++) {
            _lineKeys.add(GlobalKey());
          }
        }
      });
    } catch (e) {
      setState(() {
        _lyricsResult = null;
        _isLoading = false;
      });
    }
  }

  void _updateCurrentLine(Duration position) {
    if (_lyricsResult?.syncedLyrics == null || _isUpdatingLine) return;
    
    // Throttle updates to prevent excessive rebuilds
    if ((position - _lastPosition).abs() < const Duration(milliseconds: 100)) {
      return;
    }
    
    _lastPosition = position;
    
    final lines = _lyricsResult!.syncedLyrics!;
    int newLineIndex = -1;
    
    // Find the current line based on position
    for (int i = 0; i < lines.length; i++) {
      if (position >= lines[i].timestamp) {
        newLineIndex = i;
      } else {
        break;
      }
    }
    
    if (newLineIndex != _currentLineIndex) {
      _isUpdatingLine = true;
      
      // Use post frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentLineIndex = newLineIndex;
          });
          
          // Auto-scroll to current line
          if (newLineIndex >= 0 && newLineIndex < _lineKeys.length) {
            _scrollToCurrentLine();
          }
          
          _isUpdatingLine = false;
        }
      });
    }
  }

  void _scrollToCurrentLine() {
    if (_currentLineIndex >= 0 && 
        _currentLineIndex < _lineKeys.length && 
        _scrollController.hasClients) {
      
      // Calculate the scroll position to center the current line
      final itemHeight = 70.0; // Approximate height of each lyrics line
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = (_currentLineIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
      
      // Clamp the offset to valid scroll range
      final maxOffset = _scrollController.position.maxScrollExtent;
      final minOffset = _scrollController.position.minScrollExtent;
      final clampedOffset = targetOffset.clamp(minOffset, maxOffset);
      
      try {
        _scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        // Fallback to ensureVisible if animateTo fails
        final context = _lineKeys[_currentLineIndex].currentContext;
        if (context != null) {
          try {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.5, // Center the line
            );
          } catch (e) {
            // Ignore scroll errors that might occur during rapid transitions
          }
        }
      }
    }
  }

  String _getNoLyricsMessage() {
    return 'Lyrics not found for "${widget.trackName}" by ${widget.artistName}\n\n'
        'This could be because:\n'
        '• The song is instrumental\n'
        '• The lyrics are not in our database\n'
        '• There might be a difference in the song title or artist name\n\n'
        'You can try searching for lyrics manually or check if the song information is correct.';
  }

  String _getErrorMessage() {
    return 'Unable to load lyrics for "${widget.trackName}" by ${widget.artistName}\n\n'
        'Please check your internet connection and try again.\n\n'
        'If the problem persists, the lyrics service might be temporarily unavailable.';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Lyrics',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_lyricsResult?.hasSyncedLyrics == true) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                                              ),
                                              child: const Text(
                                                'SYNC',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${widget.trackName} • ${widget.artistName}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _animationController.reverse().then((_) {
                                      Navigator.of(context).pop();
                                    });
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.xmark,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Lyrics content
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CupertinoActivityIndicator(
                                          color: Colors.white,
                                          radius: 16,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Loading lyrics...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _lyricsResult == null
                                    ? SingleChildScrollView(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          _getErrorMessage(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            height: 1.6,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : _lyricsResult!.hasSyncedLyrics
                                        ? _buildSyncedLyrics()
                                        : _buildPlainLyrics(),
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
      },
    );
  }

  Widget _buildSyncedLyrics() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return StreamBuilder<Duration>(
          stream: appState.audioHandler?.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            _updateCurrentLine(position);
            
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _lyricsResult!.syncedLyrics!.length,
              itemBuilder: (context, index) {
                final line = _lyricsResult!.syncedLyrics![index];
                final isCurrentLine = index == _currentLineIndex;
                final isPastLine = index < _currentLineIndex;
                
                return Container(
                  key: _lineKeys[index],
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isCurrentLine 
                          ? Colors.white.withOpacity(0.15)
                          : Colors.transparent,
                      border: isCurrentLine
                          ? Border.all(color: Colors.white.withOpacity(0.3))
                          : null,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        color: isCurrentLine
                            ? Colors.white
                            : isPastLine
                                ? Colors.white.withOpacity(0.6)
                                : Colors.white.withOpacity(0.8),
                        fontSize: isCurrentLine ? 18 : 16,
                        fontWeight: isCurrentLine ? FontWeight.w600 : FontWeight.normal,
                        height: 1.4,
                      ),
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlainLyrics() {
    final lyrics = _lyricsResult?.plainLyrics ?? _getNoLyricsMessage();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        lyrics,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.8,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
