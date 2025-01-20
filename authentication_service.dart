import 'dart:async';
import 'dart:convert';
import 'dart:io';
//import 'dart:js';

import 'package:flutter/foundation.dart';
import 'package:impulsa/begin/api/services/photo_service.dart';
import 'package:impulsa/begin/api/services/profession_service.dart';
import 'package:impulsa/begin/api/services/province_service.dart';
import 'package:impulsa/begin/api/services/region_service.dart';
import 'package:impulsa/begin/api/services/relation_ship_service.dart';
import 'package:impulsa/begin/api/services/sector_service.dart';
import 'package:impulsa/begin/api/services/study_service.dart';
import 'package:impulsa/begin/api/services/time_business.dart';
import 'package:impulsa/begin/api/services/zone_service.dart';
import 'package:impulsa/begin/model/authenticated_user.dart';
import 'package:impulsa/common/encryptor/aes_encryptor.dart';
import 'package:impulsa/common/encryptor/rsa_encryptor.dart';
import 'package:impulsa/common/utils/preferences.dart';
import 'package:impulsa/common/utils/respuesta.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:platform_device_id_plus/platform_device_id.dart';

import '../../../common/db/sqldb.dart';
import '../../../common/utils/repositorio.dart';
import '../../../common/utils/text.dart';
import '../../../common/utils/util.dart';
import '../../model/ambito.dart';
import '../../model/objeto.dart';
import '../../model/perfil.dart';
import '../../model/usuario.dart';
import '../db/update_scope.dart';
import 'business_service.dart';
import 'charges_service.dart';
import 'civil_status_service.dart';
import 'department_service.dart';
import 'district_service.dart';
import 'living_service.dart';
import 'modality_rate_service.dart';
import 'motivo_cambio_service.dart';
import 'nucleus_family_service.dart';
import 'office_service.dart';

