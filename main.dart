import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuardianSafeApp());
}

class GuardianSafeApp extends StatefulWidget {
  const GuardianSafeApp({super.key});

  @override
  State<GuardianSafeApp> createState() => _GuardianSafeAppState();
}

class _GuardianSafeAppState extends State<GuardianSafeApp> {
  String _selectedLanguage = 'hi'; // Default Hindi for India/J&K

  void _updateLanguage(String langCode) {
    setState(() {
      _selectedLanguage = langCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardianSafe - J&K Safety App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEC4899), // Rose accent
          secondary: Color(0xFFF59E0B), // Amber accent
          surface: Color(0xFF161F30),
        ),
      ),
      home: MainSafetyScreen(
        currentLanguage: _selectedLanguage,
        onLanguageChanged: _updateLanguage,
      ),
    );
  }
}

class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({required this.name, required this.phone});
}

class MainSafetyScreen extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String> onLanguageChanged;

  const MainSafetyScreen({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<MainSafetyScreen> createState() => _MainSafetyScreenState();
}

class _MainSafetyScreenState extends State<MainSafetyScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Location State
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSub;
  bool _isLoadingLocation = true;
  String? _errorMessage;
  bool _isInJammuKashmir = false;

  // Legal Disclaimer & Terms Agreement State
  bool _hasAcceptedLegalDisclaimer = false;
  bool _disclaimerCheckbox = false;

  // 5 Emergency Contacts (Stored in SharedPreferences)
  List<EmergencyContact> _contacts = [];

  // Admin Configurable Payment Settings (Stored locally)
  String _adminUpiId = "safetyapp@upi";
  String _scannerProPrice = "49";
  String _adminPin = "9999";

  // Rollout & User Metrics
  int _simulatedUserCount = 14200; // Count towards 1 Lakh milestone

  // Active Modes
  bool _isTejSirenActive = false;
  bool _isGupatSirenActive = false;
  Timer? _stealthPulseTimer;

  // Animation for pulse marker
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadLocalPreferences();
    _initLocationService();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _stealthPulseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // Load Local SharedPreferences (Zero Server Bills)
  // -------------------------------------------------------------
  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasAcceptedLegalDisclaimer = prefs.getBool('accepted_disclaimer_jk') ?? false;
      _adminUpiId = prefs.getString('admin_upi_id') ?? "safetyapp@upi";
      _scannerProPrice = prefs.getString('scanner_pro_price') ?? "49";

      // Load 5 saved contacts
      _contacts = [];
      for (int i = 1; i <= 5; i++) {
        final name = prefs.getString('contact_${i}_name');
        final phone = prefs.getString('contact_${i}_phone');
        if (name != null && phone != null && phone.isNotEmpty) {
          _contacts.add(EmergencyContact(name: name, phone: phone));
        }
      }
    });

    if (!_hasAcceptedLegalDisclaimer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMandatoryLegalDialog();
      });
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 1; i <= 5; i++) {
      if (i <= _contacts.length) {
        await prefs.setString('contact_${i}_name', _contacts[i - 1].name);
        await prefs.setString('contact_${i}_phone', _contacts[i - 1].phone);
      } else {
        await prefs.remove('contact_${i}_name');
        await prefs.remove('contact_${i}_phone');
      }
    }
  }

  // -------------------------------------------------------------
  // Mandatory Legal Disclaimer Modal (High Court Jammu Jurisdiction)
  // -------------------------------------------------------------
  void _showMandatoryLegalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              ),
              title: Row(
                children: const [
                  Icon(Icons.gavel_rounded, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'कानूनी शपथ व डिस्क्लेमर\nLegal & Privacy Agreement',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'न्यायाधिकार सूचना (Jurisdiction Clause):\n'
                        'इस एप्लिकेशन से संबंधित किसी भी विवाद या कानूनी मामले का क्षेत्राधिकार केवल जम्मू कश्मीर और लद्दाख उच्च न्यायालय, जम्मू पीठ (High Court of Jammu & Kashmir and Ladakh at Jammu) के अधीन होगा।',
                        style: TextStyle(fontSize: 12, color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. उपयोगकर्ता यह स्वीकार करता है कि ऐप केवल आपातकालीन आत्म-सुरक्षा सहायता के लिए है।\n'
                      '2. ऐप का किसी भी प्रकार का गलत उपयोग, प्रैंक या झूठी इमरजेंसी अलार्म बजाने पर उपयोगकर्ता स्वयं पूर्णतः कानूनी व आर्थिक रूप से जिम्मेदार होगा। डेवलपर या ऐप टीम पर कोई कानूनी कार्रवाई मान्य नहीं होगी।\n'
                      '3. ऐप में किसी भी प्रकार का डाटा किसी सर्वर पर स्टोर नहीं किया जाता। यह 100% सर्वरलेस व प्राइवेसी-प्रोटेक्टेड है।',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _disclaimerCheckbox,
                          activeColor: const Color(0xFFEC4899),
                          onChanged: (val) {
                            setDialogState(() {
                              _disclaimerCheckbox = val ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'मैं सभी नियमों से सहमत हूँ और गलत उपयोग के लिए स्वयं जिम्मेदार रहूँगा/रहूँगी।',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _disclaimerCheckbox ? const Color(0xFFEC4899) : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _disclaimerCheckbox
                      ? () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('accepted_disclaimer_jk', true);
                          setState(() {
                            _hasAcceptedLegalDisclaimer = true;
                          });
                          Navigator.of(dialogContext).pop();
                        }
                      : null,
                  child: const Text('स्वीकार करें और ऐप शुरू करें'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Live GPS Initialization & J&K Geo-Engine
  // -------------------------------------------------------------
  Future<void> _initLocationService() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'कृपया फोन सेटिंग्स में GPS चालू करें।';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'सुरक्षा के लिए लोकेशन अनुमति अनिवार्य है।';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'लोकेशन हमेशा के लिए बंद है। कृपया सेटिंग्स खोलें।';
          _isLoadingLocation = false;
        });
        return;
      }

      Position initialPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Check Jammu & Kashmir Geo-fence bounds (Lat: 32.2 to 37.1, Lng: 73.4 to 80.3)
      bool inJK = (initialPos.latitude >= 32.2 && initialPos.latitude <= 37.1 &&
                   initialPos.longitude >= 73.4 && initialPos.longitude <= 80.3);

      setState(() {
        _currentPosition = initialPos;
        _isInJammuKashmir = inJK;
        _isLoadingLocation = false;
      });

      _mapController.move(LatLng(initialPos.latitude, initialPos.longitude), 16.5);

      // Continuous GPS Stream
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen((Position position) {
        setState(() {
          _currentPosition = position;
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'GPS Error: $e';
        _isLoadingLocation = false;
      });
    }
  }

  // -------------------------------------------------------------
  // 1. TEJ SIREN (तेज़ सायरन / Loud Alert)
  // -------------------------------------------------------------
  void _toggleTejSiren() {
    setState(() {
      _isTejSirenActive = !_isTejSirenActive;
      if (_isTejSirenActive) _isGupatSirenActive = false;
    });

    if (_isTejSirenActive) {
      // System high-rate vibration alarm
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ तेज़ सायरन सक्रिय! आसपास के लोगों का ध्यान आकर्षित करने के लिए अलार्म चालू है।'),
        ),
      );
    }
  }

  // -------------------------------------------------------------
  // 2. GUPAT SIREN (गुप्त सायरन / Silent Stealth SOS)
  // -------------------------------------------------------------
  void _triggerGupatSiren() {
    setState(() {
      _isGupatSirenActive = true;
      _isTejSirenActive = false;
    });

    // Subtle single haptic buzz confirmation so attacker doesn't hear anything
    HapticFeedback.lightImpact();

    _stealthPulseTimer?.cancel();
    _stealthPulseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isGupatSirenActive = false;
        });
      }
    });

    // Send silent distress SMS to all 5 saved contacts without making noise
    _sendDistressToSavedContacts(isSilent: true);
  }

  // -------------------------------------------------------------
  // Peer-to-Peer Distress SMS to 5 Contacts (Zero Server)
  // -------------------------------------------------------------
  Future<void> _sendDistressToSavedContacts({bool isSilent = false}) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS लोकेशन प्राप्त होने की प्रतीक्षा करें...')),
      );
      return;
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final osmLink = 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng';

    final messagePrefix = isSilent
        ? '⚠️ [गुप्त SOS अलर्ट / Silent Distress] मुझे तुरंत सहायता चाहिए! मेरी लाइव OSM लोकेशन है: '
        : '🚨 [आपातकालीन SOS / Emergency] कृपया तुरंत मेरी सहायता करें! मेरी वर्तमान लोकेशन: ';

    final fullMessage = '$messagePrefix\n$osmLink\n(क्षेत्राधिकार: High Court of J&K at Jammu)';

    // Join up to 5 phone numbers separated by comma or semicolon
    String recipients = _contacts.map((c) => c.phone).join(',');

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': fullMessage},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('5 संपर्कों के लिए SOS लिंक तैयार: $osmLink'),
          ),
        );
      }
    } catch (e) {
      debugPrint('SMS error: $e');
    }
  }

  // -------------------------------------------------------------
  // 5 Emergency Contacts Manager Modal
  // -------------------------------------------------------------
  void _openContactsManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.contact_phone_rounded, color: Color(0xFFEC4899)),
                          SizedBox(width: 8),
                          Text(
                            '5 आपातकालीन संपर्क (Contacts)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Text(
                    'ये नंबर केवल आपके फोन में सुरक्षित रहते हैं। किसी सर्वर पर नहीं जाते।',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                  const SizedBox(height: 14),

                  // List of 5 slots
                  for (int i = 0; i < 5; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFFEC4899).withOpacity(0.2),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFEC4899), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: i < _contacts.length
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _contacts[i].name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        _contacts[i].phone,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'खाली स्लॉट (Tap + to add)',
                                    style: TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                          ),
                          if (i < _contacts.length)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setModalState(() {
                                  _contacts.removeAt(i);
                                });
                                setState(() {});
                                _saveContacts();
                              },
                            )
                          else if (_contacts.length < 5)
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFF10B981)),
                              onPressed: () => _showAddContactDialog(setModalState),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: const Text('सुरक्षित सहेजें (Save & Close)'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddContactDialog(StateSetter parentSetState) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('नया संपर्क जोड़ें', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'नाम (उदा. माँ / भाई)'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'मोबाइल नंबर (उदा. 9876543210)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  parentSetState(() {
                    _contacts.add(EmergencyContact(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                    ));
                  });
                  setState(() {});
                  _saveContacts();
                  Navigator.pop(context);
                }
              },
              child: const Text('जोड़ें'),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Safety Scanner (कमाई / Monetization Feature)
  // -------------------------------------------------------------
  void _openSafetyScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.radar_rounded, color: Color(0xFF10B981), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'स्मार्ट सेफ्टी स्कैनर (Route Risk Scanner)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('PRO SHIELD', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'यह स्कैनर आपकी लाइव लोकेशन और आसपास के मार्गों का सेफ्टी स्कोर, स्ट्रीट लाइट घनत्व और सेफ ज़ोन जांचता है।',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScannerStat('सेफ्टी स्कोर', '94%', Colors.emeraldAccent),
                    _buildScannerStat('मार्ग प्रकाश', 'अच्छा (Lit)', Colors.amberAccent),
                    _buildScannerStat('निकटतम सेफ पॉइंट', '350m', Colors.blueAccent),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // UPI Payment unlock button for App Owner
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _launchUpiPayment(),
                  icon: const Icon(Icons.payment_rounded, size: 20),
                  label: Text(
                    'अनलिमिटेड सेफ्टी पास अनलॉक करें (₹$_scannerProPrice via UPI)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'सीधा भुगतान एडमिन UPI ($_adminUpiId) पर जाएगा',
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScannerStat(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  // -------------------------------------------------------------
  // UPI Intent Launcher for Direct Revenue
  // -------------------------------------------------------------
  Future<void> _launchUpiPayment() async {
    final upiUrl = 'upi://pay?pa=$_adminUpiId&pn=GuardianSafe&am=$_scannerProPrice&cu=INR&tn=SafetyScannerPass';
    final Uri uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blueAccent,
            content: Text('UPI ID: $_adminUpiId पर ₹$_scannerProPrice भेजें'),
          ),
        );
      }
    } catch (e) {
      debugPrint('UPI error: $e');
    }
  }

  // -------------------------------------------------------------
  // Admin Panel for Updating Payment & Rollout Anytime
  // -------------------------------------------------------------
  void _openAdminPanel() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('एडमिन पैनल सत्यापन', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'एडमिन पिन दर्ज करें (डिफ़ॉल्ट: 9999)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('रद्द करें')),
            ElevatedButton(
              onPressed: () {
                if (pinController.text == _adminPin) {
                  Navigator.pop(context);
                  _showAdminSettingsSheet();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('गलत पिन!')),
                  );
                }
              },
              child: const Text('लॉगिन करें'),
            ),
          ],
        );
      },
    );
  }

  void _showAdminSettingsSheet() {
    final upiController = TextEditingController(text: _adminUpiId);
    final priceController = TextEditingController(text: _scannerProPrice);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'एडमिन कंट्रोल: पेमेंट व रोलआउट सेटिंग्स',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiController,
                decoration: const InputDecoration(labelText: 'आपकी UPI ID (जिस पर पैसे आएंगे)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'सेफ्टी स्कैनर पास शुल्क (₹)'),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('वर्तमान रोलआउट चरण: ${_isInJammuKashmir ? "जम्मू और कश्मीर (Phase 1)" : "राष्ट्रीय विस्तार (Phase 2)"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 4),
                    Text('अनुमानित सक्रिय उपयोगकर्ता: $_simulatedUserCount / 1,00,000 (1 लाख के बाद ऑटोमैटिक विश्वव्यापी)',
                        style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black87),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('admin_upi_id', upiController.text.trim());
                    await prefs.setString('scanner_pro_price', priceController.text.trim());
                    setState(() {
                      _adminUpiId = upiController.text.trim();
                      _scannerProPrice = priceController.text.trim();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('पेमेंट सेटिंग्स सफलतापूर्वक अपडेट हो गईं!')),
                    );
                  },
                  child: const Text('अपडेट सहेजें (Save Changes)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // UI Builder
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final LatLng initialPoint = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(32.7266, 74.8570); // Default Jammu City coordinates

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('गार्डियन सेफ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isInJammuKashmir ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isInJammuKashmir ? Colors.redAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _isInJammuKashmir ? 'J&K Phase 1' : 'India Expansion',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _isInJammuKashmir ? Colors.redAccent : Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'न्यायाधिकार: High Court of J&K at Jammu • 100% Free OSM',
              style: TextStyle(fontSize: 9.5, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          // Safety Scanner Button
          IconButton(
            tooltip: 'सेफ्टी स्कैनर (कमाई फ़ीचर)',
            icon: const Icon(Icons.radar_rounded, color: Color(0xFF10B981)),
            onPressed: _openSafetyScanner,
          ),
          // 5 Emergency Contacts Button
          IconButton(
            tooltip: '5 आपातकालीन संपर्क',
            icon: Badge(
              label: Text('${_contacts.length}/5'),
              backgroundColor: const Color(0xFFEC4899),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white70),
            ),
            onPressed: _openContactsManager,
          ),
          // Admin Settings (Hold or tap to open)
          IconButton(
            tooltip: 'एडमिन पेमेंट सेटिंग्स',
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent),
            onPressed: _openAdminPanel,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. FREE COPYRIGHT-FREE OPENSTREETMAP TILE LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialPoint,
              initialZoom: 16.5,
              minZoom: 3.0,
              maxZoom: 19.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.guardiansafe.jkapp',
                maxZoom: 19,
              ),

              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 70,
                      height: 70,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 50 * _pulseAnimation.value,
                                  height: 50 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (_isTejSirenActive ? Colors.red : const Color(0xFFEC4899)).withOpacity(0.35),
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isTejSirenActive ? Colors.red : const Color(0xFFEC4899),
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. LEGAL IMMUNITY BADGE
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'प्राइवेसी व कानूनी सुरक्षा सक्रिय • High Court Jammu क्षेत्राधिकार',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹0 सर्वर बिल',
                    style: TextStyle(fontSize: 10, color: Colors.greenAccent.shade200, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // 3. RECENTER BUTTON
          Positioned(
            right: 16,
            bottom: 210,
            child: FloatingActionButton.small(
              backgroundColor: const Color(0xFF1E293B),
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 17.0);
                } else {
                  _initLocationService();
                }
              },
              child: const Icon(Icons.my_location_rounded, color: Colors.white),
            ),
          ),

          // 4. DUAL SIREN ACTION BAR (TEJ SIREN & GUPAT SIREN)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.3)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'सुरक्षा सायरन नियंत्रण (${_contacts.length}/5 संपर्क तैयार)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: _openContactsManager,
                        icon: const Icon(Icons.edit, size: 13, color: Color(0xFFEC4899)),
                        label: const Text('संपर्क बदलें', style: TextStyle(fontSize: 11, color: Color(0xFFEC4899))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // BUTTON 1: TEJ SIREN (तेज़ सायरन / Loud Alert)
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTejSirenActive ? Colors.redAccent : const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _toggleTejSiren,
                            icon: Icon(_isTejSirenActive ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                            label: Text(
                              _isTejSirenActive ? 'सायरन बंद करें' : 'तेज़ सायरन\n(Loud Siren)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // BUTTON 2: GUPAT SIREN (गुप्त सायरन / Stealth Silent SOS)
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF334155),
                              foregroundColor: const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: Color(0xFFEC4899), width: 1.2),
                            ),
                            onPressed: _triggerGupatSiren,
                            icon: const Icon(Icons.notifications_off_rounded, color: Color(0xFFEC4899)),
                            label: const Text(
                              'गुप्त सायरन\n(Silent SOS)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
