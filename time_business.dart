import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../../../common/db/sqldb.dart';
import '../../../common/encryptor/aes_encryptor.dart';
import '../../../common/encryptor/rsa_encryptor.dart';
import '../../../common/utils/preferences.dart';
import '../../../common/utils/util.dart';

class TimeBusinessService {
  Future getTimeBusiness() async {
    Uri url = getURL('load_tiempo_negocio');

    final headers = <String, String>{
      HttpHeaders.authorizationHeader: Preferences.token,
      HttpHeaders.contentTypeHeader: 'application/json',
    };

    AesEncryptor aesEncryptor = AesEncryptor();
    aesEncryptor.generateKey();

    Map data = {
      'user': Preferences.username,
    };

    String aesEncryptedData = aesEncryptor.encrypt(data: jsonEncode(data));

    RsaEncryptor rsaEncryptor = RsaEncryptor();

    var rsaEncryptedAesKey =
        await rsaEncryptor.encrypt(data: aesEncryptor.key.toString());
    var rsaEncryptedIv =
        await rsaEncryptor.encrypt(data: aesEncryptor.iv.toString());

    final body = jsonEncode(<String, String>{
      'rsaEncryptedAesKey': rsaEncryptedAesKey,
      'rsaEncryptedIv': rsaEncryptedIv,
      'aesEncryptedData': aesEncryptedData,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      final responseJson = json.decode(response.body);
      final encryptedResponse = responseJson['data'];
      final decryptedResponse = aesEncryptor.decrypt(data: encryptedResponse);
      final decryptedResponseJson = json.decode(decryptedResponse);

      if (response.statusCode == 200) {
        debugPrint("Descargando Tiempo de Negocio...");
        await SqlDb().deleteData("DELETE FROM TiempoNegocio");
        String date = DateTime.now().toString();
        for (var item in decryptedResponseJson) {
          String id = item['ID'].toString();
          var sql =
              ("INSERT INTO TiempoNegocio (idTiempoNegocio,tiempoNegocio,fechaSync) VALUES ('$id','${item['TIEMPONEGOCIO'].toString().replaceAll("'", "")}','$date')");
          await SqlDb().insertData(sql);
        }
      } else {
        debugPrint("Error: TimeBusinessService -> ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error: TimeBusinessService -> $e");
    }
  }
}