class AuthenticationService {
  Future<AuthenticatedUser> executeLogin(
      String username, String password) async {
    Uri url = getURL('execute_login');

    String imei = '';

    if (kIsWeb) {
      imei = "windows";
    } else {
      imei = await PlatformDeviceId.getDeviceId ?? '';
      imei = (Platform.isWindows) ? "windows" : imei;
    }

    debugPrint("IMEI: $imei");

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Preferences.appName = packageInfo.appName;
    Preferences.packageName = packageInfo.packageName;
    Preferences.version = packageInfo.version;
    Preferences.buildNumber = packageInfo.buildNumber;
    Preferences.imei = imei;

    final headers = <String, String>{
      HttpHeaders.authorizationHeader: token,
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.cacheControlHeader: 'no-cache',
    };

    AesEncryptor aesEncryptor = AesEncryptor();
    aesEncryptor.generateKey();

    Map<String, dynamic> data = {
      'user': username.toUpperCase(),
      'password': password.toUpperCase(),
      'imei': imei,
      'version': Preferences.version,
      // 'version': '0.2.3',
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

    AuthenticatedUser authenticatedUser = authenticatedUserDefault;

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        debugPrint("RESPONSE: ${response.statusCode}");

        final responseJson = json.decode(response.body);

        final encryptedResponse = responseJson['data'];
        final decryptedResponse = aesEncryptor.decrypt(data: encryptedResponse);
        final decryptedResponseJson = json.decode(decryptedResponse);

        authenticatedUser = AuthenticatedUser.fromJson(decryptedResponseJson);

        if (authenticatedUser.exito == 1) {
          if (Preferences.tablasMaestrasCargadas == false) {
            var response = await loadInformation();
            Preferences.tablasMaestrasCargadas = response.exito;
          }

          await SqlDb()
              .deleteData("DELETE FROM Perfiles WHERE usuario = '$username' ");
          await SqlDb()
              .deleteData("DELETE FROM Ambitos WHERE usuario = '$username' ");
          await SqlDb()
              .deleteData("DELETE FROM Objetos WHERE usuario = '$username' ");

          for (var item in json.decode(decryptedResponseJson['perfiles'])) {
            var sqlOb =
                ("INSERT INTO Perfiles (usuario,perfil,codigo,principal) VALUES ('${item['usuario']}','${item['perfil']}','${item['codPerfil']}',${item['principal']})");
            await SqlDb().insertData(sqlOb);

            if (item['principal'] == 1) {
              Preferences.profile = item['perfil'];
              Preferences.idProfile = int.parse(item['codPerfil']);
            }
          }

          for (var item in json.decode(decryptedResponseJson['ambitos'])) {
            var sqlOb =
                ("INSERT INTO Ambitos (usuario,ambito,codigo,descripcion) VALUES ('${item['usuario']}','${item['ambito']}',${item['codigo']},'${item['descripcion']}')");
            await SqlDb().insertData(sqlOb);

            updateScope(
              scope: item['ambito'] as String,
              scopeCode: item['codigo'] as int,
              prime: item['principal'] == 1 ? true : false,
            );

            debugPrint("AMBITO: $item");
          }

          for (var item in json.decode(decryptedResponseJson['objetos'])) {
            var sqlOb =
                ("INSERT INTO Objetos (usuario,perfil,idObjeto,objeto) VALUES ('${item['usuario']}','${item['perfil']}',${item['idObjeto']},'${item['objeto']}')");
            await SqlDb().insertData(sqlOb);
          }
        }
      }
      //return authenticatedUser;
    } on TimeoutException {
      String query = "SELECT clave FROM Usuario WHERE usuario= '$username'";
      List<Map> response = await SqlDb().readData(query);

      if (response.isNotEmpty) {
        if (response[0]['clave'] == password) {
          authenticatedUser = AuthenticatedUser(
              exito: 1,
              mensaje: "Inicio de sesión OffLine",
              token: '',
              nombre: Preferences.username,
              nombreCompleto: Preferences.fullName);
        }
      }

      // return authenticatedUser;
    } catch (e) {
      //Se quito el internet manualmente
      if (e.toString() == "Connection failed") {
        String query = "SELECT clave FROM Usuario WHERE usuario= '$username'";
        List<Map> response = await SqlDb().readData(query);

        if (response.isNotEmpty) {
          if (response[0]['clave'] == password) {
            authenticatedUser = AuthenticatedUser(
                exito: 1,
                mensaje: "Inicio de sesión OffLine",
                token: '',
                nombre: Preferences.username,
                nombreCompleto: Preferences.fullName);
          }
        }
      } else {
        debugPrint("Error: $e");
        authenticatedUser.mensaje = 'Ocurrió un error: ${e.toString()}';
      }
    }

