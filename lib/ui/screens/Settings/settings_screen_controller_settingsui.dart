part of 'settings_screen_controller.dart';

mixin _SettingsUiMixin on _SettingsScreenControllerBase {
  void setAppLanguage(String? val) {
    if (val == null) return;
    final locale = val == 'en_AU' ? const Locale('en', 'AU') : Locale(val);
    final langCode = val;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.updateLocale(locale);
      Get.find<MusicServices>().hlCode = langCode;
      Get.find<HomeScreenController>().loadContentFromNetwork(silent: true);
      currentAppLanguageCode.value = langCode;
      setBox.put('currentAppLanguageCode', langCode);
      Get.find<AppSettingsController>().setLocale(langCode);
    });
  }

  void setContentNumber(int? no) {
    noOfHomeScreenContent.value = no!;
    setBox.put("noOfHomeScreenContent", no);
  }

  void setStreamingQuality(dynamic val) {
    setBox.put("streamingQuality", AudioQuality.values.indexOf(val));
    streamingQuality.value = val;
  }

  void setPlayerUi(dynamic val) {
    final playerCon = Get.find<PlayerController>();
    setBox.put("playerUi", val);
    if (val == 1 && playerCon.gesturePlayerStateAnimationController == null) {
      playerCon.initGesturePlayerStateAnimationController();
    }

    playerUi.value = val;
  }

  void enableBottomNavBar(bool val) {
    final homeScrCon = Get.find<HomeScreenController>();
    final playerCon = Get.find<PlayerController>();
    if (val) {
      homeScrCon.onSideBarTabSelected(5);
      isBottomNavBarEnabled.value = true;
    } else {
      isBottomNavBarEnabled.value = false;
      homeScrCon.onSideBarTabSelected(7);
    }
    if (!Get.find<PlayerController>().initFlagForPlayer) {
      playerCon.playerPanelMinHeight.value =
          val ? 80.0 : 80.0 + Get.mediaQuery.viewPadding.bottom;
    }
    setBox.put("isBottomNavBarEnabled", val);
  }

  void setSidebarMode(SidebarMode? mode) {
    if (mode == null) return;
    sidebarMode.value = mode;
    setBox.put("sidebarMode", mode.index);
  }

  void setNowPlayingLayout(NowPlayingLayout? layout) {
    if (layout == null) return;
    nowPlayingLayout.value = layout;
    setBox.put("nowPlayingLayout", layout.index);
  }

  void setLyricsDynamicColorEnabled(bool value) {
    lyricsDynamicColorEnabled.value = value;
    setBox.put("lyricsDynamicColorEnabled", value);
  }

  void setSyncedLyricsHighlightStyle(SyncedLyricsHighlightStyle style) {
    syncedLyricsHighlightStyle.value = style;
    setBox.put("syncedLyricsHighlightStyle", style.index);
  }

  void setAnimationSpeed(AnimationSpeed speed) {
    animationSpeed.value = speed;
    setBox.put('animationSpeed', speed.index);
    final disabled = speed == AnimationSpeed.off;
    isTransitionAnimationDisabled.value = disabled;
    setBox.put('isTransitionAnimationDisabled', disabled);
  }

  void toggleSlidableAction(bool val) {
    setBox.put("slidableActionEnabled", val);
    slidableActionEnabled.value = val;
  }

  void changeDownloadingFormat(String? val) {
    setBox.put("downloadingFormat", val);
    downloadingFormat.value = val!;
  }

  void disableTransitionAnimation(bool val) {
    setBox.put('isTransitionAnimationDisabled', val);
    isTransitionAnimationDisabled.value = val;
    if (val) {
      animationSpeed.value = AnimationSpeed.off;
      setBox.put('animationSpeed', AnimationSpeed.off.index);
    } else {
      if (animationSpeed.value == AnimationSpeed.off) {
        animationSpeed.value = AnimationSpeed.fast;
        setBox.put('animationSpeed', AnimationSpeed.fast.index);
      }
    }
  }

  void onThemeChange(dynamic val) {
    final type = val as ThemeType;
    Get.find<AppSettingsController>().setThemeModeType(themeTypeToStorage(type));
    themeModetype.value = type;
    Get.find<ThemeController>().changeThemeModeType(type);
  }

  void onContentChange(dynamic value) {
    setBox.put('discoverContentType', value);
    discoverContentType.value = value;
    Get.find<HomeScreenController>().changeDiscoverContent(value);
  }

}
