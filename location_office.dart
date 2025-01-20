import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:impulsa/common/utils/preferences.dart';
import 'package:http/http.dart' as http;

import '../../../common/db/sqldb.dart';
import '../../../common/encryptor/aes_encryptor.dart';
import '../../../common/encryptor/rsa_encryptor.dart';
import '../../../common/utils/date_utils.dart';
import '../../../common/utils/respuesta.dart';
import '../../../common/utils/util.dart';

class AgenciaService {
  Future<Respuesta> getAgencias() async {
    Uri url = getURL('load_agencia');

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

    Respuesta r = Respuesta();

    try {
      final response = await http.post(url, headers: headers, body: body);

      final responseJson = json.decode(response.body);
      final encryptedResponse = responseJson['data'];
      final decryptedResponse = aesEncryptor.decrypt(data: encryptedResponse);
      final decryptedResponseJson = json.decode(decryptedResponse);

      if (response.statusCode == 200) {
        debugPrint("Descargando Agencias...");

        await SqlDb().deleteData("DELETE FROM Agencias");

        String date = getDateTimeSync();
        int insert = 0;
        for (var item in decryptedResponseJson) {
          var sql =
              ("INSERT INTO Agencias (idAgencia,agencia,latitude,longitude,radio,fechaSync) VALUES (${item['idAgencia']},'${item['agencia'].toString()}',${item['latitud']},${item['longitud']},,${item['radio']},'$date')");
          insert = await SqlDb().insertData(sql);
        }

        if (insert >= 1) {
          r.mensaje = 'OK';
          r.exito = true;
        }
      } else {
        r.mensaje = "AgenciaService: ${response.statusCode}";
        debugPrint("AgenciaService: ${response.statusCode}");
      }
    } catch (e) {
      r.mensaje = "AgenciaService: $e";
      debugPrint("AgenciaService -> $e");
    }

    return r;
  }
}
