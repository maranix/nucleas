import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:valence/valence.dart';

const baseURL = "dummyjson.com";

final queries = <String>["phone", "mobile", "watch", "car", "table", "bottle"];

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
  final searchResult = store(0);

  final searchResource = resource(() {
    final q = searchQuery();
    if (q.isEmpty) return Future.value(0);

    return _searchProducts(q);
  }, filter: (c) => c > 0);

  searchResource.trigger(
    store: searchResult,
    then: (count) => Action<int>.run(handler: (_) => count),
  );

  reactor(() {
    final query = searchQuery();
    final loading = searchResource().isLoading;

    if (!loading || query.isEmpty) return;

    print("⏳ Waiting for results for $query...");
  });

  reactor(() {
    final count = searchResult();
    if (count == 0) return;

    print("Got $count Results");
  });

  reactor(() {
    final state = searchResource();
    if (state is ResourceError) {
      print("ERROR: \${(state as ResourceError).error}");
    }
  });

  final queue = Completer<void>();
  bool isFirstRun = true;

  reactor(() {
    final searchState = searchResource();

    if (searchState is ResourceLoading && !isFirstRun) return;

    if (queries.isNotEmpty) {
      final nextQuery = queries.removeLast();

      scheduleMicrotask(() {
        searchQuery.dispatch(.run(handler: (_) => nextQuery));
      });

      isFirstRun = false;
    } else {
      if (!queue.isCompleted) {
        queue.complete();
      }
    }
  });

  await queue.future;

  client.close();
}
