import 'package:flutter/material.dart';
import '/utils/app_l10n.dart';
import 'package:get/get.dart';

import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/widgets/piped_sync_widget.dart';
import '../../widgets/create_playlist_dialog.dart';
import 'library.dart';

const String _kCombinedLibraryTag = 'fullLibrary';

class CombinedLibrary extends StatefulWidget {
  const CombinedLibrary({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<CombinedLibrary> createState() => _CombinedLibraryState();
}

class _CombinedLibraryState extends State<CombinedLibrary> {
  @override
  void initState() {
    super.initState();
    Get.put(
      CombinedLibraryController(
          initialIndex: widget.initialTabIndex.clamp(0, 3)),
      tag: _kCombinedLibraryTag,
    );
  }

  @override
  void dispose() {
    Get.delete<CombinedLibraryController>(tag: _kCombinedLibraryTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabCon = Get.find<CombinedLibraryController>(tag: _kCombinedLibraryTag);
    final settingscrnController = Get.find<SettingsScreenController>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 85,
        backgroundColor: Theme.of(context).canvasColor,
        elevation: 0,
        actions: [
          Obx(() => (settingscrnController.isLinkedWithPiped.isTrue)
              ? const PipedSyncWidget(
                  padding: EdgeInsets.only(right: 10, top: 50))
              : const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.only(top: 50.0, right: 25),
            child: SizedBox(
              height: 40,
              width: 50,
              child: FittedBox(
                child: FloatingActionButton.extended(
                    elevation: 0,
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              const CreateNRenamePlaylistPopup());
                    },
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.add,
                        ),
                      ],
                    )),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          splashFactory: NoSplash.splashFactory,
          controller: tabCon.tabController,
          tabs: [
            Tab(text: context.l10n.songs),
            Tab(text: context.l10n.playlists),
            Tab(text: context.l10n.albums),
            Tab(text: context.l10n.artists),
          ],
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 60.0, left: 5),
          child:
              Text(context.l10n.library, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      body: TabBarView(
        controller: tabCon.tabController,
        children: const [
          SongsLibraryWidget(
            isBottomNavActive: true,
          ),
          PlaylistNAlbumLibraryWidget(
              isAlbumContent: false, isBottomNavActive: true),
          PlaylistNAlbumLibraryWidget(isBottomNavActive: true),
          LibraryArtistWidget(isBottomNavActive: true),
        ],
      ),
    );
  }
}

class CombinedLibraryController extends GetxController
    with GetSingleTickerProviderStateMixin {
  CombinedLibraryController({this.initialIndex = 0});

  final int initialIndex;
  late TabController tabController;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(
        vsync: this, length: 4, initialIndex: initialIndex.clamp(0, 3));
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }
}
