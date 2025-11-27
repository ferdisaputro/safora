import 'package:nominatim_flutter/model/response/status_response.dart' show Status;
import 'package:nominatim_flutter/model/response/status_response.dart';
import 'package:nominatim_flutter/nominatim_flutter.dart';
import 'package:nominatim_flutter/model/request/search_request.dart';
import 'package:nominatim_flutter/model/request/reverse_request.dart';
import 'package:nominatim_flutter/model/request/lookup_request.dart';
import 'package:nominatim_flutter/model/response/nominatim_response.dart';

class NominatimService {
  /// 🔧 Konfigurasi awal Nominatim — panggil di main() atau initState()
  static Future<void> configure() async {
    NominatimFlutter.instance.configureNominatim(
      useCacheInterceptor: true,
      maxStale: const Duration(days: 7),
      baseUrl: 'https://nominatim.openstreetmap.org', // default server
      userAgent: 'SaforaApp/1.0',
      enableCurlLog: false,
      printOnSuccess: false,
      convertFormData: true,
    );
  }

  /// 🔍 Pencarian lokasi berdasarkan teks
  static Future<List<NominatimResponse>> searchLocation(String query) async {
    if (query.isEmpty) return [];

    final searchRequest = SearchRequest(
      query: query,
      limit: 5,
      addressDetails: true,
      extraTags: true,
      nameDetails: true,
    );

    final results = await NominatimFlutter.instance.search(
      searchRequest: searchRequest,
      language: 'id,en;q=0.5',
    );

    return results;
  }

  /// 📍 Reverse geocoding — dari koordinat ke nama tempat
  static Future<NominatimResponse?> reverseGeocode(double lat, double lon) async {
    final reverseRequest = ReverseRequest(
      lat: lat,
      lon: lon,
      addressDetails: true,
      extraTags: true,
      nameDetails: true,
    );

    final result = await NominatimFlutter.instance.reverse(
      reverseRequest: reverseRequest,
      language: 'id,en;q=0.5',
    );

    return result;
  }

  /// 🧭 Cek status server
  static Future<bool> checkServerStatus() async {
    final status = await NominatimFlutter.instance.status();
    return status.status == Status.ok;
  }

  /// 🔎 Lookup detail tempat berdasarkan OSM ID
  static Future<List<NominatimResponse>> lookupById(String osmIds) async {
    final lookupRequest = LookupRequest(
      osmIds: osmIds,
      addressDetails: true,
      extraTags: true,
      nameDetails: true,
    );

    final result = await NominatimFlutter.instance.lookup(
      lookupRequest: lookupRequest,
      language: 'id,en;q=0.5',
    );

    return result;
  }
}
