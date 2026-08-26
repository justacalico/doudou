part of 'settings_screen.dart';

mixin __SettingsViewStateBase on State<_SettingsView> {

  _SettingsSectionId _selected = _SettingsSectionId.personalisation;

  static const _sectionMeta = <(_SettingsSectionId, IconData, String)>[
    (
      _SettingsSectionId.personalisation,
      Icons.palette_outlined,
      'personalisation'
    ),
    (_SettingsSectionId.content, Icons.movie_outlined, 'content'),
    (_SettingsSectionId.playback, Icons.music_note_outlined, 'musicPlayback'),
    (_SettingsSectionId.servers, Icons.dns_outlined, 'servers'),
    (_SettingsSectionId.download, Icons.download_outlined, 'download'),
    (_SettingsSectionId.backup, Icons.restore_outlined, 'backup'),
    (_SettingsSectionId.misc, Icons.miscellaneous_services_outlined, 'misc'),
    (_SettingsSectionId.info, Icons.info_outline, 'appInfo'),
  ];

  static const _mobileClusters = <(_SettingsSectionId, String, String)>[
    (_SettingsSectionId.servers, 'ACCOUNTS', 'accounts'),
    (_SettingsSectionId.backup, 'ACCOUNTS', 'accounts'),
    (_SettingsSectionId.content, 'USER', 'user'),
    (_SettingsSectionId.playback, 'USER', 'user'),
    (_SettingsSectionId.misc, 'USER', 'user'),
    (_SettingsSectionId.personalisation, 'APPEARANCE', 'appearance'),
    (_SettingsSectionId.download, 'APPEARANCE', 'appearance'),
    (_SettingsSectionId.info, 'APPEARANCE', 'appearance'),
  ];

  late final _groupedClusters = _buildGroupedClusters();
  static List<(String, String, List<_SettingsSectionId>)> _buildGroupedClusters() {
    final map = <String, (String, List<_SettingsSectionId>)>{};
    for (final c in _mobileClusters) {
      final existing = map[c.$2];
      if (existing == null) {
        map[c.$2] = (c.$3, [c.$1]);
      } else {
        existing.$2.add(c.$1);
      }
    }
    return map.entries
        .map((e) => (e.key, e.value.$1, e.value.$2))
        .toList();
  }

Widget build(BuildContext context);
  String _clusterLabel(BuildContext context, String key);
  Widget _buildHeader(BuildContext context, bool useTwoPane);
  Widget _buildTwoPane( BuildContext context, SettingsScreenController settings, LibrarySyncService sync, );
  Widget _buildSinglePane( BuildContext context, SettingsScreenController settings, LibrarySyncService sync, double bottomPadding, );
  Widget _buildSectionNav(BuildContext context);
  Widget _buildNavTile(BuildContext context, _SettingsSectionId id);
  Widget _buildMobileSectionRow( BuildContext context, SettingsScreenController settings, LibrarySyncService sync, _SettingsSectionId id, );
  void _openSectionSubPage( BuildContext context, SettingsScreenController settings, LibrarySyncService sync, _SettingsSectionId id, );
  IconData _sectionIcon(_SettingsSectionId id);
  String _sectionTitle(BuildContext context, _SettingsSectionId id);
  String _sectionSubtitle(BuildContext context, _SettingsSectionId id);
  bool _isTv(BuildContext context);
  List<Widget> _buildSectionChildren( BuildContext context, SettingsScreenController settings, LibrarySyncService sync, _SettingsSectionId id, );
  List<Widget> _buildPersonalisation( BuildContext context, SettingsScreenController settings, );
  String _themeModeLabel(BuildContext context, ThemeType type);
  List<Widget> _buildContent( BuildContext context, SettingsScreenController settings, );
  String _discoverContentLabel(BuildContext context, String value);
  List<Widget> _buildPlayback( BuildContext context, SettingsScreenController settings, );
  Widget _batteryStatusText( BuildContext context, SettingsScreenController settings, );
  List<Widget> _buildServers( BuildContext context, SettingsScreenController settings, LibrarySyncService sync, );
  Future<void> _showAddProviderPicker(BuildContext context);
  List<Widget> _buildDownload( BuildContext context, SettingsScreenController settings, );
  List<Widget> _buildBackup(BuildContext context);
  List<Widget> _buildMisc( BuildContext context, SettingsScreenController settings, );
  void _showDiscordAppIdDialog( BuildContext context, SettingsScreenController settings, );
  void _testDiscordRpc( BuildContext context, SettingsScreenController settings, );
  List<Widget> _buildInfo( BuildContext context, SettingsScreenController settings, );

}

