import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/playbook.dart';
import '../../services/playbook_service.dart';
import '../../services/base_service.dart';
import '../../providers/app_state.dart';
import '../../widgets/apple_design/apple_theme.dart';

/// Screen for managing Playbooks (music service configurations)
class PlaybooksScreen extends StatefulWidget {
  const PlaybooksScreen({super.key});

  @override
  State<PlaybooksScreen> createState() => _PlaybooksScreenState();
}

class _PlaybooksScreenState extends State<PlaybooksScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: CupertinoPageScaffold(
        backgroundColor: isDark 
            ? const Color(0xFF0A0A0A)
            : CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          border: null,
          middle: Text(
            'Playbooks',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.add),
            onPressed: () => _showAddPlaybookSheet(context),
          ),
        ),
        child: Consumer<PlaybookService>(
          builder: (context, playbookService, child) {
            final playbooks = playbookService.playbooks;

            if (playbooks.isEmpty) {
              return _buildEmptyState(context, isDark);
            }

            return SafeArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: playbooks.length,
                itemBuilder: (context, index) {
                  final playbook = playbooks[index];
                  return _buildPlaybookCard(context, playbook, playbookService, isDark);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              CupertinoIcons.music_note_list,
              size: 40,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Playbooks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a music service to get started',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white54 : Colors.black54,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: () => _showAddPlaybookSheet(context),
            child: const Text('Add Playbook'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybookCard(
    BuildContext context,
    Playbook playbook,
    PlaybookService playbookService,
    bool isDark,
  ) {
    final isActive = playbookService.activePlaybookId == playbook.id;
    final color = _getColorForType(playbook.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isActive ? color : Colors.white).withOpacity(isDark ? 0.15 : 0.1),
                  (isActive ? color : Colors.white).withOpacity(isDark ? 0.05 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive 
                    ? color.withOpacity(0.5)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: playbook.isEnabled 
                    ? () => playbookService.setActivePlaybook(playbook.id)
                    : null,
                onLongPress: () => _showPlaybookOptions(context, playbook, playbookService),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Service Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(isDark ? 0.2 : 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildServiceIcon(playbook.type, color),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    playbook.name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getPlaybookSubtitle(playbook),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Enable/Disable Switch
                      CupertinoSwitch(
                        value: playbook.isEnabled,
                        activeColor: color,
                        onChanged: (enabled) {
                          playbookService.togglePlaybook(playbook.id, enabled);
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

  Widget _buildServiceIcon(ServerType type, Color color) {
    switch (type) {
      case ServerType.jellyfin:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: SvgPicture.asset(
            'assets/icons/jellyfin.svg',
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        );
      case ServerType.plex:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: SvgPicture.asset(
            'assets/icons/plex.svg',
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        );
      case ServerType.navidrome:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: SvgPicture.asset(
            'assets/icons/navidrome.svg',
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        );
      case ServerType.local:
        return Icon(
          CupertinoIcons.folder_fill,
          color: color,
          size: 28,
        );
    }
  }

  Color _getColorForType(ServerType type) {
    switch (type) {
      case ServerType.jellyfin:
        return AppleColors.systemPurple;
      case ServerType.plex:
        return AppleColors.systemOrange;
      case ServerType.navidrome:
        return AppleColors.systemBlue;
      case ServerType.local:
        return AppleColors.systemGreen;
    }
  }

  String _getPlaybookSubtitle(Playbook playbook) {
    switch (playbook.type) {
      case ServerType.local:
        final dirs = playbook.directories;
        return '${dirs.length} folder${dirs.length != 1 ? 's' : ''}';
      default:
        return playbook.serverUrl ?? playbook.typeDisplayName;
    }
  }

  void _showAddPlaybookSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const AddPlaybookSheet(),
    );
  }

  void _showPlaybookOptions(
    BuildContext context,
    Playbook playbook,
    PlaybookService playbookService,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(playbook.name),
        message: Text(playbook.typeDisplayName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showEditPlaybookSheet(context, playbook);
            },
            child: const Text('Edit'),
          ),
          if (playbook.type == ServerType.local)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showManageDirectories(context, playbook, playbookService);
              },
              child: const Text('Manage Directories'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _confirmDeletePlaybook(context, playbook, playbookService);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showEditPlaybookSheet(BuildContext context, Playbook playbook) {
    // TODO: Implement edit playbook sheet
  }

  void _showManageDirectories(
    BuildContext context,
    Playbook playbook,
    PlaybookService playbookService,
  ) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ManageDirectoriesScreen(playbook: playbook),
      ),
    );
  }

  void _confirmDeletePlaybook(
    BuildContext context,
    Playbook playbook,
    PlaybookService playbookService,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Playbook?'),
        content: Text('Are you sure you want to delete "${playbook.name}"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await playbookService.removePlaybook(playbook.id);
              Navigator.pop(context);
              // Refresh content after removing playbook
              if (context.mounted) {
                final appState = context.read<AppState>();
                await appState.refreshLibraryData();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Sheet for adding a new playbook
class AddPlaybookSheet extends StatefulWidget {
  const AddPlaybookSheet({super.key});

  @override
  State<AddPlaybookSheet> createState() => _AddPlaybookSheetState();
}

class _AddPlaybookSheetState extends State<AddPlaybookSheet> {
  ServerType? _selectedType;
  final _nameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();
  final List<String> _selectedDirectories = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Text(
                  'Add Playbook',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _canSave() ? _savePlaybook : null,
                  child: _isLoading
                      ? const CupertinoActivityIndicator()
                      : const Text('Save'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Type Selection
                  Text(
                    'Service Type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildServiceTypeSelector(isDark),
                  const SizedBox(height: 24),
                  
                  // Service-specific configuration
                  if (_selectedType != null) ...[
                    _buildNameField(isDark),
                    const SizedBox(height: 16),
                    ..._buildServiceConfigFields(isDark),
                  ],
                  
                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: CupertinoColors.systemRed,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: CupertinoColors.systemRed,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeSelector(bool isDark) {
    return Row(
      children: [
        _buildServiceTypeOption(ServerType.jellyfin, 'Jellyfin', 
            'assets/icons/jellyfin.svg', AppleColors.systemPurple, isDark),
        const SizedBox(width: 12),
        _buildServiceTypeOption(ServerType.plex, 'Plex', 
            'assets/icons/plex.svg', AppleColors.systemOrange, isDark),
        const SizedBox(width: 12),
        _buildServiceTypeOption(ServerType.navidrome, 'Navidrome', 
            'assets/icons/navidrome.svg', AppleColors.systemBlue, isDark),
        const SizedBox(width: 12),
        _buildServiceTypeOption(ServerType.local, 'Local', 
            null, AppleColors.systemGreen, isDark, icon: CupertinoIcons.folder_fill),
      ],
    );
  }

  Widget _buildServiceTypeOption(
    ServerType type,
    String label,
    String? iconPath,
    Color color,
    bool isDark, {
    IconData? icon,
  }) {
    final isSelected = _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _nameController.text = label;
            _error = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(isDark ? 0.2 : 0.12)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withOpacity(0.6)
                  : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: icon != null
                    ? Icon(icon, color: color, size: 20)
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: SvgPicture.asset(
                          iconPath!,
                          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(bool isDark) {
    return CupertinoTextField(
      controller: _nameController,
      placeholder: 'Playbook Name',
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
    );
  }

  List<Widget> _buildServiceConfigFields(bool isDark) {
    switch (_selectedType!) {
      case ServerType.jellyfin:
      case ServerType.navidrome:
        return [
          CupertinoTextField(
            controller: _serverUrlController,
            placeholder: _selectedType == ServerType.jellyfin 
                ? 'http://your-server:8096'
                : 'http://your-server:4533',
            padding: const EdgeInsets.all(16),
            keyboardType: TextInputType.url,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _usernameController,
            placeholder: 'Username',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _passwordController,
            placeholder: 'Password',
            obscureText: true,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ];
      case ServerType.plex:
        return [
          CupertinoTextField(
            controller: _serverUrlController,
            placeholder: 'http://your-server:32400',
            padding: const EdgeInsets.all(16),
            keyboardType: TextInputType.url,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _tokenController,
            placeholder: 'Plex Token',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ];
      case ServerType.local:
        return [
          Text(
            'Music Directories',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          ..._selectedDirectories.map((dir) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.folder, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dir.split('/').last,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 24,
                  onPressed: () {
                    setState(() {
                      _selectedDirectories.remove(dir);
                    });
                  },
                  child: const Icon(
                    CupertinoIcons.minus_circle_fill,
                    color: CupertinoColors.systemRed,
                    size: 20,
                  ),
                ),
              ],
            ),
          )),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: _addDirectory,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.folder_badge_plus,
                  color: AppleColors.systemGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Directory',
                  style: TextStyle(
                    color: AppleColors.systemGreen,
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }

  Future<void> _addDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Music Directory',
    );
    
    if (result != null && !_selectedDirectories.contains(result)) {
      setState(() {
        _selectedDirectories.add(result);
      });
    }
  }

  bool _canSave() {
    if (_selectedType == null || _nameController.text.isEmpty) {
      return false;
    }

    switch (_selectedType!) {
      case ServerType.jellyfin:
      case ServerType.navidrome:
        return _serverUrlController.text.isNotEmpty &&
               _usernameController.text.isNotEmpty &&
               _passwordController.text.isNotEmpty;
      case ServerType.plex:
        return _serverUrlController.text.isNotEmpty &&
               _tokenController.text.isNotEmpty;
      case ServerType.local:
        return _selectedDirectories.isNotEmpty;
    }
  }

  Future<void> _savePlaybook() async {
    if (!_canSave()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final playbookService = context.read<PlaybookService>();
      final appState = context.read<AppState>();
      
      Map<String, dynamic> config;
      
      switch (_selectedType!) {
        case ServerType.jellyfin:
          config = PlaybookConfig.jellyfin(
            serverUrl: _serverUrlController.text,
            username: _usernameController.text,
            password: _passwordController.text,
          );
          break;
        case ServerType.navidrome:
          config = PlaybookConfig.navidrome(
            serverUrl: _serverUrlController.text,
            username: _usernameController.text,
            password: _passwordController.text,
          );
          break;
        case ServerType.plex:
          config = PlaybookConfig.plex(
            serverUrl: _serverUrlController.text,
            token: _tokenController.text,
          );
          break;
        case ServerType.local:
          config = PlaybookConfig.local(
            directories: _selectedDirectories,
          );
          break;
      }

      final playbook = await playbookService.addPlaybook(
        name: _nameController.text,
        type: _selectedType!,
        config: config,
      );

      // Trigger scan/refresh based on playbook type
      if (_selectedType == ServerType.local) {
        // For local playbooks, scan the directories
        final service = await playbookService.getServiceForPlaybook(playbook.id);
        if (service != null && service is LocalMusicService) {
          await service.scanDirectories();
        }
      }
      
      // Refresh library data to show new content
      await appState.refreshLibraryData();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

/// Screen for managing directories of a local playbook
class ManageDirectoriesScreen extends StatefulWidget {
  final Playbook playbook;

  const ManageDirectoriesScreen({super.key, required this.playbook});

  @override
  State<ManageDirectoriesScreen> createState() => _ManageDirectoriesScreenState();
}

class _ManageDirectoriesScreenState extends State<ManageDirectoriesScreen> {
  late List<String> _directories;

  @override
  void initState() {
    super.initState();
    _directories = List.from(widget.playbook.directories);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? const Color(0xFF0A0A0A)
          : CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        middle: const Text('Manage Directories'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addDirectory,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: _directories.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.folder,
                      size: 48,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No directories added',
                      style: TextStyle(
                        fontSize: 17,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _directories.length,
                itemBuilder: (context, index) {
                  final dir = _directories[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        CupertinoIcons.folder_fill,
                        color: AppleColors.systemGreen,
                      ),
                      title: Text(dir.split('/').last),
                      subtitle: Text(
                        dir,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _removeDirectory(dir),
                        child: const Icon(
                          CupertinoIcons.trash,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _addDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Music Directory',
    );
    
    if (result != null && !_directories.contains(result)) {
      setState(() {
        _directories.add(result);
      });
      _saveChanges();
    }
  }

  void _removeDirectory(String dir) {
    setState(() {
      _directories.remove(dir);
    });
    _saveChanges();
  }

  void _saveChanges() {
    final playbookService = context.read<PlaybookService>();
    final updatedPlaybook = widget.playbook.copyWith(
      config: {
        ...widget.playbook.config,
        'directories': _directories,
      },
    );
    playbookService.updatePlaybook(updatedPlaybook);
  }
}
