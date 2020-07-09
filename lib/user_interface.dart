import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'config/ui_variables.dart';
import 'config/constants.dart' as constants;

class UserInterface extends StatefulWidget {
  @override
  UserInterfaceState createState() => UserInterfaceState();
}

enum UserRoute{
  init, friends, notifications, dialog,
}

class UserInterfaceState extends State<UserInterface> {

  var id = TextEditingController();
  var pw = TextEditingController();
  var nickname = TextEditingController();
  var friends = [];
  var notifications = [];
  var friendId = "";
  var friendNickname = "";
  var dialogTtileController = TextEditingController();
  var scrollController = ScrollController();
  var messages = [];
  var messageDate = "";

  var currentRoute = UserRoute.init;

  Socket socket;
  var httpClient = HttpClient();

  @override
  Widget build(BuildContext context) {
    if (currentRoute == UserRoute.init) {
      final Map arguments = ModalRoute
        .of(context)
        .settings
        .arguments;
      id.text = arguments[constants.id];
      pw.text = arguments[constants.password];
      nickname.text = arguments[constants.nickname];
      friends = arguments[constants.friends];
      notifications = arguments[constants.notifications];
      currentRoute = UserRoute.friends;

      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

      var loading = false;
      scrollController.addListener(() async {
        if(loading) return;
        double maxScroll = scrollController.position.maxScrollExtent;
        double currentScroll = scrollController.position.pixels;
        double delta = 1.0; // or something else..
        if ( (currentScroll - maxScroll).abs() <= delta) { // whatever you determine here
          loading = true;
          var msg = {
            constants.type: constants.message,
            constants.subtype: constants.history,
            constants.id: this.id.text.trim(),
            constants.password: this.pw.text.trim(),
            constants.friend: friendId,
            constants.date: messageDate,
            constants.version: constants.currentVersion
          };

          try {
            var request = await httpClient.putUrl(Uri.parse("${constants.protocol}${constants.server}/"));
            request.headers.add("content-type", "application/json;charset=utf-8");
            request.write(json.encode(msg));
            var response = await request.close();
            if (response.statusCode == 200) {
              var string = await response.transform(utf8.decoder).join();
              var result = json.decode(string);
              if (currentRoute == UserRoute.dialog && result[constants.friend] == friendId) {
                setState(() => messages.addAll((result[constants.history] as List).reversed));
                messageDate = result[constants.date];
              }
            } else {
              this.showMessage(uiVariables['system_error']);
            }
          }catch(e){
            this.showMessage(uiVariables['network_error']);
          }

          loading = false;
        }
      });

      Socket.connect(constants.server, constants.tcpPort)
        .then((socket) {
        this.socket = socket;
        var msg = {
          constants.type: constants.login,
          constants.id: id.text.trim(),
          constants.password: pw.text.trim(),
          constants.version: constants.currentVersion,
        };
        socket.write(json.encode(msg) + constants.end);
        var message = List<int>();
        socket.forEach((packet) {
          message.addAll(packet); //粘包
          if (utf8.decode(message).endsWith(constants.end)) {
            List<String> msgs = utf8.decode(message).trim().split(constants.end); //拆包
            for (String msg in msgs) {
              processMesssage(msg);
            }
            message.clear();
          }
        });
        var ctx = Navigator.of(context);
        socket.handleError(() => ctx.popUntil(ModalRoute.withName('/')));
        socket.done.then((_) => ctx.popUntil(ModalRoute.withName('/')));
      });
    }

    if(currentRoute==UserRoute.dialog){

      ListView dialog = ListView.builder(
        padding: EdgeInsets.all(10.0),
        controller: scrollController,
        reverse: true,
        itemBuilder: (BuildContext context, int index) {
          Map item = messages[index];

          var align = MainAxisAlignment.start;
          if(item[constants.id] == id.text.trim()){
            align = MainAxisAlignment.end;
          }

          var text = "${item[constants.id]}:\n${item[constants.body]}";

          var row = Row(
            mainAxisAlignment: align,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Text("$text", textAlign: TextAlign.start,),
              ),
            ],
          );

          if(item[constants.id] == id.text.trim()){
            row.children.add(Icon(Icons.message));
          }else{
            row.children.insert(0, Icon(Icons.message));
          }

          return row;
        },
        itemCount: messages.length,
      );

