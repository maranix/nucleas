import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:valence/valence.dart';

const baseURL = "dummyjson.com";

final queries = <String>[
  "phone",
  "mobile",
  "watch",
  "car",
  "table",
  "",
  "bottle",
];

final client = http.Client();

Future<int> _searchProducts(String query) async {
  final url = Uri.https(baseURL, "/products/search", {"q": query});
  final res = await client.get(url);

  if (res.statusCode != HttpStatus.ok) {
    throw Exception("Blud this broke with ${res.statusCode}");
  }

  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return json["total"];
}

void main() async {
  final searchQuery = store("", filter: (q) => q.isNotEmpty);

  final searchResource = resource(() {
    final q = searchQuery();
    return _searchProducts(q);
  });

  reactor(() {
    // Reading both the Resource and the Store in the same Observer
    final currentQuery = searchQuery();
    if (currentQuery.isEmpty) return;

    final searchState = searchResource();

    final message = switch (searchState) {
      ResourceLoading(:final data) =>
        data != null
            ? "Searching for '$currentQuery' (Keeping stale data: $data)..."
            : "Searching for '$currentQuery'...",
      ResourceLoaded(:final data) => "Got $data results for '$currentQuery'",
      ResourceError(:final error) =>
        "Failed to get results for '$currentQuery': $error",
    };

    print(message);
  });

  final stream = Stream.periodic(.new(seconds: 3), (_) {
    if (queries.isEmpty) return;

    searchQuery.dispatch(.run(handler: (_) => queries.removeLast()));
  });

  await stream.forEach((_) {});

  client.close();
}
