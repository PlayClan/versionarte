import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:versionarte/src/helpers/logger.dart';
import 'package:versionarte/src/models/versionarte_result.dart';
import 'package:versionarte/src/providers/versionarte_provider.dart';
import 'package:versionarte/versionarte.dart';

class Versionarte {
  static PackageInfo? _packageInfo;

  /// Retrieves package information from the platform.
  static Future<PackageInfo?> get packageInfo async {
    _packageInfo ??= await PackageInfo.fromPlatform();

    return _packageInfo;
  }

  static Future<VersionarteResult> check({
    required VersionarteProvider versionarteProvider,
    LocalVersioning? localVersioning,
  }) async {
    try {
      localVersioning ??= await LocalVersioning.fromPackageInfo();

      if (localVersioning == null) {
        return VersionarteResult(
          VersionarteStatus.failedToCheck,
          message:
              'A null `LocalVersioning` received. If you\'ve used `LocalVersioning.fromPackageInfo`, package_info plugin might have failed.',
        );
      }

      logV('Received LocalVersioning: $localVersioning');
      logV('Checking versionarte using ${versionarteProvider.runtimeType}');

      final serversideVersioning =
          await versionarteProvider.getVersioningDetails();

      if (serversideVersioning == null) {
        return VersionarteResult(
          VersionarteStatus.failedToCheck,
          message:
              'For some unknown reasons ServersideVersioning could not be fetched.',
        );
      }

      logV('Received ServersideVersioning: \n$serversideVersioning');

      final platformVersionarte = serversideVersioning.platformVersionarte;

      final available = platformVersionarte.availability.available;
      if (!available) {
        return VersionarteResult(
          VersionarteStatus.unavailable,
          details: platformVersionarte,
        );
      }

      final localPlatformVersion = localVersioning.platformVersion;
      if (localPlatformVersion == null) {
        return VersionarteResult(
          VersionarteStatus.failedToCheck,
          message:
              'LocalVersioning does not contain a version number for the platform $defaultTargetPlatform, make sure you\'ve specified version for it.',
        );
      }

      final serversideMinPlatformVersion = platformVersionarte.minimum.number;
      final mustUpdate = serversideMinPlatformVersion > localPlatformVersion;
      if (mustUpdate) {
        return VersionarteResult(
          VersionarteStatus.mustUpdate,
          details: platformVersionarte,
        );
      }

      final serversideLatestPlatformVersion = platformVersionarte.latest.number;
      final shouldUpdate =
          serversideLatestPlatformVersion > localPlatformVersion;

      if (shouldUpdate) {
        return VersionarteResult(
          VersionarteStatus.couldUpdate,
          details: platformVersionarte,
        );
      }

      return VersionarteResult(VersionarteStatus.upToDate);
    } on FormatException catch (e) {
      if (versionarteProvider is RemoteConfigVersionarteProvider) {
        return VersionarteResult(
          VersionarteStatus.failedToCheck,
          message:
              'Failed to parse json received from RemoteConfig. Check out the example json file at path /versionarte.json, and make sure that the one you\'ve uploaded to RemoteConfig matches the pattern. If you have uploaded it with a custom key name  make sure you specify as a `keyName`.',
        );
      } else if (versionarteProvider is RestfulVersionarteProvider) {
        return VersionarteResult(
          VersionarteStatus.failedToCheck,
          message:
              'Failed to parse json received from RESTful API endpoint. Check out the example json file at path /versionarte.json, and make sure that endpoint response body matches the pattern.',
        );
      } else {
        return VersionarteResult(
          VersionarteStatus.failedToCheck,
          message: e.toString(),
        );
      }
    } catch (e, s) {
      logV('Exception: $e');
      logV('Stack Trace: $s');

      return VersionarteResult(
        VersionarteStatus.failedToCheck,
        message: e.toString(),
      );
    }
  }

  /// Using `url_launcher`, opens App Store on iOS, Play Store on Android.
  ///
  /// App URL for Play Store is generated automatically by the help of the
  /// package info, so no need to specify `androidPackageName` manually.
  /// But, for the App Store you must specify your app ID as an `int`, meaning
  /// no need for "id" prefix.
  ///
  /// `androidPackageName`: Package name of the app (Android)
  ///
  /// `appleAppId`: App ID of the app on App Store (iOS)
  static Future<bool> openAppInStore({
    required int appleAppId,
    String? androidPackageName,
  }) async {
    if (Platform.isAndroid) {
      androidPackageName ??= (await packageInfo)?.packageName;

      if (androidPackageName != null) {
        return launchUrl(
          Uri.parse(
            'https://play.google.com/store/apps/details?id=$androidPackageName',
          ),
        );
      } else {
        return false;
      }
    } else if (Platform.isIOS) {
      return launchUrl(
        Uri.parse(
          'https://apps.apple.com/app/id$appleAppId',
        ),
      );
    } else {
      logV('${Platform.operatingSystem} is not supported.');

      return false;
    }
  }
}
