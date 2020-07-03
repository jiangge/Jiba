import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jiba/bloc/journal_bloc.dart';
import 'package:jiba/helpers/datetime_helpers.dart';
import 'package:jiba/helpers/network_helpers.dart';
import 'package:jiba/resources/shared_prefs_provider.dart';
import 'package:jiba/models/journal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

TextStyle smallTextStyle = TextStyle(color: Colors.black, fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.normal);

class JournalEditPage extends StatefulWidget {
  ///Weather or not there was a early version of today's journal.
  final bool hasUncompletedContent;

  ///the id to refer to the photo attached to the journal.
  final int nextId;

  final Journal tempJournal;

  JournalEditPage({this.hasUncompletedContent = false, this.nextId, this.tempJournal})
      : assert((hasUncompletedContent && tempJournal != null) || (!hasUncompletedContent && tempJournal == null));

  @override
  State<StatefulWidget> createState() => JournalEditPageState();
}

class JournalEditPageState extends State<JournalEditPage> {
  final TextEditingController textEditingController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  Journal tempJournal;

  double elevation = 0;
  Color appBarColor = Colors.transparent;

  double locationOpacity = 0;
  double dateOpacity = 0;

  double longitude, latitude;
  String location, weatherCode = '01d';

  String dropdownFontFamilyValue = noto;

  File imageFile;

  List<int> imageBytes;

  ///Weather or not there is a photo attached.
  bool photoAttached = false;

  ///The timer used to save content periodically
  Timer timer;

  int nextId;

