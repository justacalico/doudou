#import "TouchBarPlugin.h"

@interface TouchBarPlugin () <NSTouchBarDelegate>
@property (nonatomic, strong) NSTouchBar *touchBar;
@property (nonatomic, strong) NSButton *playPauseButton;
@property (nonatomic, strong) NSSlider *timelineSlider;
@property (nonatomic, strong) NSTextField *nowPlayingLabel;
@property (nonatomic, strong) NSButton *favoriteButton;
@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) double currentPosition;
@property (nonatomic, assign) double totalDuration;
@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, strong) NSString *currentTitle;
@property (nonatomic, strong) NSString *currentArtist;
@property (nonatomic, assign) BOOL isDragging;
@end

@implementation TouchBarPlugin

// Touch Bar identifiers
static NSTouchBarItemIdentifier const PlayPauseItemIdentifier = @"com.openlyst.doudou.playPause";
static NSTouchBarItemIdentifier const PreviousItemIdentifier = @"com.openlyst.doudou.previous";
static NSTouchBarItemIdentifier const NextItemIdentifier = @"com.openlyst.doudou.next";
static NSTouchBarItemIdentifier const TimelineItemIdentifier = @"com.openlyst.doudou.timeline";
static NSTouchBarItemIdentifier const NowPlayingItemIdentifier = @"com.openlyst.doudou.nowPlaying";
static NSTouchBarItemIdentifier const FavoriteItemIdentifier = @"com.openlyst.doudou.favorite";

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"com.openlyst.doudou/touchbar"
              binaryMessenger:[registrar messenger]];
    
    TouchBarPlugin* instance = [[TouchBarPlugin alloc] init];
    instance.channel = channel;
    
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isPlaying = NO;
        self.currentPosition = 0.0;
        self.totalDuration = 0.0;
        self.isFavorite = NO;
        self.currentTitle = @"";
        self.currentArtist = @"";
        self.isDragging = NO;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"initialize" isEqualToString:call.method]) {
        [self initializeTouchBar];
        result(nil);
    } else if ([@"updateNowPlaying" isEqualToString:call.method]) {
        [self updateNowPlayingWithArguments:call.arguments];
        result(nil);
    } else if ([@"clearNowPlaying" isEqualToString:call.method]) {
        [self clearNowPlaying];
        result(nil);
    } else if ([@"updatePlaybackState" isEqualToString:call.method]) {
        [self updatePlaybackStateWithArguments:call.arguments];
        result(nil);
    } else if ([@"setControlsEnabled" isEqualToString:call.method]) {
        BOOL enabled = [call.arguments[@"enabled"] boolValue];
        [self setControlsEnabled:enabled];
        result(nil);
    } else if ([@"dispose" isEqualToString:call.method]) {
        [self disposeTouchBar];
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)initializeTouchBar {
    if (@available(macOS 10.12.2, *)) {
        self.touchBar = [[NSTouchBar alloc] init];
        self.touchBar.delegate = self;
        self.touchBar.defaultItemIdentifiers = @[
            PreviousItemIdentifier,
            PlayPauseItemIdentifier,
            NextItemIdentifier,
            TimelineItemIdentifier,
            NowPlayingItemIdentifier,
            FavoriteItemIdentifier
        ];
        
        // Set the Touch Bar for the main window
        dispatch_async(dispatch_get_main_queue(), ^{
            NSWindow *mainWindow = [NSApplication sharedApplication].mainWindow;
            if (mainWindow) {
                mainWindow.touchBar = self.touchBar;
            }
        });
        
        NSLog(@"Touch Bar initialized successfully");
    } else {
        NSLog(@"Touch Bar not available on this macOS version");
    }
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    if ([identifier isEqualToString:PlayPauseItemIdentifier]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        self.playPauseButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameTouchBarPlayTemplate]
                                                  target:self
                                                  action:@selector(playPausePressed:)];
        item.view = self.playPauseButton;
        return item;
        
    } else if ([identifier isEqualToString:PreviousItemIdentifier]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSButton *button = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameTouchBarRewindTemplate]
                                             target:self
                                             action:@selector(previousPressed:)];
        item.view = button;
        return item;
        
    } else if ([identifier isEqualToString:NextItemIdentifier]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSButton *button = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameTouchBarFastForwardTemplate]
                                             target:self
                                             action:@selector(nextPressed:)];
        item.view = button;
        return item;
        
    } else if ([identifier isEqualToString:TimelineItemIdentifier]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        self.timelineSlider = [[NSSlider alloc] init];
        self.timelineSlider.minValue = 0.0;
        self.timelineSlider.maxValue = 1.0;
        self.timelineSlider.doubleValue = 0.0;
        self.timelineSlider.target = self;
        self.timelineSlider.action = @selector(timelineChanged:);
        
        // Add continuous tracking for smooth updates
        [self.timelineSlider setContinuous:YES];
        
        item.view = self.timelineSlider;
        return item;
        
    } else if ([identifier isEqualToString:NowPlayingItemIdentifier]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        self.nowPlayingLabel = [[NSTextField alloc] init];
        self.nowPlayingLabel.stringValue = @"No track playing";
        self.nowPlayingLabel.editable = NO;
        self.nowPlayingLabel.bezeled = NO;
        self.nowPlayingLabel.backgroundColor = [NSColor clearColor];
        self.nowPlayingLabel.textColor = [NSColor labelColor];
        self.nowPlayingLabel.font = [NSFont systemFontOfSize:12];
        item.view = self.nowPlayingLabel;
        return item;
        
    } else if ([identifier isEqualToString:FavoriteItemIdentifier]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        self.favoriteButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameTouchBarAddTemplate]
                                                 target:self
                                                 action:@selector(favoritePressed:)];
        item.view = self.favoriteButton;
        return item;
    }
    
    return nil;
}

