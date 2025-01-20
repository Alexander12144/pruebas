import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:impulsa/common/encryptor/aes_encryptor.dart';
import 'package:impulsa/common/encryptor/rsa_encryptor.dart';
import 'package:impulsa/common/utils/preferences.dart';
import 'package:impulsa/common/utils/text.dart';
import 'package:http/http.dart' as http;

import '../../../common/db/sqldb.dart';
import '../../../common/utils/date_utils.dart';
import '../../../common/utils/util.dart';

class SectorService {
  Future getSector() async {
    Uri url = getURL('load_sector');

    final headers = <String, String>{
      HttpHeaders.authorizationHeader: token,
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
        debugPrint("Descargando Sectores ...");
        await SqlDb().deleteData("DELETE FROM Sectores");
        String date = getDateTimeSync();
        for (var item in decryptedResponseJson) {
          var sql =
              ("INSERT INTO Sectores (idSector,sector,idOficina,ambito,fechaSync) VALUES (${item['IDSECTOR']},'${item['SECTOR'].toString()}',${item['IDOFICINA']},0,'$date')");
          await SqlDb().insertData(sql);
        }
      } else {
        debugPrint("Error:");
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}