  @override
  void initState() {
    super.initState();

    if (widget.nextId == null) {
      journalBloc.getNextId().then((value) {
        nextId = value;
      });
    } else {
      nextId = widget.nextId;
    }

    if (widget.hasUncompletedContent) {
      recoverUncompletedJournal();
    } else {
      setState(() {
        setToLastFontFamily();
      });
    }

    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        dateOpacity = 1;
        appBarColor = MediaQuery.of(context).platformBrightness == Brightness.dark ? Colors.black : Colors.white;
      });
    });

    timer = Timer.periodic(Duration(seconds: 20), (timer) {
      print("${timer.isActive}" + textEditingController.text);

      if (timer.isActive) saveContent();
    });

    scrollController.addListener(onTextScrolled);
  }

  @override
  void dispose() {
    timer?.cancel();

    textEditingController.dispose();

    scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.bottomRight,
              child: Transform.scale(
                scale: 34,
                child: FloatingActionButton(
                  elevation: 0,
                  child: Container(
                    color: Colors.transparent,
                  ),
                  onPressed: () {},
                  backgroundColor: MediaQuery.of(context).platformBrightness == Brightness.dark ? Colors.black : Colors.white,
                ),
              ),
            ),
            Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: Colors.transparent,
                child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: PreferredSize(
                        child: AppBar(
                          leading: IconButton(icon: Icon(Icons.chevron_left), onPressed: onBackPressed),
                          iconTheme: IconThemeData(
                            color: Colors.black, //change your color here
                          ),
                          elevation: elevation,
                          backgroundColor: appBarColor,
                          flexibleSpace: Padding(
                              padding: EdgeInsets.only(left: 24, right: 12, top: 96),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: <Widget>[
                                  AnimatedOpacity(
                                    duration: Duration(milliseconds: 600),
                                    opacity: locationOpacity,
                                    child: Text('', style: smallTextStyle),
                                  ),
                                  Spacer(),
                                  AnimatedOpacity(
                                    duration: Duration(milliseconds: 600),
                                    opacity: dateOpacity,
                                    child: Text(DateTime.now().toDisplayString(), style: smallTextStyle),
                                  ),
                                ],
                              )),
                          actions: <Widget>[
                            DropdownButton<String>(
                              value: weatherCode,
                              icon: Icon(
                                Icons.arrow_downward,
                                color: Colors.black,
                              ),
                              iconSize: 18,
                              underline: Divider(
                                color: Colors.black,
                              ),
                              onChanged: onWeatherChanged,
                              items: <String>[
                                '01d',
                                '01n',
                                '02d',
                                '02n',
                                '03d',
                                '03n',
                                '04d',
                                '04n',
                                '09d',
                                '09n',
                                '10d',
                                '10n',
                                '11d',
                                '11n',
                                '13d',
                                '13n',
                                '50d',
                                '50n'
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                    value: value,
                                    child: Image.asset(
                                      'assets/weather_icons/$value.png',
                                      scale: 0.5,
                                    ));
                              }).toList(),
                            ),
                            SizedBox(
                              width: 12,
                            ),
                            DropdownButton<String>(
                              value: dropdownFontFamilyValue,
                              icon: Icon(
                                Icons.arrow_downward,
                                color: Colors.black,
                              ),
                              iconSize: 18,
                              underline: Divider(
                                color: Colors.black,
                              ),
                              onChanged: onFontChanged,
                              items: <String>[noto, ma, liu].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    fontNames[value],
                                    style: TextStyle(color: Colors.black, fontFamily: value),
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(
                              width: 12,
                            ),
                            IconButton(icon: Icon(Icons.add_a_photo), onPressed: onAddPhotoPressed),
                            //IconButton(icon: Icon(Icons.done), onPressed: onDonePressed),
                          ],
                        ),
                        preferredSize: Size.fromHeight(100)),
                    body: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: <Widget>[
                          if (photoAttached)
                            GestureDetector(
                              onLongPress: onPhotoLongPressed,
                              child: Container(
                                height: 200,
                                child: ClipRRect(
                                    borderRadius: BorderRadius.all(Radius.circular(12)), child: Image.memory(this.imageBytes, fit: BoxFit.cover)),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.only(left: 24, right: 24, bottom: 0, top: photoAttached ? 12 : 0),
                            child: TextField(
                              controller: textEditingController,
                              minLines: 40,
                              maxLines: 50,
                              cursorColor: Colors.black,
                              decoration: InputDecoration(
                                focusColor: Colors.transparent,
                                fillColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: TextStyle(fontSize: 24, fontFamily: dropdownFontFamilyValue),
                            ),
                          )
                        ],
                      ),
                    ))),
          ],
        ),
      ),
    );
  }

  void onTextScrolled() {
    if (this.mounted) {
      if (scrollController.offset <= 0) {
        setState(() {
          elevation = 0;
        });
      } else {
        setState(() {
          elevation = 8;
        });
      }
    }
  }

  void onAddPhotoPressed() => getImage();

  Future getImage() async {
    if (await checkPhotoLibraryPermission()) {
      var image = await ImagePicker.pickImage(source: ImageSource.gallery);

      imageBytes = await image.readAsBytes();

      var appDocDir = await getTemporaryDirectory();
      var f = File("${appDocDir.path}/temp.png");
      f.writeAsBytes(imageBytes);

      setState(() {
        photoAttached = true;
        this.imageFile = image;
      });
    } else {
      //If permission is not granted, we notify the user
      showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
                title: Text(
                  'Access denied',
                  style: TextStyle(fontFamily: 'SF Pro', fontWeight: FontWeight.bold),
                ),
                content: Text('Permission to access photo library is not granted.'),
                actions: <Widget>[
                  CupertinoDialogAction(
                    child: Text(
                      'Okay',
                      style: TextStyle(color: Colors.blue),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ));
    }
  }

  Future<bool> checkPhotoLibraryPermission() async {
    PermissionStatus permission = await PermissionHandler().checkPermissionStatus(PermissionGroup.photos);
    if (permission != PermissionStatus.granted) {
      Map<PermissionGroup, PermissionStatus> permissions = await PermissionHandler().requestPermissions([PermissionGroup.photos]);

      if (permissions[PermissionGroup.photos] != PermissionStatus.granted) {
        return Future.value(false);
      } else {
        return Future.value(true);
      }
    } else {
      return Future.value(true);
    }
  }

  void saveContent() {
    print("Has uncompleted: ${widget.hasUncompletedContent}");
    if (journalBloc.hasIncomplete) {
      print("HAS INCOMPLETE!");
      journalBloc.updateJournal(Journal(
          id: tempJournal.id,
          content: textEditingController.text,
          createdDate: tempJournal.createdDate,
          fontFamily: dropdownFontFamilyValue,
          weatherCode: tempJournal.weatherCode ?? '01d',
          location: tempJournal.location,
          longitude: tempJournal.longitude,
          latitude: tempJournal.latitude,
          imageBytes: imageBytes));
    } else {
      if (!(imageBytes == null && textEditingController.text.isEmpty)) {
        journalBloc.addJournal(Journal(
            id: journalBloc.nextId,
            content: textEditingController.text,
            createdDate: DateTime.now(),
            fontFamily: dropdownFontFamilyValue,
            weatherCode: weatherCode ?? '01d',
            location: location,
            longitude: longitude,
            latitude: latitude,
            imageBytes: imageBytes));
      }
    }
  }

  void saveLastUsedFontFamily(String fontFamily) {
    sharedPrefsProvider.lastFontFamily = fontFamily;
  }

  void recoverUncompletedJournal() async {
    tempJournal = widget.tempJournal;

    if (tempJournal.hasImage) {
      Directory appTempDir = await getTemporaryDirectory();
      File temp = File('${appTempDir.path}/temp.png');
      temp.readAsBytes().then((bytes) {
        setState(() {
          textEditingController.text = tempJournal.content;
          dropdownFontFamilyValue = tempJournal.fontFamily;
          imageFile = temp;
          this.imageBytes = bytes;
          photoAttached = true;
        });
      });
    } else {
      textEditingController.text = tempJournal.content;

      setState(() {
        dropdownFontFamilyValue = tempJournal.fontFamily;
        location = tempJournal.location;
        weatherCode = tempJournal.weatherCode;
        locationOpacity = 1;
      });
    }
  }

  void setToLastFontFamily() {
    dropdownFontFamilyValue = sharedPrefsProvider.lastFontFamily;
    //dropdownFontFamilyValue = tempJournal.fontFamily;
  }

  void onWeatherChanged(String code) {
    setState(() {
      weatherCode = code;
    });
  }

  void onFontChanged(String fontFamily) {
    setState(() {
      dropdownFontFamilyValue = fontFamily;
    });
    saveContent();
    saveLastUsedFontFamily(fontFamily);
  }

  void onPhotoLongPressed() {
    showCupertinoModalPopup(
        context: context,
        builder: (_) {
          return CupertinoActionSheet(
            actions: <Widget>[
              CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      this.photoAttached = false;
                      this.imageFile = null;
                      this.imageBytes = null;
                    });
                  },
                  child: Text('Delete'))
            ],
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel')),
          );
        });
  }

  void onBackPressed() {
    Navigator.pop(context);
    saveContent();
  }
}