- (void)playPausePressed:(NSButton *)sender {
    [self.channel invokeMethod:@"playPause" arguments:nil];
}

- (void)previousPressed:(NSButton *)sender {
    [self.channel invokeMethod:@"previousTrack" arguments:nil];
}

- (void)nextPressed:(NSButton *)sender {
    [self.channel invokeMethod:@"nextTrack" arguments:nil];
}

- (void)timelineChanged:(NSSlider *)sender {
    if (self.totalDuration > 0) {
        double position = sender.doubleValue;
        [self.channel invokeMethod:@"seekTo" arguments:@{@"position": @(position)}];
    }
}

- (void)favoritePressed:(NSButton *)sender {
    [self.channel invokeMethod:@"toggleFavorite" arguments:nil];
}

- (void)updateNowPlayingWithArguments:(NSDictionary *)arguments {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *title = arguments[@"title"] ?: @"Unknown Track";
        NSString *artist = arguments[@"artist"] ?: @"Unknown Artist";
        NSNumber *duration = arguments[@"duration"] ?: @0;
        
        self.currentTitle = title;
        self.currentArtist = artist;
        self.totalDuration = [duration doubleValue];
        
        NSString *displayText = [NSString stringWithFormat:@"%@ - %@", title, artist];
        if (self.nowPlayingLabel) {
            self.nowPlayingLabel.stringValue = displayText;
        }
        
        if (self.timelineSlider) {
            self.timelineSlider.maxValue = self.totalDuration;
        }
    });
}

- (void)clearNowPlaying {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.nowPlayingLabel) {
            self.nowPlayingLabel.stringValue = @"No track playing";
        }
        if (self.timelineSlider) {
            self.timelineSlider.doubleValue = 0.0;
            self.timelineSlider.maxValue = 1.0;
        }
    });
}

- (void)updatePlaybackStateWithArguments:(NSDictionary *)arguments {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL isPlaying = [arguments[@"isPlaying"] boolValue];
        NSNumber *position = arguments[@"position"] ?: @0;
        NSNumber *duration = arguments[@"duration"] ?: @0;
        BOOL isFavorite = [arguments[@"isFavorite"] boolValue];
        
        self.isPlaying = isPlaying;
        self.currentPosition = [position doubleValue];
        self.totalDuration = [duration doubleValue];
        self.isFavorite = isFavorite;
        
        // Update play/pause button
        if (self.playPauseButton) {
            NSImage *buttonImage = isPlaying ? 
                [NSImage imageNamed:NSImageNameTouchBarPauseTemplate] :
                [NSImage imageNamed:NSImageNameTouchBarPlayTemplate];
            self.playPauseButton.image = buttonImage;
        }
        
        // Update timeline slider (only if not being dragged by user)
        if (self.timelineSlider && !self.isDragging) {
            if (self.totalDuration > 0) {
                self.timelineSlider.maxValue = self.totalDuration;
                self.timelineSlider.doubleValue = self.currentPosition;
            }
        }
        
        // Update favorite button
        if (self.favoriteButton) {
            NSImage *favoriteImage = isFavorite ?
                [NSImage imageNamed:NSImageNameTouchBarRemoveTemplate] :
                [NSImage imageNamed:NSImageNameTouchBarAddTemplate];
            self.favoriteButton.image = favoriteImage;
        }
    });
}

- (void)setControlsEnabled:(BOOL)enabled {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.playPauseButton) self.playPauseButton.enabled = enabled;
        if (self.timelineSlider) self.timelineSlider.enabled = enabled;
        if (self.favoriteButton) self.favoriteButton.enabled = enabled;
    });
}

- (void)disposeTouchBar {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *mainWindow = [NSApplication sharedApplication].mainWindow;
        if (mainWindow) {
            mainWindow.touchBar = nil;
        }
        
        self.touchBar = nil;
        self.playPauseButton = nil;
        self.timelineSlider = nil;
        self.nowPlayingLabel = nil;
        self.favoriteButton = nil;
    });
}

@end