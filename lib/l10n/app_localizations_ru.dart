// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get home => 'Главная';

  @override
  String get songs => 'Песни';

  @override
  String get playlists => 'Плейлисты';

  @override
  String get albums => 'Альбомы';

  @override
  String get album => 'Альбом';

  @override
  String get singles => 'Синглы';

  @override
  String get artists => 'Исполнители';

  @override
  String get albumsFromYourArtists => 'From your artists';

  @override
  String get settings => 'Настройки';

  @override
  String get library => 'Библиотека';

  @override
  String get yourLibrary => 'Your Library';

  @override
  String get manage => 'Manage';

  @override
  String tracksInYourCollection(int count) {
    return '$count tracks in your collection';
  }

  @override
  String shuffleLikedSongs(int count) {
    return 'Shuffle $count liked songs';
  }

  @override
  String get availableOffline => 'Available offline';

  @override
  String get libSongs => 'Библиотека песен';

  @override
  String get libPlaylists => 'Библиотека плейлистов';

  @override
  String get libAlbums => 'Библиотека альбомов';

  @override
  String get libArtists => 'Библиотека исполнителей';

  @override
  String get communityplaylists => 'Плейлисты сообщества';

  @override
  String get featuredplaylists => 'Избранные плейлисты';

  @override
  String get items => 'объекты';

  @override
  String get networkError1 => 'Упс, ошибка сети!';

  @override
  String get retry => 'Повторите попытку!';

  @override
  String get noOfflineSong => 'Нет офлайн-песен!';

  @override
  String get recentlyPlayed => 'Недавно проигранные';

  @override
  String get favorites => 'Избранное';

  @override
  String get cachedOrOffline => 'Кэшированные/Офлайн';

  @override
  String get downloads => 'Загрузки';

  @override
  String get emptyPlaylist => 'Пустой плейлист!';

  @override
  String get enqueueAll => 'Добавить всё в очередь';

  @override
  String get renamePlaylist => 'Переименовать плейлист';

  @override
  String get removePlaylist => 'Удалить плейлист';

  @override
  String get createNewPlaylist => 'Создать новый плейлист';

  @override
  String get reArrangePlaylist => 'Упорядочить плейлист';

  @override
  String get reArrangeSongs => 'Переставить песни';

  @override
  String get selectSongs => 'Выбрать песни';

  @override
  String get selectAll => 'Выбрать всё';

  @override
  String get removeMultiple => 'Убрать несколько песен';

  @override
  String get addMultipleSongs => 'Добавить песни в плейлист';

  @override
  String get cancel => 'Отмена';

  @override
  String get create => 'Создать';

  @override
  String get rename => 'Переименовать';

  @override
  String get createnAdd => 'Создать и добавить';

  @override
  String get noBookmarks => 'Нет закладок!';

  @override
  String get addMusicToLibraryHint =>
      'Add music to your library to see it here';

  @override
  String get shuffleAll => 'Shuffle all';

  @override
  String get shuffleFavorites => 'Shuffle favorites';

  @override
  String get shuffleDownloads => 'Shuffle downloads';

  @override
  String get homeContinueListening => 'Continue listening';

  @override
  String get homeContinueListeningSubtitle => 'Pick up where you left off';

  @override
  String get homeBecauseYouLikeArtists => 'Because you like these artists';

  @override
  String get homeBecauseYouLikeArtistsSubtitle =>
      'More tracks from artists you already favorite';

  @override
  String get homePlaylistsSubtitle => 'Playlists from your collection';

  @override
  String get recentlyAddedAlbums => 'Recently added albums';

  @override
  String get yourNewestAdditions => 'Your newest additions';

  @override
  String get yourArtists => 'Your artists';

  @override
  String get homeArtistsSubtitle => 'A rotating mix from your artists';

  @override
  String get homeFreshPicks => 'Fresh picks';

  @override
  String get homeEmptyLibraryMessage =>
      'Your library is empty. Add some music to get started.';

  @override
  String get servers => 'Servers';

  @override
  String get addServer => 'Add server';

  @override
  String get noServersConfigured => 'No servers configured yet';

  @override
  String get activeServer => 'Active server';

  @override
  String get youtubeMusic => 'YouTube Music';

  @override
  String get subsonic => 'Subsonic';

  @override
  String get jellyfin => 'Jellyfin';

  @override
  String get plex => 'Plex';

  @override
  String get plexToken => 'Plex token';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get editServer => 'Edit server';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get defaultLabel => 'Default';

  @override
  String get youtubeMusicNoLogin =>
      'YouTube Music does not require login details.';

  @override
  String get serverUrlRequired => 'Server URL is required';

  @override
  String get testConnection => 'Test connection';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get playAll => 'Play All';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get artistLabel => 'ARTIST';

  @override
  String get fromWikipedia => 'From Wikipedia';

  @override
  String get songsCount => 'songs';

  @override
  String get addToLibrary => 'Add to library';

  @override
  String get noSongsInLibrary => 'No songs in library';

  @override
  String get favoritesEmpty => 'Favorites is empty';

  @override
  String get startRadio => 'Запустить радио';

  @override
  String get playNext => 'Включить следующим';

  @override
  String get addToPlaylist => 'Добавить в плейлист';

  @override
  String get noLibPlaylist => 'У вас нет плейлистов в библиотеке!';

  @override
  String get enqueueSong => 'Добавить эту песню в очередь';

  @override
  String get goToAlbum => 'Перейти в альбом';

  @override
  String get viewArtist => 'Показать исполнителя';

  @override
  String get openIn => 'Открыть в';

  @override
  String get shareSong => 'Поделиться этой песней';

  @override
  String get removeFromPlaylist => 'Удалить из плейлиста';

  @override
  String get removeFromQueue => 'Удалить из очереди';

  @override
  String get queueShufflingDeniedMsg =>
      'Очередь нельзя перемешать, когда включен режим перемешивания';

  @override
  String get queuerearrangingDeniedMsg =>
      'Очередь воспроизведения нельзя переупорядочить при включённом режиме перемешивания';

  @override
  String get songNotPlayable =>
      'Воспроизведение песни невозможно из-за ограничений сервера!';

  @override
  String get upNext => 'Следующий';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get fromAlbum => 'From: ';

  @override
  String get byArtist => 'By: ';

  @override
  String get playingFrom => 'Playing from ';

  @override
  String get playingfromAlbum => 'Воспроизвести из альбома';

  @override
  String get playingfromPlaylist => 'Воспроизвести плейлист';

  @override
  String get playingfromSelection => 'Воспроизвести выбранное';

  @override
  String get playingfromArtist => 'Воспроизвести исполнителя';

  @override
  String get randomSelection => 'Случайный выбор';

  @override
  String get randomRadio => 'Случайное радио';

  @override
  String get playnextMsg => 'Предстоящие';

  @override
  String get shuffleQueue => 'Перемешать очередь';

  @override
  String get queueLoop => 'Цикл очереди';

  @override
  String get queueLoopNotDisMsg1 =>
      'Режим цикла очереди нельзя отключить, если включен режим перемешивания.';

  @override
  String get queueLoopNotDisMsg2 =>
      'Режим цикла очереди нельзя включить в режиме радио.';

  @override
  String get removeFromLib => 'Удалить из библиотеки';

  @override
  String get sleepTimer => 'Таймер сна';

  @override
  String get add5Minutes => 'Добавить 5 минут';

  @override
  String get cancelTimer => 'Отменить таймер';

  @override
  String get deleteDownloadData => 'Удалить из загруженных';

  @override
  String get minutes => 'минуты';

  @override
  String get endOfThisSong => 'Конец песни';

  @override
  String get appInfo => 'Справка';

  @override
  String get download => 'Скачать';

  @override
  String get misc => 'Разное';

  @override
  String get autoDownFavSong => 'Автоматическая загрузка любимых песен';

  @override
  String get autoDownFavSongDes =>
      'Автоматически загружать избранные песни при добавлении в избранное';

  @override
  String get networkError => 'Ошибка сети! Проверьте подключение к сети.';

  @override
  String get downloadError2 =>
      'Запрошенная песня не может быть скачана из-за ограничений сервера. Попробуйте снова';

  @override
  String get downloadError3 =>
      'Загрузка не удалась из-за ошибки сети/потока! Попробуйте ещё раз';

  @override
  String get musicPlayback => 'Музыка и Воспроизведение';

  @override
  String get content => 'Содержание';

  @override
  String get personalisation => 'Персонализация';

  @override
  String get themeMode => 'Режим темы';

  @override
  String get dynamicTheme => 'Dynamic';

  @override
  String get dynamicColor => 'Dynamic Colour';

  @override
  String get systemDefault => 'По умолчанию системы';

  @override
  String get dark => 'Тёмный';

  @override
  String get light => 'Светлый';

  @override
  String get oled => 'OLED';

  @override
  String get language => 'Язык';

  @override
  String get playerUi => 'Интерфейс плеера';

  @override
  String get playerUiDes => 'Выберите интерфейс плеера';

  @override
  String get standard => 'Стандарт';

  @override
  String get gesture => 'Жест';

  @override
  String get languageDes => 'Язык приложения';

  @override
  String get setDiscoverContent => 'Настроить контент на вкладке открытий';

  @override
  String get quickpicks => 'Быстрый выбор';

  @override
  String get discover => 'Обнаружить';

  @override
  String get trending => 'В тренде';

  @override
  String get topmusicvideos => 'Лучшие музыкальные клипы';

  @override
  String get basedOnLast => 'На основе последнего взаимодействия';

  @override
  String get restoreLastPlaybackSession =>
      'Восстановливать последнюю сессию прослушивания';

  @override
  String get restoreLastPlaybackSessionDes =>
      'Автоматически восстанавливает последнюю сессию прослушивания при запуске приложения';

  @override
  String get autoOpenPlayer => 'Автоматически открывать экран проигрывателя';

  @override
  String get autoOpenPlayerDes =>
      'Включить/выключить автоматическое открытие плеера на весь экран при выборе песни для воспроизведения';

  @override
  String get homeContentCount => 'Количество контента на главной странице';

  @override
  String get homeContentCountDes =>
      'Выберите примерное число изначального контента на главном экране. Меньше число - быстрее загрузка';

  @override
  String get enableBottomNav => 'Панель навигации снизу';

  @override
  String get enableBottomNavDes =>
      'Переключится на расположение навигационной панели снизу';

  @override
  String get sidebarMode => 'Sidebar behavior';

  @override
  String get sidebarModeDes =>
      'Control whether the sidebar is automatic, always collapsed, or always full width.';

  @override
  String get sidebarModeAuto => 'Auto';

  @override
  String get sidebarModeCollapsed => 'Collapsed';

  @override
  String get sidebarModeExpanded => 'Full view';

  @override
  String get dynamicColorDes =>
      'Dynamic theme using a fixed colour (not now playing).';

  @override
  String get useCustomAccentColor => 'Use custom accent colour';

  @override
  String get useCustomAccentColorDes =>
      'Apply your selected accent colour across all theme modes.';

  @override
  String get customAccentColor => 'Custom accent colour';

  @override
  String get customAccentColorDes =>
      'Pick the accent colour used across the app.';

  @override
  String get lyricsDynamicColor => 'Lyrics change accent colour';

  @override
  String get lyricsDynamicColorDes =>
      'When a song has synced lyrics, colour words in the lyrics can change the app accent (Dynamic theme only).';

  @override
  String get syncedLyricsHighlightStyle => 'Synced lyrics highlight style';

  @override
  String get syncedLyricsHighlightStyleDes =>
      'Choose how the active synced lyric line is highlighted.';

  @override
  String get lyricsHighlightBlock => 'Block highlight';

  @override
  String get lyricsHighlightKaraoke => 'Karaoke fill';

  @override
  String get pickDynamicColor => 'Pick dynamic colour';

  @override
  String get advanced => 'Advanced…';

  @override
  String get change => 'Change';

  @override
  String get cacheSongs => 'Кэш песен';

  @override
  String get cacheSongsDes =>
      'Кэширование песен во время игры на будущее / оффлайн воспроизведение, это займет дополнительное пространство на вашем устройстве';

  @override
  String get skipSilence => 'Пропускать тишину';

  @override
  String get skipSilenceDes =>
      'Тишина будет пропущена при воспроизведении музыки';

  @override
  String get loudnessNormalization => 'Нормализация громкости';

  @override
  String get loudnessNormalizationDes =>
      'Устанавливает одинаковый уровень громкости на всех песнях (Экспериментально) (Не будет работать с песнями, скачанными на версии 1.10.0 и ниже)';

  @override
  String get streamingQuality => 'Потоковое качество';

  @override
  String get streamingQualityDes => 'Качество музыкального потока';

  @override
  String get disableTransitionAnimation => 'Отключить анимацию перехода';

  @override
  String get disableTransitionAnimationDes =>
      'Включите эту опцию, чтобы отключить анимацию перехода между вкладками';

  @override
  String get animationSpeed => 'Animation speed';

  @override
  String get animationSpeedDes =>
      'Control the speed of app transitions or turn them off.';

  @override
  String get animationSpeedOff => 'Off';

  @override
  String get animationSpeedFast => 'Fast (default)';

  @override
  String get animationSpeedNormal => 'Normal';

  @override
  String get animationSpeedSlow => 'Slow';

  @override
  String get enableSlidableAction => 'Включить скользящие действия';

  @override
  String get enableSlidableActionDes =>
      'Включить скользящие действия на плитке песни';

  @override
  String get high => 'Высокое';

  @override
  String get low => 'Низкое';

  @override
  String get backgroundPlay => 'Фоновое проигрывание музыки';

  @override
  String get backgroundPlayDes =>
      'Включает/отключает проигрывание музыки на заднем фоне (Когда приложение работает на заднем фоне, оно может быть вызвано из системного трея)';

  @override
  String get downloadLocation => 'Папка для загрузок';

  @override
  String get cacheHomeScreenData => 'Кэшировать контент с главной страницы';

  @override
  String get cacheHomeScreenDataDes =>
      'Включает кэширование контента с главного экрана, главный экран будет загружаться мгновенно, если эта опция включена';

  @override
  String get downloadingFormat => 'Загрузка формата файла';

  @override
  String get downloadingFormatDes =>
      'Выберите формат файла загрузки. «Opus» обеспечит лучшее качество';

  @override
  String get exportDowloadedFiles => 'Экспортировать скачанные файлы';

  @override
  String get exportDowloadedFilesDes =>
      'Нажмите сюда, чтобы экспортировать скачанные файлы из папки приложения во внешнюю папку';

  @override
  String get exportedFileLocation => 'Место экспортирования скачанных файлов';

  @override
  String get export => 'Экспортировать';

  @override
  String get exporting => 'Экспортирование...';

  @override
  String get scanning => 'Сканирование...';

  @override
  String get downFilesFound => 'скачанных файлов найдено';

  @override
  String get close => 'Закрыть';

  @override
  String get exportMsg => 'Файлы успешно экспортированы';

  @override
  String get equalizer => 'Эквалайзер';

  @override
  String get equalizerDes => 'Открыть системный эквалайзер';

  @override
  String get clearImgCache => 'Очистить кэш изображений';

  @override
  String get clearImgCacheAlert => 'Кэш изображений успешно очищен';

  @override
  String get clearImgCacheDes =>
      'Нажмите здесь чтобы очистить кэшированные миниатюры/изображения. (Не рекомендуется, если только вы не хотите обновить кэшированные изображения)';

  @override
  String get ignoreBatOpt => 'Игнорировать оптимизацию батареи';

  @override
  String get ignoreBatOptDes =>
      'Если вы столкнулись с проблемами уведомлений или воспроизведение остановлено оптимизацией системы, пожалуйста, включите эту опцию';

  @override
  String get status => 'Статус';

  @override
  String get enabled => 'Включено';

  @override
  String get disabled => 'Отключено';

  @override
  String get resetToDefault => 'Восстановить настройки по умолчанию';

  @override
  String get resetToDefaultDes =>
      'Сбросить настройки приложения по умолчанию (требуется перезапуск)';

  @override
  String get resetToDefaultMsg =>
      'Сброс настроек до значений по умолчанию завершен. Пожалуйста, перезапустите приложение';

  @override
  String get github => 'GitHub';

  @override
  String get githubDes =>
      'Посмотреть исходный код на GitHub\\nесли вам нравится этот проект, не забудьте поставить ⭐';

  @override
  String get gitlab => 'GitLab';

  @override
  String get gitlabDes =>
      'View GitLab source code\\nif you like this project, don\'t forget to give a ⭐';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkForUpdatesOnStartup => 'Check for updates on startup';

  @override
  String get openOpenlystWebsite => 'Open Openlyst website';

  @override
  String get openGitlab => 'Open GitLab';

  @override
  String get upToDate => 'You are up to date';

  @override
  String get checkingForUpdates => 'Checking for updates…';

  @override
  String get by => 'от';

  @override
  String get urlSearchDes => 'Клик по Url открывает\\проигрывает контент';

  @override
  String get search => 'Поиск';

  @override
  String get searchDes => 'Песни, плейлист, альбом или исполнитель';

  @override
  String get searchRes => 'Результаты поиска';

  @override
  String get for1 => 'для';

  @override
  String get videos => 'Видео';

  @override
  String get viewAll => 'Показать все';

  @override
  String get results => 'Результаты';

  @override
  String get nomatch => 'Совпадений не найдено';

  @override
  String get subscribers => 'подписчики';

  @override
  String get about => 'О';

  @override
  String get synced => 'Синхронизировано';

  @override
  String get plain => 'Обычно';

  @override
  String get songInfo => 'Информация';

  @override
  String get id => 'Id';

  @override
  String get title => 'Название';

  @override
  String get duration => 'Длина';

  @override
  String get audioCodec => 'Кодек';

  @override
  String get bitrate => 'Битрейт';

  @override
  String get loudnessDb => 'Громкость (Db)';

  @override
  String get deleteDownloadedDataAlert => 'Успешно удалено из загруженных!';

  @override
  String get cancelTimerAlert => 'Таймер сна отключен';

  @override
  String get sleepTimeSetAlert => 'Ваш таймер сна установлен';

  @override
  String get radioNotAvailable => 'Радио недоступно для этого исполнителя!';

  @override
  String get songRemovedfromQueue => 'Удалено из очереди!';

  @override
  String get songRemovedfromQueueCurrSong =>
      'Вы не можете удалить проигрываемую песню';

  @override
  String get songAddedToPlaylistAlert => 'Песня добавлена в плейлист!';

  @override
  String get songAlreadyExists => 'Песня уже существует!';

  @override
  String get songAlreadyOfflineAlert => 'Песня уже офлайн в кэше';

  @override
  String get songEnqueueAlert => 'Песня добавлена в очередь!';

  @override
  String get songRemovedAlert => 'Удалено из';

  @override
  String get errorOccuredAlert => 'Произошла ошибка!';

  @override
  String get pipedplstSyncAlert => 'Плейлист Piped синхронизирован!';

  @override
  String get playlistCreatedAlert => 'Плейлист создан!';

  @override
  String get playlistCreatednsongAddedAlert =>
      'Плейлист создан и песня добавлена!';

  @override
  String get playlistRenameAlert => 'Переименовано успешно!';

  @override
  String get playlistRemovedAlert => 'Плейлист удален!';

  @override
  String get playlistBookmarkAddAlert => 'Плейлист добавлен в закладки!';

  @override
  String get playlistBookmarkRemoveAlert => 'Плейлист удален из закладок!';

  @override
  String get albumBookmarkAddAlert => 'Альбом в закладках!';

  @override
  String get albumBookmarkRemoveAlert => 'Альбом удален из закладок!';

  @override
  String get artistBookmarkAddAlert => 'Исполнитель в закладках!';

  @override
  String get artistBookmarkRemoveAlert => 'Исполнитель удален из закладок!';

  @override
  String get lyricsNotAvailable => 'Слова песни не доступны!';

  @override
  String get syncedLyricsNotAvailable =>
      'Синхронизированные слова песни недоступны!';

  @override
  String get artistDesNotAvailable => 'Описание недоступно!';

  @override
  String get newVersionAvailable => 'Доступна новая версия!';

  @override
  String get version => 'Version';

  @override
  String get dontShowInfoAgain => 'Не показывать эту информацию снова';

  @override
  String get dismiss => 'Скрыть';

  @override
  String get notaSongVideo => 'Не является видео!';

  @override
  String get notaValidLink => 'Некорректная ссылка!';

  @override
  String get operationFailed => 'Операция не удалась';

  @override
  String get goToDownloadPage =>
      'Нажмите здесь, чтобы перейти на страницу загрузки';

  @override
  String get local => 'На устройстве';

  @override
  String get piped => 'Piped';

  @override
  String get link => 'Привязать';

  @override
  String get unLink => 'Отвязать';

  @override
  String get hintApiUrl => 'URL-адрес API сервера Piped';

  @override
  String get customIns => 'Пользовательский сервер';

  @override
  String get customInsSelectMsg =>
      'Пожалуйста, выберите пользовательский сервер';

  @override
  String get selectAuthInsMsg => 'Пожалуйста, выберите сервер аутентификации!';

  @override
  String get allFieldsReqMsg => 'Все поля обязательны';

  @override
  String get linkPipedDes => 'Связать с Piped для плейлистов';

  @override
  String get selectAuthIns => 'Выберите сервер аутентификации';

  @override
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get linkAlert => 'Успешно привязано!';

  @override
  String get unlinkAlert => 'Успешно отвязано!';

  @override
  String get playlistBlacklistAlert => 'Плейлист занесен в черный список!';

  @override
  String get reset => 'Сбросить';

  @override
  String get blacklistPlstResetAlert => 'Сброс выполнен успешно!';

  @override
  String get resetblacklistedplaylist => 'Сбросить плейлисты из черного списка';

  @override
  String get resetblacklistedplaylistDes =>
      'Сбросить все плейлисты Piped из черного списка';

  @override
  String get stopMusicOnTaskClear => 'Остановить музыку после выполнения задач';

  @override
  String get stopMusicOnTaskClearDes =>
      'Воспроизведение музыки остановится, когда приложение будет удалено из диспетчера задач';

  @override
  String get backupAppData => 'Сделать бэкап приложения';

  @override
  String get androidBackupWarning =>
      'Не проверено: при установке флажка после загрузки более 60 файлов процесс может занять большой объем памяти и привести к крашу телефона или приложения. Действуйте на свой страх и риск.';

  @override
  String get backupSettingsAndPlaylistsDes =>
      'Сохраняет все настройки, плейлисты и логин в файл бэкапа';

  @override
  String get backup => 'Бэкап';

  @override
  String get letsStrart => 'Давайте начнём...';

  @override
  String get processFiles => 'Обработка файлов...';

  @override
  String get includeDownloadedFiles => 'Включать загруженные песни';

  @override
  String get backupInProgress => 'Бэкап в процессе...';

  @override
  String get restoreAppData => 'Восстановить данные приложения';

  @override
  String get restoreSettingsAndPlaylistsDes =>
      'Восстановляет все настройки, логин, плейлисты из бэкапа. Стирает все текущие данные';

  @override
  String get backupMsg => 'Бэкап успешно сохранён!';

  @override
  String get backFilesFound => 'база данных найдена';

  @override
  String get restoreMsg =>
      'Восстановлено успешно!\\nИзменения войду в силу после перезапуска';

  @override
  String get restoring => 'Восстановляем...';

  @override
  String get restore => 'Восстановить';

  @override
  String get closeApp => 'Закрыть приложение';

  @override
  String get restartApp => 'Перезапустить';

  @override
  String get exportPlaylist => 'Экспортировать плейлист';

  @override
  String get exportPlaylistCsv => 'Экспортировать плейлист как CSV';

  @override
  String get exportingPlaylist => 'Экспортируем плейлист...';

  @override
  String get playlistExportedMsg => 'Плейлист успешно экспортирован в';

  @override
  String get exportError => 'Ошибка при экспорте плейлиста';

  @override
  String get exportErrorPermission => 'Разрешение отказано при экспорте';

  @override
  String get exportErrorStorage => 'Недостаточно места для хранения';

  @override
  String get exportErrorFormat => 'Ошибка форматирования данных плейлиста';

  @override
  String get importPlaylist => 'Импортировать плейлист';

  @override
  String get importingPlaylist => 'Импорт списка воспроизведения...';

  @override
  String get importPlaylistDesc =>
      'Выберите ранее экспортированный файл JSON с плейлистом для импорта';

  @override
  String get selectFile => 'Выбрать файл';

  @override
  String get playlistImportedMsg => 'Плейлист импортирован успешно';

  @override
  String get importError => 'Ошибка при импорте списка воспроизведения';

  @override
  String get importErrorFileAccess =>
      'Не удалось получить доступ к выбранному файлу';

  @override
  String get importErrorFormat => 'Недопустимый формат файла';

  @override
  String get invalidPlaylistFile => 'Недопустимая структура файла плейлиста';

  @override
  String get importErrorDatabase => 'Ошибка при сохранении в базе данных';

  @override
  String get fileNotFound => 'Файл не найден';

  @override
  String get importLargeFileNote =>
      'Примечание: импорт больших плейлистов может занять больше времени';

  @override
  String get exportPlaylistJson => 'Экспортировать плейлист в JSON';

  @override
  String get exportPlaylistJsonSubtitle => 'Этот формат можно импортировать';

  @override
  String get exportPlaylistCsvSubtitle => 'Импорт здесь недоступен';

  @override
  String get exportToYouTubeMusic => 'Экспортировать в YouTube Music';

  @override
  String get exportToYouTubeMusicSubtitle =>
      'Ваш плейлист (до 50 песен) будет добавлен в текущую очередь. Не забудьте добавить его в плейлист или сохранить после открытия в YtMusic';

  @override
  String get linkCopied => 'Ссылка скопирована в буфер обмена';

  @override
  String get keepScreenOnWhilePlaying =>
      'Держать экран включенным во время воспроизведения';

  @override
  String get keepScreenOnWhilePlayingDes =>
      'Если включено, экран устройства будет оставаться включенным во время воспроизведения музыки';

  @override
  String get importedPlaylist => 'Imported playlist';

  @override
  String get listBookmarkRemoveAlert => 'Bookmark removed!';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get loading => 'Loading';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get unknownAlbum => 'Unknown Album';

  @override
  String get yourMusicCollection => 'Your music collection';

  @override
  String get more => 'More';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get sortByDuration => 'Sort by duration';

  @override
  String get sortAscendNDescend => 'Ascending & Descending';

  @override
  String get imported => 'Imported';
}
