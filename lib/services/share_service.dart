import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models.dart';
import 'excel_export.dart';
import 'storage.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Génère le fichier Excel de l'entraînement et ouvre la messagerie
/// (destinataire = email des paramètres). À défaut de messagerie,
/// ouvre le menu de partage Android. Renvoie un message pour l'utilisateur.
Future<String> sendTrainingByEmail(Training t, String email) async {
  final bytes = await compute(buildTrainingExcelFromJson, t.toJson());
  final name = excelFileName(t);
  final subject = emailSubject(t);
  final body = emailBody(t);

  if (kIsWeb) {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: _xlsxMime)],
      fileNameOverrides: [name],
      subject: subject,
      text: body,
    ));
    return 'Fichier $name généré';
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);

  String result;
  try {
    await FlutterEmailSender.send(Email(
      subject: subject,
      body: body,
      recipients: email.trim().isEmpty ? [] : [email.trim()],
      attachmentPaths: [file.path],
    ));
    result = 'Messagerie ouverte avec $name';
  } catch (e) {
    debugPrint('Envoi email impossible ($e), partage à la place');
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: _xlsxMime)],
      subject: subject,
      text: body,
    ));
    result = 'Partage ouvert avec $name';
  }
  t.sentAt = DateTime.now();
  await TrainingStore.instance.save(t);
  return result;
}
