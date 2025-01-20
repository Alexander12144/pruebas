import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../../../common/db/sqldb.dart';
import '../../../common/encryptor/aes_encryptor.dart';
import '../../../common/encryptor/rsa_encryptor.dart';
import '../../../common/utils/preferences.dart';
import '../../../common/utils/util.dart';

class ModalityRateService {
  Future getModalityRate() async {
    Uri url = getURL('load_modalidades_tasa');

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
        debugPrint("Descargando Modalidad Tasa...");
        await SqlDb().deleteData("DELETE FROM ModalidadTasa");

        String date = DateTime.now().toString();
        for (var item in decryptedResponseJson) {
          var sql = ("""
          INSERT INTO ModalidadTasa 
          (
          idTasaRango,
          idModalidad,
          montoInicial,
          montoFinal,
          tasa,
          tasaMinima,
          tasaMaxima,
          tea,
          teaMinima,
          teaMaxima,
          tcem,
          tcea,
          fechaSync
          ) 
          VALUES 
          (
          ${int.parse(item['IDTASARANGO'].toString())},
          ${int.parse((item['IDMODALIDAD'] ?? 0).toString())},
          ${double.parse(item['MONTOINICIAL'].toString())},
          ${double.parse(item['MONTOFINAL'].toString())},
          ${double.parse(item['TASA'].toString())},
          ${double.parse(item['TASAMINIMA'].toString())},
          ${double.parse(item['TASAMAXIMA'].toString())},
          ${double.parse(item['TEA'].toString())},
          ${double.parse(item['TEAMINIMA'].toString())},
          ${double.parse(item['TEAMAXIMA'].toString())},
          ${double.parse(item['TCEM'].toString())},
          ${double.parse(item['TCEA'].toString())},
          '$date'
          )
              """);
          await SqlDb().insertData(sql);
        }
      } else {
        debugPrint("Error: ModalityRateService");
      }
    } catch (e) {
      debugPrint("Error: ModalityRateService -> $e");
    }
  }
}
