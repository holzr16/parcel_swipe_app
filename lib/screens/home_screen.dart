import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MapboxStaticImageTest(),
    );
  }
}

class MapboxStaticImageTest extends StatefulWidget {
  const MapboxStaticImageTest({super.key});

  @override
  MapboxStaticImageTestState createState() => MapboxStaticImageTestState();
}

class MapboxStaticImageTestState extends State<MapboxStaticImageTest> {
  ImageProvider? _imageProvider;
  String? _error;
  String? _requestLength;

  static const String mapboxApiKey = 'pk.eyJ1IjoicGFyY2VsLXN3aXBlIiwiYSI6ImNseDY0azB5YjFvOWsya3FzZ3E1ZDNqcm0ifQ.NW_3JLES9EHW89e-R6rSrg';

  @override
  void initState() {
    super.initState();
    _loadImage();
    
  }

  Future<void> _loadImage() async {
    print('Loading image...');
  try {
    final urlAndLength = generateMapboxStaticImageUrl();
    final requestUrl = urlAndLength.key;
    final urlLength = urlAndLength.value;
    print('Full URL: $requestUrl');
    print('URL Length: $urlLength');
    // print('URL Preview: ${requestUrl.substring(0, 1000)}...');
    setState(() {
      _requestLength = 'Request length: $urlLength characters';
    });

    if (urlLength > 8192) {
      throw Exception('Geometry is too complex to display. Request length: $urlLength');
    }

    final imageProvider = await fetchMapboxStaticImage(requestUrl);
    setState(() {
      _imageProvider = imageProvider;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
    });
  }
}


