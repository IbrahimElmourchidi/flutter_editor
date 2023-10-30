// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'dart:io' show File, Platform;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/extensions.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../universal_ui/universal_ui.dart';
import '../widgets/time_stamp_embed_widget.dart';
import 'read_only_page.dart';

enum _SelectionType {
  none,
  word,
  // line,
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final QuillController _controller = QuillController.basic();
  // late final Future<void> _loadDocumentFromAssetsFuture;
  final FocusNode _focusNode = FocusNode();
  Timer? _selectAllTimer;
  _SelectionType _selectionType = _SelectionType.none;

  @override
  void dispose() {
    _selectAllTimer?.cancel();
    // Dispose the controller to free resources
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // _loadDocumentFromAssetsFuture = _loadFromAssets();
  }

  @override
  Widget build(BuildContext context) {
    void uploadImage() async {
      final result = await FilePicker.platform.pickFiles();
      if (result?.files == null) return;
      final pickedFile = result?.files.first;
      final path = 'files/${pickedFile!.path!}';
      final file = File(pickedFile!.path!);
      final storageInstance = FirebaseStorage.instance;
      final ref = storageInstance.ref().child(path);
      ref.putFile(file).then((snap) async {
        final url = await snap.ref.getDownloadURL();
        print(url);
      }).catchError((e) => print('errorrrrrrrrrrrrr => $e'));
    }

    _controller.changes.listen((change) {
      var delta = _controller.document
          .toDelta()
          .map(
            (e) => e.toJson(),
          )
          .toList();
      final converter = QuillDeltaToHtmlConverter(
        delta,
        ConverterOptions.forEmail(),
      );

      final html = converter.convert();
      print(html);

      // print(delta);
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Flutter Quill',
        ),
        actions: [
          IconButton(
            onPressed: () => _insertTimeStamp(
              _controller,
              DateTime.now().toString(),
            ),
            icon: const Icon(Icons.add_alarm_rounded),
          ),
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                content: Text(_controller.document.toPlainText([
                  ...FlutterQuillEmbeds.builders(),
                  TimeStampEmbedBuilderWidget()
                ])),
              ),
            ),
            icon: const Icon(Icons.text_fields_rounded),
          )
        ],
      ),
      drawer: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
        color: Colors.grey.shade800,
        child: _buildMenuBar(context),
      ),
      body: _buildWelcomeEditor(context),
    );
  }

  bool _onTripleClickSelection() {
    final controller = _controller;

    _selectAllTimer?.cancel();
    _selectAllTimer = null;

    // If you want to select all text after paragraph, uncomment this line
    // if (_selectionType == _SelectionType.line) {
    //   final selection = TextSelection(
    //     baseOffset: 0,
    //     extentOffset: controller.document.length,
    //   );

    //   controller.updateSelection(selection, ChangeSource.REMOTE);

    //   _selectionType = _SelectionType.none;

    //   return true;
    // }

    if (controller.selection.isCollapsed) {
      _selectionType = _SelectionType.none;
    }

    if (_selectionType == _SelectionType.none) {
      _selectionType = _SelectionType.word;
      _startTripleClickTimer();
      return false;
    }

    if (_selectionType == _SelectionType.word) {
      final child = controller.document.queryChild(
        controller.selection.baseOffset,
      );
      final offset = child.node?.documentOffset ?? 0;
      final length = child.node?.length ?? 0;

      final selection = TextSelection(
        baseOffset: offset,
        extentOffset: offset + length,
      );

      controller.updateSelection(selection, ChangeSource.REMOTE);

      // _selectionType = _SelectionType.line;

      _selectionType = _SelectionType.none;

      _startTripleClickTimer();

      return true;
    }

    return false;
  }

  void _startTripleClickTimer() {
    _selectAllTimer = Timer(const Duration(milliseconds: 900), () {
      _selectionType = _SelectionType.none;
    });
  }

  QuillEditor get quillEditor {
    if (kIsWeb) {
      return QuillEditor(
        focusNode: _focusNode,
        scrollController: ScrollController(),
        configurations: QuillEditorConfigurations(
          placeholder: 'Add content',
          readOnly: false,
          scrollable: true,
          autoFocus: false,
          expands: false,
          padding: EdgeInsets.zero,
          onTapUp: (details, p1) {
            return _onTripleClickSelection();
          },
          customStyles: const DefaultStyles(
            h1: DefaultTextBlockStyle(
                TextStyle(
                  fontSize: 32,
                  color: Colors.black,
                  height: 1.15,
                  fontWeight: FontWeight.w300,
                ),
                VerticalSpacing(16, 0),
                VerticalSpacing(0, 0),
                null),
            sizeSmall: TextStyle(fontSize: 9),
          ),
          embedBuilders: [
            ...defaultEmbedBuildersWeb,
            TimeStampEmbedBuilderWidget()
          ],
        ),
      );
    }
    return QuillEditor(
      configurations: QuillEditorConfigurations(
        placeholder: 'Add content',
        readOnly: false,
        autoFocus: false,
        enableSelectionToolbar: isMobile(),
        expands: false,
        padding: EdgeInsets.zero,
        onImagePaste: _onImagePaste,
        onTapUp: (details, p1) {
          return _onTripleClickSelection();
        },
        customStyles: const DefaultStyles(
          h1: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 32,
                color: Colors.black,
                height: 1.15,
                fontWeight: FontWeight.w300,
              ),
              VerticalSpacing(16, 0),
              VerticalSpacing(0, 0),
              null),
          sizeSmall: TextStyle(fontSize: 9),
          subscript: TextStyle(
            fontFamily: 'SF-UI-Display',
            fontFeatures: [FontFeature.subscripts()],
          ),
          superscript: TextStyle(
            fontFamily: 'SF-UI-Display',
            fontFeatures: [FontFeature.superscripts()],
          ),
        ),
        embedBuilders: [
          ...FlutterQuillEmbeds.builders(),
          TimeStampEmbedBuilderWidget()
        ],
      ),
      scrollController: ScrollController(),
      focusNode: _focusNode,
    );
  }

  QuillToolbar get quillToolbar {
    if (kIsWeb) {
      return QuillToolbar(
        configurations: QuillToolbarConfigurations(
          embedButtons: FlutterQuillEmbeds.buttons(
            onImagePickCallback: _onImagePickCallback,
            webImagePickImpl: _webImagePickImpl,
          ),
          buttonOptions: QuillToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              afterButtonPressed: _focusNode.requestFocus,
            ),
          ),
        ),
        // afterButtonPressed: _focusNode.requestFocus,
      );
    }
    if (_isDesktop()) {
      return QuillToolbar(
        configurations: QuillToolbarConfigurations(
          embedButtons: FlutterQuillEmbeds.buttons(
            onImagePickCallback: _onImagePickCallback,
            filePickImpl: openFileSystemPickerForDesktop,
          ),
          showAlignmentButtons: true,
          buttonOptions: QuillToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              afterButtonPressed: _focusNode.requestFocus,
            ),
          ),
        ),
        // afterButtonPressed: _focusNode.requestFocus,
      );
    }
    return QuillToolbar(
      configurations: QuillToolbarConfigurations(
        showCenterAlignment: false,
        showClearFormat: false,
        showCodeBlock: false,
        showDividers: false,
        showJustifyAlignment: false,
        showColorButton: false,
        showDirection: false,
        showHeaderStyle: false,
        showIndent: false,
        showLink: false,
        showQuote: false,
        showRedo: false,
        showUndo: false,
        showFontFamily: false,
        showFontSize: false,
        showStrikeThrough: false,
        showSubscript: false,
        showSuperscript: false,
        showSearchButton: false,
        showListCheck: false,
        showLeftAlignment: false,
        showRightAlignment: false,
        showSmallButton: false,
        showListNumbers: false,
        showInlineCode: false,
        showAlignmentButtons: false,
        showListBullets: true,
        embedButtons: FlutterQuillEmbeds.buttons(
          // provide a callback to enable picking images from device.
          // if omit, "image" button only allows adding images from url.
          // same goes for videos.
          onImagePickCallback: _onImagePickCallback,
          onVideoPickCallback: _onVideoPickCallback,
          // uncomment to provide a custom "pick from" dialog.
          // mediaPickSettingSelector: _selectMediaPickSetting,
          // uncomment to provide a custom "pick from" dialog.
          // cameraPickSettingSelector: _selectCameraPickSetting,
        ),
        buttonOptions: QuillToolbarButtonOptions(
          base: QuillToolbarBaseButtonOptions(
            afterButtonPressed: _focusNode.requestFocus,
          ),
        ),
      ),
      // afterButtonPressed: _focusNode.requestFocus,
    );
  }

  Widget _buildWelcomeEditor(BuildContext context) {
    // BUG in web!! should not releated to this pull request
    ///
    ///══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═════════════════════
    ///══════════════════════════════════════
    // The following bool object was thrown building MediaQuery
    //(MediaQueryData(size: Size(769.0, 1205.0),
    // devicePixelRatio: 1.0, textScaleFactor: 1.0, platformBrightness:
    //Brightness.dark, padding:
    // EdgeInsets.zero, viewPadding: EdgeInsets.zero, viewInsets:
    // EdgeInsets.zero,
    // systemGestureInsets:
    // EdgeInsets.zero, alwaysUse24HourFormat: false, accessibleNavigation:
    // false,
    // highContrast: false,
    // disableAnimations: false, invertColors: false, boldText: false,
    //navigationMode: traditional,
    // gestureSettings: DeviceGestureSettings(touchSlop: null), displayFeatures:
    // []
    // )):
    //   false
    // The relevant error-causing widget was:
    //   SafeArea
    ///
    ///
    return SafeArea(
      child: QuillProvider(
        configurations: QuillConfigurations(
          controller: _controller,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              flex: 15,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: quillEditor,
              ),
            ),
            kIsWeb
                ? Expanded(
                    child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: quillToolbar,
                  ))
                : Container(
                    child: quillToolbar,
                  )
          ],
        ),
      ),
    );
  }

  bool _isDesktop() => !kIsWeb && !Platform.isAndroid && !Platform.isIOS;

  Future<String?> openFileSystemPickerForDesktop(BuildContext context) async {
    return await FilesystemPicker.open(
      context: context,
      rootDirectory: await getApplicationDocumentsDirectory(),
      fsType: FilesystemType.file,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
  }

  // Renders the image picked by imagePicker from local file storage
  // You can also upload the picked image to any server (eg : AWS s3
  // or Firebase) and then return the uploaded image URL.
  Future<String> _onImagePickCallback(File file) async {
    // Copies the picked file from temporary cache to applications directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final copiedFile =
        await file.copy('${appDocDir.path}/${path.basename(file.path)}');
    return copiedFile.path.toString();
  }

  Future<String?> _webImagePickImpl(
      OnImagePickCallback onImagePickCallback) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) {
      return null;
    }

    // Take first, because we don't allow picking multiple files.
    final fileName = result.files.first.name;
    final file = File(fileName);

    return onImagePickCallback(file);
  }

  // Renders the video picked by imagePicker from local file storage
  // You can also upload the picked video to any server (eg : AWS s3
  // or Firebase) and then return the uploaded video URL.
  Future<String> _onVideoPickCallback(File file) async {
    // Copies the picked file from temporary cache to applications directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final copiedFile =
        await file.copy('${appDocDir.path}/${path.basename(file.path)}');
    return copiedFile.path.toString();
  }

  // ignore: unused_element
  Future<MediaPickSetting?> _selectMediaPickSetting(BuildContext context) =>
      showDialog<MediaPickSetting>(
        context: context,
        builder: (ctx) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.collections),
                label: const Text('Gallery'),
                onPressed: () => Navigator.pop(ctx, MediaPickSetting.Gallery),
              ),
              TextButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Link'),
                onPressed: () => Navigator.pop(ctx, MediaPickSetting.Link),
              )
            ],
          ),
        ),
      );

  // ignore: unused_element
  Future<MediaPickSetting?> _selectCameraPickSetting(BuildContext context) =>
      showDialog<MediaPickSetting>(
        context: context,
        builder: (ctx) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.camera),
                label: const Text('Capture a photo'),
                onPressed: () => Navigator.pop(ctx, MediaPickSetting.Camera),
              ),
              TextButton.icon(
                icon: const Icon(Icons.video_call),
                label: const Text('Capture a video'),
                onPressed: () => Navigator.pop(ctx, MediaPickSetting.Video),
              )
            ],
          ),
        ),
      );

  Widget _buildMenuBar(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const itemStyle = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Divider(
          thickness: 2,
          color: Colors.white,
          indent: size.width * 0.1,
          endIndent: size.width * 0.1,
        ),
        ListTile(
          title: const Center(child: Text('Read only demo', style: itemStyle)),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: _readOnly,
        ),
        Divider(
          thickness: 2,
          color: Colors.white,
          indent: size.width * 0.1,
          endIndent: size.width * 0.1,
        ),
      ],
    );
  }

  void _readOnly() {
    Navigator.pop(super.context);
    Navigator.push(
      super.context,
      MaterialPageRoute(
        builder: (context) => ReadOnlyPage(),
      ),
    );
  }

  Future<String> _onImagePaste(Uint8List imageBytes) async {
    // Saves the image to applications directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final file = await File(
      '${appDocDir.path}/${path.basename('${DateTime.now().millisecondsSinceEpoch}.png')}',
    ).writeAsBytes(imageBytes, flush: true);
    return file.path.toString();
  }

  static void _insertTimeStamp(QuillController controller, String string) {
    controller.document.insert(controller.selection.extentOffset, '\n');
    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.LOCAL,
    );

    controller.document.insert(
      controller.selection.extentOffset,
      TimeStampEmbed(string),
    );

    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.LOCAL,
    );

    controller.document.insert(controller.selection.extentOffset, ' ');
    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.LOCAL,
    );

    controller.document.insert(controller.selection.extentOffset, '\n');
    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.LOCAL,
    );
  }
}
