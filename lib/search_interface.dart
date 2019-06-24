import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'config/ui_variables.dart';
import 'package:social_vertex_flutter/config/ui_variables.dart';

import 'config/constants.dart' as constants;

class SearchInterface extends StatefulWidget {
  @override
  SearchInterfaceState createState() => SearchInterfaceState();
}

class SearchInterfaceState extends State<SearchInterface> {

  var id = TextEditingController();
  var pw = TextEditingController();
  var nickname = "";
  var keyword = TextEditingController();
  var httpClient = HttpClient();
  var friendId, friendNickname;

  @override
  Widget build(BuildContext context) {
    final Map arguments = ModalRoute.of(context).settings.arguments;
    id.text = arguments[constants.id];
    pw.text = arguments[constants.password];
    nickname = arguments[constants.nickname];

    List<Widget> itemList = [];

    if (friendId != null && friendNickname != null) {
      itemList.add(buildUserItem(context, friendId, friendNickname));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(uiVariables["search"]),
        centerTitle: true,
        leading: IconButton(
          icon: InputDecorator(
            decoration: InputDecoration(
              icon: Icon(Icons.arrow_back),
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[ //itemList
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(controller: keyword),
                  flex: 8,
                ),
                Expanded(
                  child: RaisedButton(
                    onPressed: () async {
                      var message = {
                        constants.type: constants.search,
                        constants.keyword: keyword.text.trim(),
                        constants.version: constants.currentVersion
                      };
                      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
                      var request = await httpClient.putUrl(Uri.parse("${constants.protocol}${constants.server}/"));
                      request.headers.add("content-type", "application/json;charset=utf-8");
                      request.write(json.encode(message));
                      var response = await request.close();
                      if (response.statusCode == 200) {
                        response.transform(utf8.decoder).listen((data) {
                          Map result = json.decode(data);
//                          print(result);
                          if (result.containsKey(constants.user)) {
                            setState(() {
                              this.friendId = result[constants.user][constants.id];
                              this.friendNickname = result[constants.user][constants.nickname];
                            });
                          }
                        });
                      } else {
                        this.showMessage(uiVariables["system_error"]);
                      }
                    },
                    child: Text(uiVariables["search"]),
                  ),
                  flex: 2,
                )
              ],
            ),
          ),
          ...itemList,
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    id.dispose();
    pw.dispose();
    httpClient.close(force: true);
    keyword.dispose();
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

  Widget buildUserItem(BuildContext context, String friendId, String friendNickname) {
    return Container(
//      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Icon(Icons.account_box),
                  ],
                ),
                Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(left: 5.00),
                      child: Text(
                        "$friendId($friendNickname)",
                        overflow: TextOverflow.ellipsis,
                      )),
                  ],
                ),
              ],
            ),
            flex: 8,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: InputDecorator(
                  decoration: InputDecoration(icon: Icon(Icons.add)),
                ),
                onPressed: () async {

                  var message = {
                    constants.type: constants.friend,
                    constants.subtype: constants.request,
                    constants.id: this.id.text.trim(),
                    constants.password: this.pw.text.trim(),
                    constants.nickname: this.nickname,
                    constants.to: friendId,
                    constants.message: "${uiVariables['friend_add']} ${this.id.text.trim()}",
                    constants.version: constants.currentVersion
                  };
                  httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
                  var request = await httpClient.putUrl(Uri.parse("${constants.protocol}${constants.server}/"));
                  request.headers.add("content-type", "application/json;charset=utf-8");
                  request.write(json.encode(message));
                  var response = await request.close();
                  if (response.statusCode == 200) {
                    this.showMessage(uiVariables["sent"]);
                    setState(() {
                      this.friendId = null;
                      this.friendNickname = null;
                    });
                  } else {
                    this.showMessage(uiVariables["system_error"]);
                  }
                },
              ),
            ),
            flex: 2,
          ),
        ],
      ),)
    ;
  }
}