  MapEntry<String, int> generateMapboxStaticImageUrl() {
    const geoJson = '''
    {
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [
              -5.681675,
              50.143649
            ],
            [
              -5.681672,
              50.143635
            ],
            [
              -5.681605,
              50.143611
            ],
            [
              -5.681560,
              50.143597
            ],
            [
              -5.681558,
              50.143596
            ],
            [
              -5.681489,
              50.143572
            ],
            [
              -5.681412,
              50.143548
            ],
            [
              -5.681369,
              50.143541
            ],
            [
              -5.681282,
              50.143524
            ],
            [
              -5.681177,
              50.143503
            ],
            [
              -5.681029,
              50.143476
            ],
            [
              -5.680918,
              50.143460
            ],
            [
              -5.680558,
              50.143407
            ],
            [
              -5.680520,
              50.143432
            ],
            [
              -5.680454,
              50.143495
            ],
            [
              -5.680418,
              50.143531
            ],
            [
              -5.680330,
              50.143619
            ],
            [
              -5.680282,
              50.143673
            ],
            [
              -5.680233,
              50.143723
            ],
            [
              -5.680190,
              50.143736
            ],
            [
              -5.680159,
              50.143766
            ],
            [
              -5.680109,
              50.143821
            ],
            [
              -5.680090,
              50.143837
            ],
            [
              -5.679999,
              50.143927
            ],
            [
              -5.679952,
              50.143981
            ],
            [
              -5.679913,
              50.144026
            ],
            [
              -5.679884,
              50.144062
            ],
            [
              -5.679740,
              50.143990
            ],
            [
              -5.679648,
              50.143959
            ],
            [
              -5.679645,
              50.143958
            ],
            [
              -5.679564,
              50.143937
            ],
            [
              -5.679493,
              50.143922
            ],
            [
              -5.679380,
              50.143902
            ],
            [
              -5.679376,
              50.143902
            ],
            [
              -5.679309,
              50.143896
            ],
            [
              -5.679252,
              50.143893
            ],
            [
              -5.679175,
              50.143887
            ],
            [
              -5.679108,
              50.143884
            ],
            [
              -5.679082,
              50.143883
            ],
            [
              -5.679040,
              50.144096
            ],
            [
              -5.679054,
              50.144114
            ],
            [
              -5.679091,
              50.144119
            ],
            [
              -5.679160,
              50.144131
            ],
            [
              -5.679216,
              50.144138
            ],
            [
              -5.679255,
              50.144145
            ],
            [
              -5.679322,
              50.144158
            ],
            [
              -5.679388,
              50.144179
            ],
            [
              -5.679434,
              50.144195
            ],
            [
              -5.679436,
              50.144195
            ],
            [
              -5.679440,
              50.144197
            ],
            [
              -5.679508,
              50.144223
            ],
            [
              -5.679565,
              50.144247
            ],
            [
              -5.679596,
              50.144260
            ],
            [
              -5.679632,
              50.144274
            ],
            [
              -5.679658,
              50.144286
            ],
            [
              -5.679692,
              50.144303
            ],
            [
              -5.679728,
              50.144318
            ],
            [
              -5.679748,
              50.144324
            ],
            [
              -5.679790,
              50.144340
            ],
            [
              -5.679827,
              50.144379
            ],
            [
              -5.679899,
              50.144432
            ],
            [
              -5.679954,
              50.144467
            ],
            [
              -5.680010,
              50.144507
            ],
            [
              -5.680011,
              50.144508
            ],
            [
              -5.680065,
              50.144552
            ],
            [
              -5.680106,
              50.144573
            ],
            [
              -5.680135,
              50.144591
            ],
            [
              -5.680154,
              50.144601
            ],
            [
              -5.680180,
              50.144607
            ],
            [
              -5.680213,
              50.144612
            ],
            [
              -5.680287,
              50.144618
            ],
            [
              -5.680367,
              50.144627
            ],
            [
              -5.680369,
              50.144628
            ],
            [
              -5.680446,
              50.144633
            ],
            [
              -5.680521,
              50.144641
            ],
            [
              -5.680575,
              50.144647
            ],
            [
              -5.680627,
              50.144655
            ],
            [
              -5.680667,
              50.144662
            ],
            [
              -5.680697,
              50.144677
            ],
            [
              -5.680716,
              50.144684
            ],
            [
              -5.680741,
              50.144692
            ],
            [
              -5.680769,
              50.144704
            ],
            [
              -5.680835,
              50.144737
            ],
            [
              -5.680877,
              50.144755
            ],
            [
              -5.680934,
              50.144782
            ],
            [
              -5.680974,
              50.144803
            ],
            [
              -5.681010,
              50.144818
            ],
            [
              -5.681029,
              50.144825
            ],
            [
              -5.681062,
              50.144814
            ],
            [
              -5.681207,
              50.144747
            ],
            [
              -5.681302,
              50.144705
            ],
            [
              -5.681386,
              50.144664
            ],
            [
              -5.681425,
              50.144648
            ],
            [
              -5.681460,
              50.144629
            ],
            [
              -5.681517,
              50.144599
            ],
            [
              -5.681553,
              50.144576
            ],
            [
              -5.681675,
              50.144511
            ],
            [
              -5.681682,
              50.144507
            ],
            [
              -5.681785,
              50.144452
            ],
            [
              -5.681763,
              50.144423
            ],
            [
              -5.681750,
              50.144402
            ],
            [
              -5.681744,
              50.144390
            ],
            [
              -5.681734,
              50.144380
            ],
            [
              -5.681725,
              50.144371
            ],
            [
              -5.681706,
              50.144349
            ],
            [
              -5.681673,
              50.144325
            ],
            [
              -5.681605,
              50.144273
            ],
            [
              -5.681537,
              50.144222
            ],
            [
              -5.681503,
              50.144188
            ],
            [
              -5.681482,
              50.144176
            ],
            [
              -5.681429,
              50.144134
            ],
            [
              -5.681555,
              50.143931
            ],
            [
              -5.681575,
              50.143896
            ],
            [
              -5.681584,
              50.143876
            ],
            [
              -5.681594,
              50.143855
            ],
            [
              -5.681605,
              50.143832
            ],
            [
              -5.681620,
              50.143808
            ],
            [
              -5.681633,
              50.143794
            ],
            [
              -5.681657,
              50.143759
            ],
            [
              -5.681658,
              50.143753
            ],
            [
              -5.681657,
              50.143747
            ],
            [
              -5.681659,
              50.143730
            ],
            [
              -5.681659,
              50.143716
            ],
            [
              -5.681662,
              50.143696
            ],
            [
              -5.681663,
              50.143688
            ],
            [
              -5.681667,
              50.143678
            ],
            [
              -5.681672,
              50.143664
            ],
            [
              -5.681675,
              50.143649
            ]
          ]
        ]
      }
    }
  ]
}

    ''';
    final compactGeoJson = geoJson.replaceAll('\n', '').replaceAll(' ', '');
    final encodedGeoJson = Uri.encodeComponent(compactGeoJson);
    final url = 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/geojson($encodedGeoJson)/auto/600x400?access_token=$mapboxApiKey';
    return MapEntry(url, url.length);
  }

  Future<ImageProvider> fetchMapboxStaticImage(String requestUrl) async {
    if (requestUrl.length > 8192) {
      throw Exception('Geometry is too complex to display. Request length: ${requestUrl.length}');
    }

    try {
      final response = await http.get(Uri.parse(requestUrl));
      if (response.statusCode == 200) {
        return MemoryImage(response.bodyBytes);
      } else {
        throw Exception('Failed to load image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching image: $e');
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Mapbox Static Image Test')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imageProvider != null)
            Image(image: _imageProvider!),
          if (_error != null)
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
          if (_requestLength != null)
            Text(_requestLength!),
        ],
      ),
    ),
  );
}
}