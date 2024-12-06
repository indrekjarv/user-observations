import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Map<String, dynamic>> locations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    print('Initializing app...');
    fetchData();
  }

  Future<void> fetchData() async {
    final response = await http.get(Uri.parse(
        'https://publicapi.envir.ee/v1/userObservations/combinedQuery?hours=100&account_id=all&phenomenons=all'));

    if (response.statusCode == 200) {
      final document = XmlDocument.parse(response.body);
      // Remove namespace to simplify parsing
      final entries = document.findAllElements('entry', namespace: '*');

      setState(() {
        locations = entries.map((entry) {
          final location = entry.findElements('location', namespace: '*').single.text;
          if (location.isEmpty) return null;

          try {
            final coordinates = location
                .replaceAll('(', '')
                .replaceAll(')', '')
                .split(',')
                .map((s) => double.parse(s.trim()))
                .toList();

            final paramName = entry.findElements('param_name', namespace: '*').single.text;
            final valueMeaning = entry.findElements('value_meaning', namespace: '*').single.text;
            final label = valueMeaning.isNotEmpty ? valueMeaning : paramName;

            print('Parsed location: $label at (${coordinates[0]}, ${coordinates[1]})');
            return {"name": label, "lat": coordinates[0], "lon": coordinates[1]};
          } catch (e) {
            print('Error parsing entry: $e');
            return null;
          }
        })
            .where((location) => location != null)
            .cast<Map<String, dynamic>>()
            .toList();

        print('Processed ${locations.length} valid locations');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = locations.map((location) => Marker(
      point: LatLng(location['lat'], location['lon']),
      width: 80,
      height: 80,
      child: Column(
        children: [
          const Icon(Icons.location_pin, color: Colors.red, size: 30),
          Container(
            padding: const EdgeInsets.all(4),
            color: Colors.white.withOpacity(0.8),
            child: Text(location['name']),
          ),
        ],
      ),
    )).toList();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Estonian Weather Observations"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                fetchData();
              },
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(58.7, 25.0),
            initialZoom: 8.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
              'https://tiles.envir.ee/tm/tms/1.0.0/ilmateenistus-aluskaart@GMC/{z}/{x}/{y}.jpeg',
              tms: true,
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}