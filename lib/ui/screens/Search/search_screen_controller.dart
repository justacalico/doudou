import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/utils/app_link_controller.dart' show ProcessLink;
import '/utils/server_storage.dart';
import '/services/music_service.dart';
import '../Settings/settings_screen_controller.dart';
import '/models/server.dart';

class SearchScreenController extends GetxController with ProcessLink {
  final textInputController = TextEditingController();
  final musicServices = Get.find<MusicServices>();
  final suggestionList = [].obs;
  final historyQuerylist = [].obs;
  late Box<dynamic> queryBox;
  int? _queryBoxServerId;
  final urlPasted = false.obs;

  // Desktop search bar related
  final isSearchBarInFocus = false.obs;

  @override
  onInit() {
    _init();
    super.onInit();
  }

  _init() async {
    await _loadQueryBox();
    ever(Get.find<SettingsScreenController>().activeServerId, (_) async {
      await _loadQueryBox();
    });
  }

  Future<void> _loadQueryBox() async {
    final id = currentServerId();
    if (_queryBoxServerId != null && _queryBoxServerId != id) {
      await queryBox.close();
    }
    _queryBoxServerId = id;
    queryBox = await Hive.openBox(searchQueryBoxName(id));
    historyQuerylist.value = queryBox.values.toList().reversed.toList();
  }

  Future<void> onChanged(String text) async {
    if (text.contains("https://")) {
      urlPasted.value = true;
      return;
    }
    urlPasted.value = false;
    final settings = Get.find<SettingsScreenController>();
    final server = settings.activeServer;
    final isYouTube = server?.type == ServerType.youtubeMusic;
    if (!isYouTube) {
      suggestionList.clear();
      return;
    }
    suggestionList.value = await musicServices.getSearchSuggestion(text);
  }

  Future<void> suggestionInput(String txt) async {
    textInputController.text = txt;
    textInputController.selection =
        TextSelection.collapsed(offset: textInputController.text.length);
    await onChanged(txt);
  }

  Future<void> addToHistryQueryList(String txt) async {
    if (_queryBoxServerId != currentServerId()) await _loadQueryBox();
    if (historyQuerylist.length > 9) {
      final queryForRemoval = queryBox.getAt(0);
      await queryBox.deleteAt(0);
      historyQuerylist.removeWhere((element) => element == queryForRemoval);
    }
    if (!historyQuerylist.contains(txt)) {
      await queryBox.add(txt);
      historyQuerylist.insert(0, txt);
    }

    //reset current query and suggestionlist
    reset();
  }

  void reset() {
    urlPasted.value = false;
    textInputController.text = "";
    suggestionList.clear();
  }

  void hideSuggestions() {
    urlPasted.value = false;
    suggestionList.clear();
    isSearchBarInFocus.value = false;
  }

  void setDesktopSearchFocus(bool hasFocus) {
    isSearchBarInFocus.value = hasFocus;
    if (!hasFocus) {
      hideSuggestions();
    }
  }

  Future<void> removeQueryFromHistory(String txt) async {
    if (_queryBoxServerId != currentServerId()) await _loadQueryBox();
    final index = queryBox.values.toList().indexOf(txt);
    await queryBox.deleteAt(index);
    historyQuerylist.remove(txt);
  }

  @override
  void dispose() {
    textInputController.dispose();
    if (_queryBoxServerId != null) queryBox.close();
    super.dispose();
  }
}
