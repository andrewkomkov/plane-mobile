import 'dart:io';

import 'package:dio/dio.dart';

import '../config/api_client.dart';
import '../models/attachment.dart';

/// Uploads issue attachments.
///
/// Plane does not take the file itself. It hands out a presigned POST to its
/// object store and records a row marked `is_uploaded: false`, and the row only
/// counts once the client says the bytes landed. So an upload is three calls,
/// and the middle one does not go to the Plane API at all:
///
///   1. POST the metadata → presigned `url` + `fields`, plus an `asset_id`
///   2. POST the fields *and* the file to that url, as multipart
///   3. PATCH the asset to mark it uploaded
///
/// Skipping step 3 leaves an attachment the UI will never show, so a failure
/// after step 1 deletes the row rather than leaving one behind.
class AttachmentService {
  static Future<List<Attachment>> getAttachments(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response =
        await dio.get(_collection(workspaceSlug, projectId, issueId));
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    if (list is List) {
      return list.map((e) => Attachment.fromJson(e)).toList();
    }
    return [];
  }

  static Future<Attachment> upload(
    String workspaceSlug,
    String projectId,
    String issueId, {
    required File file,
    required String name,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final dio = await ApiClient.getInstance();
    final size = await file.length();

    final created = await dio.post(
      _collection(workspaceSlug, projectId, issueId),
      data: {'name': name, 'size': size, 'type': mimeType},
    );

    final body = created.data as Map<String, dynamic>;
    final assetId = body['asset_id'] as String;
    final uploadData = body['upload_data'] as Map<String, dynamic>;
    final uploadUrl = uploadData['url'] as String;
    final fields = (uploadData['fields'] as Map).cast<String, dynamic>();

    try {
      // The presigned policy pins the exact byte count and content type, so
      // the fields go up verbatim and `file` goes last — S3-style POST
      // policies require the file to be the final part.
      final form = FormData();
      fields.forEach((key, value) {
        form.fields.add(MapEntry(key, value.toString()));
      });
      form.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(file.path, filename: name),
      ));

      // A bare Dio: the storage endpoint is not the Plane API and must not
      // receive the API key or the session cookie.
      await Dio().post(
        uploadUrl,
        data: form,
        onSendProgress: onProgress,
        options: Options(
          // The store answers 204 with an empty body.
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      await dio.patch(_asset(workspaceSlug, projectId, issueId, assetId));
    } catch (_) {
      // Step 1 already created the row. Leaving it would show up in nobody's
      // list and count against nothing, so take it back out.
      try {
        await dio.delete(_asset(workspaceSlug, projectId, issueId, assetId));
      } catch (_) {}
      rethrow;
    }

    return Attachment.fromJson(body['attachment'] as Map<String, dynamic>);
  }

  static Future<void> delete(
    String workspaceSlug,
    String projectId,
    String issueId,
    String attachmentId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(_asset(workspaceSlug, projectId, issueId, attachmentId));
  }

  static String _collection(String ws, String pid, String iid) =>
      '/workspaces/$ws/projects/$pid/issues/$iid/issue-attachments/';

  static String _asset(String ws, String pid, String iid, String assetId) =>
      '${_collection(ws, pid, iid)}$assetId/';
}