    return authenticatedUser;
  }

  @Deprecated("No funcional, use [executeLogin]")
  Future<Respuesta<Usuario>> singIn(String username, String password) async {
    Preferences.imei = await PlatformDeviceId.getDeviceId ?? '';
    debugPrint('imei: ${Preferences.imei}');

    // get package info
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Preferences.version = packageInfo.version;

    Respuesta<Usuario> r = await Repositorio().remoto<Usuario>(
      endPoint: "/execute_login",
      timeoutSeconds: 10,
      jsonMap: {
        'user': username,
        'password': password,
        'imei': Platform.isAndroid ? Preferences.imei : "windows",
        'version': Preferences.version
      },
      mapper: (data) => Usuario.fromJson(data),
    );

    if (r.exito) {
      /* INICIO ONLINE */
      Usuario usuario = r.datos!.first;

      /* Usuario y contraseña */
      await SqlDb().deleteData("DELETE FROM Usuario");
      String sqlUs =
          ("INSERT INTO Usuario (usuario,clave,fecha) VALUES ('$username','$password', '${DateTime.now().toString()}')");
      await SqlDb().insertData(sqlUs);
      Preferences.token = usuario.token;
      Preferences.username = username;
      Preferences.psw = password;
      Preferences.name = usuario.nombre;
      Preferences.fullName = usuario.nombreCompleto;

      /* Carga de tablas maestras */
      if (Preferences.tablasMaestrasCargadas == false) {
        var response = await loadInformation();
        Preferences.tablasMaestrasCargadas = response.exito;
      }

      /* PERFILES */
      await SqlDb().deleteData("DELETE FROM Perfil");
      for (Perfil p in usuario.perfiles) {
        String sqlOb =
            ("INSERT INTO Perfil (idPerfil,nombrePerfil,principal) VALUES (${p.idPerfil},'${p.nombrePerfil}',${p.principal ? 1 : 0})");
        try {
          await SqlDb().insertData(sqlOb);
        } catch (e) {
          debugPrint("Error: $e");
        }
        debugPrint("Perfiles: ${p.toString()}");
        if (p.principal) {
          Preferences.idProfile = p.idPerfil;
        }
      }

      /// Al menos debe tener un perfil marcado como principal
      /// Si no tiene ninguno, se toma el primero
      if (Preferences.idProfile == 0) {
        Preferences.idProfile = usuario.perfiles.first.idPerfil;
      }

      /// Con el idPerfil se obtiene el nombre del perfil
      var row = await SqlDb().getFirst(
          "SELECT nombrePerfil FROM Perfil WHERE idPerfil = ${Preferences.idProfile}");
      Preferences.profile = row['nombrePerfil'];

      /* OBJETOS */
      await SqlDb().deleteData("DELETE FROM Objeto");
      for (Objeto o in usuario.objetos) {
        String sqlOb =
            ("INSERT INTO Objeto (idObjeto,nombreObjeto,nombrePerfil) VALUES (${o.idObjeto},'${o.nombreObjeto}','${o.nombrePerfil}')");
        try {
          await SqlDb().insertData(sqlOb);
        } catch (e) {
          debugPrint("Error: $e");
        }
        debugPrint("Objetos: ${o.toString()}");
      }

      /* AMBITOS */
      /// Ordenas ambitos en secuencia: ZONA, SECTOR, REGION, OFICINA
      usuario.ambitos
          .sort((a, b) => b.tipoAmbito[0].compareTo(a.tipoAmbito[0]));

      await SqlDb().deleteData("DELETE FROM Ambito");
      for (Ambito a in usuario.ambitos) {
        var sqlOb =
            ("INSERT INTO Ambito (tipoAmbito,idAmbito,nombreAmbito) VALUES ('${a.tipoAmbito}',${a.idAmbito},'${a.nombreAmbito}')");
        try {
          await SqlDb().insertData(sqlOb);
        } catch (e) {
          debugPrint("Error: $e");
        }
        debugPrint("Ambitos: ${a.toString()}");
        agregarAmbito(ambito: a);
      }

      /// Carga de tablas maestras
      if (Preferences.tablasMaestrasCargadas == false) {
        var response = await loadInformation();
        Preferences.tablasMaestrasCargadas = response.exito;
      }
    } else {
      // TODO: OFFLINE
      String query = "SELECT clave FROM Usuario WHERE usuario= '$username'";
      List<Map> response = await SqlDb().readData(query);

      if (response.isNotEmpty) {
        if (response[0]['clave'] == password) {
          r.exito = true;
          r.mensaje = "Inicio de sesión OffLine";
        }
      }
    }

    return r;
  }
}

Future<Respuesta> loadInformation() async {
  Respuesta r = Respuesta();
  try {
    //blockUIMsg(context: context, msj: msj);

    r = await ZoneService().getZones();
    await SectorService().getSector();
    await OfficeService().getOffices();
    await RegionService().getRegions();
    await CivilStatusService().getCivilStatus();
    await LivingService().getAllLiving();
    await StudyService().getAllStudy();
    await DepartmentService().getAllDepartment();
    await ProvinceService().getAllProvince();
    await DistrictService().getAllDistrict();
    await ProfessionService().getAllProfession();
    await RelationShipService().getAllRelationShip();
    await PhotoService().getPhoto();
    await FamilyService().getFamilyNucleus();
    await ChargesServices().getCharges();

    await BusinessService().getBusiness();
    await BusinessService().getCiiu();

    await TimeBusinessService().getTimeBusiness();
    await ModalityRateService().getModalityRate();
    await MotivoCambioService().getMotivoCambio();
    //await AgenciaService().getAgencias();
  } catch (e) {
    debugPrint("TABLAS MAESTRAS Error: $e");
    r.mensaje = "Error al cargar tablas maestras: $e";
    return r;
  }

  return r;
}
