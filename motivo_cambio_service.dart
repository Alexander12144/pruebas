import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:impulsa/common/db/sqldb.dart';
import 'package:http/http.dart' as http;

import '../../../common/encryptor/aes_encryptor.dart';
import '../../../common/encryptor/rsa_encryptor.dart';
import '../../../common/utils/date_utils.dart';
import '../../../common/utils/preferences.dart';
import '../../../common/utils/respuesta.dart';
import '../../../common/utils/util.dart';
import '../../../lsubmodule/data/option.dart';

class MotivoCambioService {
  Future getMotivoCambio() async {
    Uri url = getURL('load_motivoCambioCasaReunion');

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

      MotivoCambioDAO dao = MotivoCambioDAO();
      if (response.statusCode == 200) {
        debugPrint("Descargando Motivos Cambios...");
        await dao.eliminarTablaMotivoDao();
        String date = getDateTimeSync();
        for (var item in decryptedResponseJson) {
          int id = int.tryParse(item['idMotivoCambioCasaReunion'].toString()) ?? 0 ;
          String motivo = item['motivoCambioCasaReunion'].toString().replaceAll("'", "");
          await dao.insertarMotivoCambioDao(motivo: MotivoModel(idMotivo: id, motivo: motivo, fechaSync: date));
        }
      } else {
        debugPrint("Error: MotivoCambioService -> ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error: MotivoCambioService -> $e");
    }
  }
}

class MotivoCambioDAO {
  Future<Respuesta> insertarMotivoCambioDao({required MotivoModel motivo}) async {
    Respuesta respuesta = Respuesta();
    int response = 0;
    try {

      String query =
      """
      INSERT INTO MotivosCambios
      (idMotivo,motivo,fechaSync)
      VALUES
      (${motivo.idMotivo},'${motivo.motivo}','${motivo.fechaSync}')
      """;

      response = await SqlDb().insertData(query);

    } catch (e) {
      respuesta.exito = false;
      respuesta.mensaje = e.toString();
    } finally {
      if(response > 0){
        respuesta.exito = true;
        respuesta.mensaje = "OK";
      }
    }

    return respuesta;
  }

  Future<Respuesta> eliminarTablaMotivoDao() async {
    Respuesta respuesta = Respuesta();
    int response = 0;
    try {
      String query = """
      DELETE FROM MotivosCambios
      """;
      response = await SqlDb().deleteData(query);
    } catch (e) {
      respuesta.exito = false;
      respuesta.mensaje = e.toString();
    }finally {
      if(response > 0){
        respuesta.exito = true;
        respuesta.mensaje = "OK";
      }
    }

    return respuesta;

  }

  Future<Respuesta<Option>> obtenerMotivoCambioDao() async {
    Respuesta<Option> respuesta = Respuesta();
    List<Option> list = [];

    try {
      String query = "SELECT idMotivo,motivo FROM MotivosCambios";
      var response =  await SqlDb().readData(query);

      for(var r in response){
        list.add(Option(id: r['idMotivo'] ,value: r['motivo']));
      }
    } catch (e) {
      respuesta.exito = false;
      respuesta.mensaje = e.toString();
    } finally {
      if(list.isNotEmpty){
        respuesta.exito = true;
        respuesta.mensaje = "OK";
        respuesta.datos = list;
      }
    }

    return respuesta;

  }
}

class MotivoModel {
  int idMotivo;
  String motivo;
  String fechaSync;

  MotivoModel({
    required this.idMotivo,
    required this.motivo,
    required this.fechaSync,
  });

}
