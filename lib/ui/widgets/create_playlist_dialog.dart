import 'package:audio_service/audio_service.dart';
import '/utils/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '/services/piped_service.dart';
import '../screens/Library/library_controller.dart';
import '/ui/widgets/snackbar.dart';
import '../../models/playlist.dart';
import 'common_dialog_widget.dart';
import 'modified_text_field.dart';

class CreateNRenamePlaylistPopup extends StatelessWidget {
  const CreateNRenamePlaylistPopup(
      {super.key,
      this.isCreateNadd = false,
      this.songItems,
      this.renamePlaylist = false,
      this.playlist});
  final bool isCreateNadd;
  final bool renamePlaylist;
  final List<MediaItem>? songItems;
  final Playlist? playlist;

  @override
  Widget build(BuildContext context) {
    final librPlstCntrller = Get.find<LibraryPlaylistsController>();
    librPlstCntrller.changeCreationMode("local");
    librPlstCntrller.textInputController.text = "";
    final isPipedLinked = Get.find<PipedServices>().isLoggedIn;
    return CommonDialog(
      child: Container(
        height: (isPipedLinked && !renamePlaylist) ? 245 : 200,
        padding:
            const EdgeInsets.only(top: 30, left: 30, right: 30, bottom: 10),
        child: Stack(
          children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Marquee(
                    delay: const Duration(milliseconds: 300),
                    id: "createPlaylist",
                    child: Text(
                      renamePlaylist
                          ? context.l10n.renamePlaylist
                          : context.l10n.createNewPlaylist,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              if (isPipedLinked && !renamePlaylist)
                Obx(
                  () => RadioGroup<String>(
                    groupValue:
                        librPlstCntrller.playlistCreationMode.value,
                    onChanged: librPlstCntrller.changeCreationMode,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Radio<String>(value: "piped"),
                            Text(context.l10n.piped),
                          ],
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        Row(
                          children: [
                            const Radio<String>(value: "local"),
                            Text(context.l10n.local),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ModifiedTextField(
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                cursorColor: Theme.of(context).textTheme.titleSmall!.color,
                controller: librPlstCntrller.textInputController,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.only(left: 5),
                  focusColor: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InkWell(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(context.l10n.cancel),
                      ),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).textTheme.titleLarge!.color,
                          borderRadius: BorderRadius.circular(10)),
                      child: InkWell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15.0, vertical: 10),
                          child: Text(
                            isCreateNadd
                                ? context.l10n.createnAdd
                                : renamePlaylist
                                    ? context.l10n.rename
                                    : context.l10n.create,
                            style:
                                TextStyle(color: Theme.of(context).canvasColor),
                          ),
                        ),
                        onTap: () async {
                          if (renamePlaylist) {
                            librPlstCntrller
                                .renamePlaylist(playlist!)
                                .then((value) {
                              if (value) {
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    snackbar(context, context.l10n.playlistRenameAlert,
                                        size: SnackBarSize.MEDIUM));
                              }
                            });
                          } else {
                            librPlstCntrller
                                .createNewPlaylist(
                                    createPlaylistNaddSong: isCreateNadd,
                                    songItems: songItems)
                                .then((value) {
                              if (!context.mounted) return;
                              if (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    snackbar(
                                        context,
                                        isCreateNadd
                                            ? context.l10n.playlistCreatednsongAddedAlert
                                            : context.l10n.playlistCreatedAlert,
                                        size: SnackBarSize.MEDIUM));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    snackbar(context, context.l10n.errorOccuredAlert,
                                        size: SnackBarSize.MEDIUM));
                              }
                              Navigator.of(context).pop();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              )
            ]),
            Obx(() =>
                (librPlstCntrller.creationInProgress.isTrue && isPipedLinked)
                    ? const Positioned(
                        top: 5,
                        right: 8,
                        child: SizedBox(
                            height: 15,
                            width: 15,
                            child: CircularProgressIndicator(
                              backgroundColor: Colors.transparent,
                              strokeWidth: 2,
                            )),
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
