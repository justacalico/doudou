import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/playbook.dart';
import '../../services/playbook_service.dart';
import '../../services/base_service.dart';
import '../../providers/app_state.dart';
import '../../widgets/apple_design/apple_theme.dart';

/// Desktop widget for managing Playbooks in settings
class DesktopPlaybooksSection extends StatefulWidget {
  const DesktopPlaybooksSection({super.key});

  @override
  State<DesktopPlaybooksSection> createState() => _DesktopPlaybooksSectionState();
}

class _DesktopPlaybooksSectionState extends State<DesktopPlaybooksSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<PlaybookService>(
      builder: (context, playbookService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playbooks',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your music sources. Enable multiple services to aggregate your music library.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Add new playbook card
            _buildAddPlaybookCard(isDark),
            const SizedBox(height: 16),

            // List of playbooks
            if (playbookService.playbooks.isEmpty)
              _buildEmptyState(isDark)
            else
              ...playbookService.playbooks.map(
                (playbook) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPlaybookCard(playbook, playbookService, isDark),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAddPlaybookCard(bool isDark) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAddPlaybookDialog(),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Playbook',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect to Jellyfin, Navidrome, Plex, or local files',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 48,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: 16),
          Text(
            'No playbooks configured',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a music source to get started',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybookCard(
    Playbook playbook,
    PlaybookService playbookService,
    bool isDark,
  ) {
    final isActive = playbookService.activePlaybookId == playbook.id;
    final color = _getColorForType(playbook.type);

    return Card(
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? color.withOpacity(0.5) : Colors.transparent,
          width: isActive ? 2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: playbook.isEnabled
            ? () => playbookService.setActivePlaybook(playbook.id)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Service Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
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
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Enable/Disable Switch
              Switch(
                value: playbook.isEnabled,
                activeColor: color,
                onChanged: (enabled) {
                  playbookService.togglePlaybook(playbook.id, enabled);
                },
              ),
              // Options button
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handlePlaybookAction(value, playbook, playbookService),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (playbook.type == ServerType.local)
                    const PopupMenuItem(
                      value: 'directories',
                      child: ListTile(
                        leading: Icon(Icons.folder),
                        title: Text('Manage Directories'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
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
          Icons.folder_rounded,
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

  void _handlePlaybookAction(String action, Playbook playbook, PlaybookService playbookService) {
    switch (action) {
      case 'edit':
        _showEditPlaybookDialog(playbook);
        break;
      case 'directories':
        _showManageDirectoriesDialog(playbook);
        break;
      case 'delete':
        _confirmDeletePlaybook(playbook, playbookService);
        break;
    }
  }

  void _showAddPlaybookDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddPlaybookDialog(),
    );
  }

  void _showEditPlaybookDialog(Playbook playbook) {
    // TODO: Implement edit dialog
  }

  void _showManageDirectoriesDialog(Playbook playbook) {
    showDialog(
      context: context,
      builder: (context) => ManageDirectoriesDialog(playbook: playbook),
    );
  }

  void _confirmDeletePlaybook(Playbook playbook, PlaybookService playbookService) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Playbook?'),
        content: Text('Are you sure you want to delete "${playbook.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await playbookService.removePlaybook(playbook.id);
              Navigator.pop(dialogContext);
              // Refresh content after removing playbook
              if (context.mounted) {
                final appState = context.read<AppState>();
                await appState.refreshLibraryData();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for adding a new playbook
class AddPlaybookDialog extends StatefulWidget {
  const AddPlaybookDialog({super.key});

  @override
  State<AddPlaybookDialog> createState() => _AddPlaybookDialogState();
}

class _AddPlaybookDialogState extends State<AddPlaybookDialog> {
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

    return AlertDialog(
      title: const Text('Add Playbook'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Type Selection
              const Text(
                'Service Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildServiceTypeSelector(isDark),
              const SizedBox(height: 24),

              // Service-specific configuration
              if (_selectedType != null) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Playbook Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ..._buildServiceConfigFields(),
              ],

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSave() ? _savePlaybook : null,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildServiceTypeSelector(bool isDark) {
    return Row(
      children: [
        _buildServiceTypeOption(ServerType.jellyfin, 'Jellyfin',
            'assets/icons/jellyfin.svg', AppleColors.systemPurple, isDark),
        const SizedBox(width: 8),
        _buildServiceTypeOption(ServerType.plex, 'Plex',
            'assets/icons/plex.svg', AppleColors.systemOrange, isDark),
        const SizedBox(width: 8),
        _buildServiceTypeOption(ServerType.navidrome, 'Navidrome',
            'assets/icons/navidrome.svg', AppleColors.systemBlue, isDark),
        const SizedBox(width: 8),
        _buildServiceTypeOption(ServerType.local, 'Local',
            null, AppleColors.systemGreen, isDark, icon: Icons.folder_rounded),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedType = type;
            _nameController.text = label;
            _error = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(isDark ? 0.2 : 0.1)
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
                  fontSize: 11,
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

  List<Widget> _buildServiceConfigFields() {
    switch (_selectedType!) {
      case ServerType.jellyfin:
      case ServerType.navidrome:
        return [
          TextField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: _selectedType == ServerType.jellyfin
                  ? 'http://your-server:8096'
                  : 'http://your-server:4533',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case ServerType.plex:
        return [
          TextField(
            controller: _serverUrlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://your-server:32400',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: 'Plex Token',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case ServerType.local:
        return [
          const Text('Music Directories', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ..._selectedDirectories.map((dir) => ListTile(
                leading: const Icon(Icons.folder),
                title: Text(dir.split('/').last),
                subtitle: Text(dir, style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () {
                    setState(() => _selectedDirectories.remove(dir));
                  },
                ),
              )),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Directory'),
            onPressed: _addDirectory,
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

/// Dialog for managing directories of a local playbook
class ManageDirectoriesDialog extends StatefulWidget {
  final Playbook playbook;

  const ManageDirectoriesDialog({super.key, required this.playbook});

  @override
  State<ManageDirectoriesDialog> createState() => _ManageDirectoriesDialogState();
}

class _ManageDirectoriesDialogState extends State<ManageDirectoriesDialog> {
  late List<String> _directories;

  @override
  void initState() {
    super.initState();
    _directories = List.from(widget.playbook.directories);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Directories - ${widget.playbook.name}'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: Column(
          children: [
            Expanded(
              child: _directories.isEmpty
                  ? const Center(child: Text('No directories added'))
                  : ListView.builder(
                      itemCount: _directories.length,
                      itemBuilder: (context, index) {
                        final dir = _directories[index];
                        return ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(dir.split('/').last),
                          subtitle: Text(dir, style: const TextStyle(fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeDirectory(dir),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Directory'),
              onPressed: _addDirectory,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
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
