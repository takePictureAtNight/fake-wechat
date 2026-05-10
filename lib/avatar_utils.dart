import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_client.dart';

class AvatarUtils {
  AvatarUtils._();

  static Future<String?> pickAvatarDataUrl() async {
    final granted = await _ensurePhotoPermission();
    if (!granted) {
      throw Exception('相册权限被拒绝，请在系统设置中允许访问照片');
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 720,
      maxHeight: 720,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mime = _mimeByFileName(file.name);
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static Future<File?> pickAvatarFile() async {
    final granted = await _ensurePhotoPermission();
    if (!granted) {
      throw Exception('相册权限被拒绝，请在系统设置中允许访问照片');
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 720,
      maxHeight: 720,
    );
    if (file == null) return null;
    return File(file.path);
  }

  static Future<bool> _ensurePhotoPermission() async {
    if (Platform.isIOS) {
      final s = await Permission.photos.status;
      if (s.isGranted || s.isLimited) return true;
      final r = await Permission.photos.request();
      return r.isGranted || r.isLimited;
    }
    final s = await Permission.photos.status;
    if (s.isGranted) return true;
    final r = await Permission.photos.request();
    return r.isGranted;
  }

  static ImageProvider? providerFromUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final v = url.trim();
    if (v.startsWith('data:image/')) {
      final idx = v.indexOf('base64,');
      if (idx <= 0) return null;
      try {
        final raw = v.substring(idx + 7);
        final bytes = base64Decode(raw);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return NetworkImage(v);
    }
    if (v.startsWith('/')) {
      return NetworkImage('${ApiClient.instance.baseUrl}$v');
    }
    return null;
  }

  static Uint8List? bytesFromDataUrl(String? url) {
    if (url == null || !url.startsWith('data:image/')) return null;
    final idx = url.indexOf('base64,');
    if (idx <= 0) return null;
    try {
      return base64Decode(url.substring(idx + 7));
    } catch (_) {
      return null;
    }
  }

  static String _mimeByFileName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