      return  Scaffold(
        appBar: AppBar(
          title: Text("$friendId($friendNickname)"),
          centerTitle: true,
          leading: IconButton(
            icon: InputDecorator(
              decoration: InputDecoration(icon: Icon(Icons.arrow_back)),
            ),
            onPressed: () => setState(()=>currentRoute=UserRoute.friends),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: dialog,
            ),
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(10.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: dialogTtileController,
                    ),
                  ),
                  RaisedButton(
                    child: Text(uiVariables['send']),
                    onPressed: () async {
                      if(dialogTtileController.text.isNotEmpty){
                        var msg = {
                          constants.id: id.text.trim(),
                          constants.password: pw.text.trim(),
                          constants.type: constants.message,
                          constants.subtype: constants.text,
                          constants.body: dialogTtileController.text,
                          constants.to: friendId,
                        };
                        dialogTtileController.clear();
                        var request = await httpClient.putUrl(Uri.parse("${constants.protocol}${constants.server}/${constants.message}"));
                        request.headers.add("content-type", "application/json;charset=utf-8");
                        request.write(json.encode(msg));
                        var response = await request.close();
                        if (response.statusCode == 200) {
                          setState(() => messages.insert(0,msg));
                          scrollController.position.jumpTo(0);
                        } else {
                          this.showMessage(uiVariables['network_error']);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }else {
      return Scaffold(
        appBar: AppBar(
          title: Text(uiVariables['friends']),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              icon: InputDecorator(
                decoration: InputDecoration(icon: Icon(Icons.search)),
              ),
              onPressed: () {
                Navigator.pushNamed(context, "/search", arguments: {constants.id: id.text.trim(), constants.password: pw.text.trim(), constants.nickname: nickname.text.trim()});
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: getDrawer(),
        ),
        body: getBody(friends ??= [], notifications ??= []),
        bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_box), title: Text(uiVariables['friends'])),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active), title: Text(uiVariables['msg']),
            ),
          ],
          onTap: (index) => setState(() => currentRoute = index==0?UserRoute.friends:UserRoute.notifications),
          currentIndex: currentRoute==UserRoute.friends?0:1,
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    id.dispose();
    pw.dispose();
    nickname.dispose();
    if (this.socket != null) {
      socket.destroy();
    }
    httpClient.close(force: true);
    scrollController.dispose();
    dialogTtileController.dispose();
  }

  processMesssage(String msg) {
    Map map = json.decode(msg);
    switch (map[constants.type]) {
      case constants.friend:
        switch (map[constants.subtype]) {
          case constants.request:
            setState(() {
              notifications.removeWhere((e) => e[constants.id] == map[constants.id]);
              notifications.insert(0, map);
            });
            break;
          case constants.response:
            if (map.containsKey(constants.accept) && map[constants.accept]) {
              setState(() {
                friends.removeWhere((e) => e[constants.id] == map[constants.id]);
                friends.insert(0, {constants.id: map[constants.id], constants.nickname: map[constants.nickname]});
              });
            } else {
              this.showMessage("${map[constants.id]}${uiVariables['friend_add_refuse']}");
            }
            break;
          default:
            break;
        }
        break;
      case constants.message:
        if(currentRoute == UserRoute.dialog && friendId == map[constants.id]) {
          setState(() => messages.insert(0,map));
          scrollController.position.jumpTo(0);
        }
        break;
      default:
        break;
    }
  }

  getDrawer() {
    return Scaffold(
      body: ListView(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 100.0,
                height: 100.0,
                child: Image.asset("assets/images/flutter.png"),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.center,
          ),
          Text(
            nickname.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.0,
              fontFamily: "微软雅黑",
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload), title: Text(uiVariables['update'])),
          BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app), title: Text(uiVariables['quit']))
        ],
        onTap: (value) {
          if (value == 1) {
            Navigator.popUntil(context, ModalRoute.withName('/'));
          } else {
            setState(() {

            });
          }
        },
        currentIndex: 1,
      ),
    );
  }

  ListView getBody(List friends, List notifications) {
    List<Widget> list = [];

    for (int i = 0; i < (currentRoute == UserRoute.friends ? friends.length : notifications.length); i++) {
      var widget;
      if (currentRoute == UserRoute.friends) {
        String fid = friends[i][constants.id];
        String fnickname = friends[i][constants.nickname];

        var row = Row(
          children: <Widget>[
            Icon(Icons.account_box),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(fid + "($fnickname)"),
                    Text(uiVariables['no_msg'])
                  ],
                ),
              ),
            ),
          ],
        );

        var container = Container(
          padding: EdgeInsets.all(10.0),
          child: row,
        );

        widget = GestureDetector(
          onTap: () async {
            setState(() {
              messages.clear();
              currentRoute = UserRoute.dialog;
              friendId = fid;
              friendNickname = fnickname;
              messageDate = "";
            });

            var msg = {
              constants.type: constants.message,
              constants.subtype: constants.history,
              constants.id: this.id.text.trim(),
              constants.password: this.pw.text.trim(),
              constants.friend: fid,
              constants.version: constants.currentVersion
            };

            var request = await httpClient.putUrl(Uri.parse("${constants.protocol}${constants.server}/"));
            request.headers.add("content-type", "application/json;charset=utf-8");
            request.write(json.encode(msg));
            var response = await request.close();
            if (response.statusCode == 200) {
              var string = await response.transform(utf8.decoder).join();
              var result = json.decode(string);
              if(currentRoute == UserRoute.dialog && result[constants.friend] == friendId){
                setState(() => messages.addAll((result[constants.history] as List).reversed));
                scrollController.position.animateTo(0, duration: Duration(seconds: 3), curve: Curves.decelerate);
                messageDate = result[constants.date];
              }
            } else {
              this.showMessage(uiVariables['system_error']);
            }
          },
          child: container,
        );
      } else {
        var upperRow = Row(
          children: <Widget>[
            Icon(Icons.notifications_active),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(notifications[i][constants.id]),
                    Text(notifications[i][constants.message])
                  ],
                ),
              ),
            )
          ],
        );

        void _pressed(bool accept) async {
          //define a function, used below
          var id = notifications[i][constants.id];
          var nickname = notifications[i][constants.nickname];
          var msg = {
            constants.type: constants.friend,
            constants.subtype: constants.response,
            constants.id: this.id.text.trim(),
            constants.password: this.pw.text.trim(),
            constants.nickname: this.nickname.text.trim(),
            constants.to: id,
            constants.accept: accept,
            constants.version: constants.currentVersion
          };

          var request = await httpClient.putUrl(Uri.parse("${constants.protocol}${constants.server}/"));
          request.headers.add("content-type", "application/json;charset=utf-8");
          request.write(json.encode(msg));
          var response = await request.close();
          if (response.statusCode == 200) {
            if (accept) {
              friends.removeWhere((e) => e[constants.id] == id);
              friends.insert(0, {constants.id: id, constants.nickname: nickname});
            }
            setState(() {
              notifications.removeWhere((e) => e[constants.id] == id);
            });
          } else {
            this.showMessage(uiVariables['system_error']);
          }
        }

        var lowerRow = Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            RaisedButton(
              padding: EdgeInsets.all(10.0),
              onPressed: () => _pressed(true),
              child: Text(uiVariables['accept']),
            ),
            RaisedButton(
              padding: EdgeInsets.all(10.0),
              onPressed: () => _pressed(false),
              child: Text(uiVariables['refuse']),
            ),
          ],
        );

        var col = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[upperRow, lowerRow]);

        widget = Container(
          padding: EdgeInsets.all(10.0),
          child: col,
        );
      }

      list.add(widget);
    }

//    var col = Column(
//      crossAxisAlignment: CrossAxisAlignment.stretch,
//      children: list,
//    );

    return ListView.builder(
      padding: EdgeInsets.all(10.0),
      itemBuilder: (BuildContext context, int index) => list[index],
      itemCount: list.length,
    );
  }

  void showMessage(String message) {
    //显示系统消息
    showDialog(
      context: context,
      builder: (BuildContext context) =>
        SimpleDialog(
//              title: Text("消息"),
          children: <Widget>[
            Center(
              child: Text(message),
            )
          ],
        ));
  }
}