import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF121212),
  ));
  runApp(const RideAggApp());
}

// ═══════════════════════════════════════════════════════════
//  DESIGN SYSTEM — Colors, Typography, Tokens
// ═══════════════════════════════════════════════════════════

class AppColors {
  static const Color bg = Color(0xFF121212);
  static const Color card = Color(0xFF1C1C1E);
  static const Color cardElevated = Color(0xFF2C2C2E);
  static const Color border = Color(0xFF38383A);
  static const Color accent = Color(0xFF007AFF);       // Electric Blue
  static const Color green = Color(0xFF34C759);
  static const Color red = Color(0xFFFF3B30);
  static const Color yellow = Color(0xFFFFD60A);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);
}

const String _tileUrl =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const List<String> _tileSubdomains = ['a', 'b', 'c', 'd'];

// Platform brand colors
class PlatformBrands {
  static const Map<String, Map<String, dynamic>> brands = {
    'Rapido':      {'color': 0xFFFFCB05, 'letter': 'R', 'textDark': true, 'image': 'LOGO/Rapido.png'},
    'Uber':        {'color': 0xFF276EF1, 'letter': 'U', 'textDark': false, 'image': 'LOGO/uber.png'},
    'Ola':         {'color': 0xFF8BC34A, 'letter': 'O', 'textDark': true, 'image': 'LOGO/ola.png'},
    'Namma Yatri': {'color': 0xFF00BCD4, 'letter': 'N', 'textDark': false, 'image': 'LOGO/namma yatri.png'},
    'Meru':        {'color': 0xFFD32F2F, 'letter': 'M', 'textDark': false, 'image': 'LOGO/meru cab.png'},
    'Quick Ride':  {'color': 0xFF1565C0, 'letter': 'Q', 'textDark': false, 'image': 'LOGO/quick ride.png'},
    'Nagara Meter':{'color': 0xFFFF9800, 'letter': 'NM', 'textDark': true, 'image': 'LOGO/Nagara.png'},
    'Bharat Taxi': {'color': 0xFFFFA000, 'letter': 'BT', 'textDark': true, 'image': 'LOGO/bharat taxi.jpg'},
    'Volta Cabs':  {'color': 0xFF4CAF50, 'letter': 'VC', 'textDark': true, 'image': 'LOGO/volta.jpg'},
    'Jugnoo':      {'color': 0xFFFFEB3B, 'letter': 'J', 'textDark': true, 'image': 'LOGO/jugnoo.jpg'},
    'Mega Cabs':   {'color': 0xFFF44336, 'letter': 'MC', 'textDark': false, 'image': 'LOGO/mega cabs.jpg'},
    'BlaBlaCar':   {'color': 0xFF00BCD4, 'letter': 'BB', 'textDark': false, 'image': 'LOGO/blabla.jpg'},
    'Yatri Sathi': {'color': 0xFF9C27B0, 'letter': 'YS', 'textDark': false, 'image': 'LOGO/yatri sathi.jpg'},
  };

  static Widget logo(String platform, {double size = 36}) {
    final key = brands.keys.firstWhere(
      (k) => platform.startsWith(k),
      orElse: () => 'Rapido',
    );
    final brand = brands[key]!;
    final bool dark = brand['textDark'] as bool;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Image.asset(
        brand['image'] as String,
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size, height: size, color: Color(brand['color'] as int),
          child: Center(child: Text(brand['letter'] as String, 
            style: TextStyle(color: dark ? Colors.black : Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4))),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MODELS & PERSISTENCE
// ═══════════════════════════════════════════════════════════

class SavedLocation {
  final LatLng latLng;
  final String address;
  final String name;
  final String subtitle;

  SavedLocation({
    required this.latLng,
    required this.address,
    required this.name,
    required this.subtitle,
  });

  Map<String, dynamic> toJson() => {
        'lat': latLng.latitude,
        'lng': latLng.longitude,
        'address': address,
        'name': name,
        'subtitle': subtitle,
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
        latLng: LatLng(json['lat'], json['lng']),
        address: json['address'],
        name: json['name'],
        subtitle: json['subtitle'] ?? '',
      );
}

class PreferencesManager {
  static const String _keyRecent = 'recent_searches_v1';

  static Future<List<SavedLocation>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_keyRecent);
      if (data == null) return [];
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => SavedLocation.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveRecentSearch(SavedLocation loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<SavedLocation> recents = await getRecentSearches();
      recents.removeWhere((s) => s.address == loc.address || s.name == loc.name);
      recents.insert(0, loc);
      if (recents.length > 3) recents = recents.sublist(0, 3);
      await prefs.setString(
          _keyRecent, jsonEncode(recents.map((e) => e.toJson()).toList()));
    } catch (e) {
      // Ignored
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════

IconData _getCategoryIcon(String? osmClass, String? osmType) {
  switch (osmType) {
    case 'station': case 'railway': case 'halt': return Icons.train;
    case 'bus_stop': case 'bus_station': return Icons.directions_bus;
    case 'airport': case 'aerodrome': return Icons.flight;
    case 'hospital': case 'clinic': case 'doctors': return Icons.local_hospital;
    case 'school': case 'university': case 'college': return Icons.school;
    case 'restaurant': case 'cafe': case 'fast_food': case 'food_court': return Icons.restaurant;
    case 'hotel': case 'motel': case 'hostel': case 'guest_house': return Icons.hotel;
    case 'park': case 'garden': case 'nature_reserve': return Icons.park;
    case 'mall': case 'marketplace': case 'supermarket': return Icons.shopping_bag;
    case 'cinema': case 'theatre': return Icons.movie;
    case 'museum': return Icons.museum;
    case 'place_of_worship': case 'temple': return Icons.temple_hindu;
    case 'pharmacy': return Icons.local_pharmacy;
    case 'fuel': return Icons.local_gas_station;
    case 'bank': case 'atm': return Icons.account_balance;
    case 'city': case 'town': return Icons.location_city;
    case 'village': case 'hamlet': return Icons.holiday_village;
    case 'suburb': case 'neighbourhood': case 'residential': return Icons.home_work;
    case 'attraction': case 'viewpoint': return Icons.attractions;
    default: break;
  }
  switch (osmClass) {
    case 'amenity': return Icons.place;
    case 'tourism': return Icons.attractions;
    case 'shop': return Icons.store;
    case 'highway': return Icons.route;
    case 'building': return Icons.business;
    case 'natural': return Icons.landscape;
    default: return Icons.location_on;
  }
}

Color _getTypeColor(String? osmClass, String? osmType) {
  switch (osmClass) {
    case 'tourism': return AppColors.accent;
    case 'amenity': return AppColors.green;
    case 'shop': return const Color(0xFFAF52DE);
    case 'highway': case 'railway': return AppColors.accent;
    case 'place': case 'boundary': return AppColors.yellow;
    case 'building': return const Color(0xFFAF52DE);
    case 'natural': return AppColors.green;
    default: return AppColors.textSecondary;
  }
}

double _calculateDistanceKm(LatLng from, LatLng to) {
  const Distance distance = Distance();
  return distance.as(LengthUnit.Kilometer, from, to);
}

// ═══════════════════════════════════════════════════════════
//  SMOOTH PAGE ROUTE TRANSITION
// ═══════════════════════════════════════════════════════════

Route<T> _smoothPageRoute<T>({required Widget page, bool fromCenter = false, bool fadeOnly = false}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      if (fadeOnly) {
        return FadeTransition(opacity: curved, child: child);
      }
      if (fromCenter) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      }
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════
//  ANIMATED PRESSABLE WIDGET
// ═══════════════════════════════════════════════════════════

class _AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  const _AnimatedPressable({required this.child, this.onTap, this.scaleDown = 0.96}); // ignore: unused_element_parameter
  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { setState(() => _isPressed = true); HapticFeedback.selectionClick(); },
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: Duration(milliseconds: _isPressed ? 100 : 200),
        curve: _isPressed ? Curves.easeInCubic : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  APP ROOT
// ═══════════════════════════════════════════════════════════

class RideAggApp extends StatelessWidget {
  const RideAggApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride Aggregator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.card,
          primary: AppColors.accent,
          secondary: AppColors.green,
          error: AppColors.red,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCREEN 0 — SPLASH: Branding + Competitor Orbit
// ═══════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _orbitCtrl;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    super.dispose();
  }

  void _proceed() {
    Navigator.pushReplacement(context, _smoothPageRoute(page: const HomeScreen(), fadeOnly: true));
  }

  @override
  Widget build(BuildContext context) {
    final competitors = ['Rapido', 'Uber', 'Ola', 'Namma Yatri', 'Meru'];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF0A1628), Color(0xFF050A14), Color(0xFF000000)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // ─── Orbiting Logos ─────────────────────
                SizedBox(
                  width: 260, height: 260,
                  child: AnimatedBuilder(
                    animation: _orbitCtrl,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Orbit Ring
                          Container(
                            width: 220, height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.08), width: 1.5),
                            ),
                          ),
                          // Center App Logo
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 30)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset('LOGO/Ride Aggregator.jpeg', fit: BoxFit.cover),
                            ),
                          ),
                          // Competitors
                          for (int i = 0; i < competitors.length; i++)
                            Builder(builder: (_) {
                              final angle = (2 * math.pi * i / competitors.length) + (_orbitCtrl.value * 2 * math.pi);
                              final c = competitors[i];
                              return Transform.translate(
                                offset: Offset(105 * math.cos(angle), 105 * math.sin(angle)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [BoxShadow(color: AppColors.bg.withValues(alpha: 0.5), blurRadius: 10)],
                                  ),
                                  child: PlatformBrands.logo(c, size: 40),
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  ),
                ).animate().fade(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), duration: 800.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: 48),

                const Text('Ride Aggregator',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ).animate().fade(duration: 600.ms, delay: 300.ms).slideY(begin: 0.2, duration: 600.ms, delay: 300.ms),

                const SizedBox(height: 10),

                Text('One App. All ride options.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
                ).animate().fade(duration: 600.ms, delay: 500.ms),

                const Spacer(flex: 4),

                // Get Started Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _AnimatedPressable(
                    onTap: _proceed,
                    child: Container(
                      width: double.infinity, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: const Center(
                        child: Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ).animate().fade(duration: 500.ms, delay: 700.ms).slideY(begin: 0.3, duration: 500.ms, delay: 700.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCREEN 1 — HOME: Map, Where To?, Vehicle Cards, BottomNav
// ═══════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  LatLng _currentLocation = const LatLng(12.9279, 77.6271);
  String _currentAddress = "Locating...";
  List<SavedLocation> _recentSearches = [];
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _loadRecentSearches();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final recents = await PreferencesManager.getRecentSearches();
    if (mounted) setState(() => _recentSearches = recents);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      Position position = await Geolocator.getCurrentPosition();
      final newLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _currentLocation = newLoc);
        _mapController.move(newLoc, 15);
        _reverseGeocode(newLoc);
      }
    } catch (e) { /* Ignore */ }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse('https://api.tomtom.com/search/2/reverseGeocode/${location.latitude},${location.longitude}.json?key=47pvAQxSQNZcPg4HySLLqOCygidP4YOi');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = data['addresses'] as List?;
        final addrStr = (addresses != null && addresses.isNotEmpty) ? addresses[0]['address']['freeformAddress'] : "Current Location";
        if (mounted) setState(() => _currentAddress = addrStr?.toString() ?? "Current Location");
      }
    } catch (e) { /* Ignore */ }
  }

  void _openSetLocation({String vehicleType = 'Cab', SavedLocation? presetDropoff}) {
    Navigator.push(context, _smoothPageRoute(
      page: SetLocationScreen(
        vehicleType: vehicleType,
        initialPickup: SavedLocation(latLng: _currentLocation, address: _currentAddress, name: 'Current Location', subtitle: ''),
        initialDropoff: presetDropoff,
      ),
    )).then((_) => _loadRecentSearches());
  }

  Widget _buildVehicleCard(String title, IconData icon, Color color, Color bgGradientStart) {
    return Expanded(
      child: _AnimatedPressable(
        onTap: () => _openSetLocation(vehicleType: title),
        child: Container(
          height: 110,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [bgGradientStart.withValues(alpha: 0.15), AppColors.card],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return Stack(
        children: [
          // ── MAP ────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation, initialZoom: 15.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(urlTemplate: _tileUrl, subdomains: _tileSubdomains, userAgentPackageName: 'com.rideagg.app', retinaMode: true),
              MarkerLayer(markers: [
                Marker(point: _currentLocation, width: 44, height: 44, child: _PulsingDot(pulseAnim: _pulseAnim)),
              ]),
            ],
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.40,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.card,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: AppColors.accent),
            ),
          ),

          // ── GRADIENT ──────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bg.withValues(alpha: 0.95), AppColors.bg.withValues(alpha: 0.5),
                      Colors.transparent, Colors.transparent,
                      AppColors.bg.withValues(alpha: 0.85), AppColors.bg,
                    ],
                    stops: const [0.0, 0.15, 0.3, 0.5, 0.72, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── TOP CONTENT ───────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.green,
                          boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.5), blurRadius: 4)]),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(_currentAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),

                  // WHERE TO?
                  _AnimatedPressable(
                    onTap: () => _openSetLocation(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.card.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            const Icon(Icons.search_rounded, color: AppColors.textPrimary, size: 26),
                            const SizedBox(width: 14),
                            Text('Where to?', style: TextStyle(
                              color: AppColors.textPrimary.withValues(alpha: 0.9), fontSize: 22, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // VEHICLE CARDS
                  Row(children: [
                    _buildVehicleCard('Bike', Icons.two_wheeler, AppColors.accent, AppColors.accent),
                    _buildVehicleCard('Auto', Icons.electric_rickshaw, AppColors.green, AppColors.green),
                    _buildVehicleCard('Cab', Icons.local_taxi, AppColors.yellow, AppColors.yellow),
                  ]),
                ],
              ),
            ),
          ),

          // ── BOTTOM: Recent Searches ───────────────
          if (_recentSearches.isNotEmpty)
            Positioned(
              left: 0, right: 0, bottom: 72,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('RECENT', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _recentSearches.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final loc = entry.value;
                              return _AnimatedPressable(
                                onTap: () => _openSetLocation(presetDropoff: loc),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    border: idx < _recentSearches.length - 1
                                        ? const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)) : null,
                                  ),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.history, color: AppColors.textSecondary, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(loc.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                                        if (loc.subtitle.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(loc.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ],
                                      ]),
                                    ),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
  }

  Widget _buildActivityView() {
    final mockRides = [
      {'date': 'Yesterday, 4:30 PM', 'price': '₹145', 'pickup': 'Jaipur Junction', 'drop': 'Nymph Academy'},
      {'date': 'Jun 7, 10:15 AM', 'price': '₹85', 'pickup': 'Nymph Academy', 'drop': 'City Palace'},
      {'date': 'Jun 5, 2:00 PM', 'price': '₹210', 'pickup': 'City Palace', 'drop': 'Airport'},
      {'date': 'Jun 3, 9:00 AM', 'price': '₹110', 'pickup': 'Airport', 'drop': 'Jaipur Junction'},
    ];

    return Container(
      color: AppColors.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Text('Your Rides', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mockRides.length,
                itemBuilder: (context, index) {
                  final ride = mockRides[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ride['date']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(ride['price']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(ride['pickup']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15))),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 3.5),
                          child: Container(width: 1, height: 16, color: AppColors.border),
                        ),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(ride['drop']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15))),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 300.ms, delay: (index * 100).ms).slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountView() {
    return Container(
      color: AppColors.bg,
      width: double.infinity,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.engineering_rounded, size: 80, color: AppColors.accent)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 2.seconds)
                .scaleXY(begin: 0.9, end: 1.0, duration: 1.seconds, curve: Curves.easeInOutSine)
                .then()
                .scaleXY(begin: 1.0, end: 0.9, duration: 1.seconds, curve: Curves.easeInOutSine),
            const SizedBox(height: 24),
            const Text('Work in Progress', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('We are building something awesome here.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _bottomNavIndex,
        children: [
          _buildHomeView(),
          _buildActivityView(),
          _buildAccountView(),
        ],
      ),
      // ── BOTTOM NAV ────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_filled, 'Home', 0),
                _buildNavItem(Icons.receipt_long, 'Activity', 1),
                _buildNavItem(Icons.person_outline, 'Account', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool active = _bottomNavIndex == index;
    return _AnimatedPressable(
      onTap: () => setState(() => _bottomNavIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? AppColors.accent : AppColors.textTertiary, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: active ? AppColors.accent : AppColors.textTertiary,
            fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 20 : 0, height: 2,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(1)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCREEN 2 — SET LOCATION: Dual Search Fields
// ═══════════════════════════════════════════════════════════

class SetLocationScreen extends StatefulWidget {
  final String vehicleType;
  final SavedLocation? initialPickup;
  final SavedLocation? initialDropoff;
  const SetLocationScreen({super.key, required this.vehicleType, this.initialPickup, this.initialDropoff});
  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropoffFocus = FocusNode();

  bool _isPickupActive = false;
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  SavedLocation? _selectedPickup;
  SavedLocation? _selectedDropoff;

  @override
  void initState() {
    super.initState();
    _selectedPickup = widget.initialPickup;
    _selectedDropoff = widget.initialDropoff;
    if (_selectedPickup != null) _pickupController.text = _selectedPickup!.name;
    if (_selectedDropoff != null) _dropoffController.text = _selectedDropoff!.name;

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) setState(() { _isPickupActive = true; _clearSearch(); _searchPlaces(_pickupController.text); });
    });
    _dropoffFocus.addListener(() {
      if (_dropoffFocus.hasFocus) setState(() { _isPickupActive = false; _clearSearch(); _searchPlaces(_dropoffController.text); });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedDropoff == null) { _dropoffFocus.requestFocus(); } else { _checkBothSelected(); }
    });
  }

  @override
  void dispose() {
    _pickupController.dispose(); _dropoffController.dispose();
    _pickupFocus.dispose(); _dropoffFocus.dispose();
    _debounce?.cancel(); super.dispose();
  }

  void _checkBothSelected() async {
    if (_selectedPickup != null && _selectedDropoff != null) {
      FocusScope.of(context).unfocus();
      
      final budget = await showModalBottomSheet<int?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const BudgetPromptSheet(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(context, _smoothPageRoute(
        page: ResultsScreen(pickup: _selectedPickup!, dropoff: _selectedDropoff!, vehicleType: widget.vehicleType, budget: budget),
      ));
    }
  }

  void _clearSearch() { setState(() { _searchResults = []; _isSearching = false; _hasSearched = false; }); }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) { _clearSearch(); return; }
    setState(() => _isSearching = true);
    try {
      final encoded = Uri.encodeQueryComponent(query);
      final url = Uri.parse('https://api.tomtom.com/search/2/search/$encoded.json?key=47pvAQxSQNZcPg4HySLLqOCygidP4YOi&limit=8&countrySet=IN');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) setState(() { _searchResults = data['results'] as List? ?? []; _isSearching = false; _hasSearched = true; });
      }
    } catch (e) { if (mounted) setState(() => _isSearching = false); }
  }

  void _onSearchQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _searchPlaces(query));
  }

  void _onSearchResultTapped(dynamic res) async {
    final pos = res['position'] as Map<String, dynamic>? ?? {};
    final lat = double.tryParse(pos['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(pos['lon']?.toString() ?? '') ?? 0;
    
    final poi = res['poi'] as Map<String, dynamic>?;
    final addr = res['address'] as Map<String, dynamic>?;
    
    final name = poi?['name']?.toString() ?? addr?['freeformAddress']?.toString() ?? 'Location';
    final subtitle = addr?['freeformAddress']?.toString() ?? '';
    final fullAddress = subtitle.isEmpty ? name : subtitle;
    
    final location = SavedLocation(latLng: LatLng(lat, lon), address: fullAddress, name: name, subtitle: fullAddress);
    HapticFeedback.lightImpact();

    if (_isPickupActive) {
      setState(() { _selectedPickup = location; _pickupController.text = location.name; });
      _dropoffFocus.requestFocus();
    } else {
      setState(() { _selectedDropoff = location; _dropoffController.text = location.name; });
      await PreferencesManager.saveRecentSearch(location);
      _checkBothSelected();
    }
  }

  Future<void> _openMapPicker() async {
    FocusScope.of(context).unfocus();
    final pickingPickup = _isPickupActive;
    final startLoc = pickingPickup
        ? (_selectedPickup?.latLng ?? const LatLng(12.9279, 77.6271))
        : (_selectedDropoff?.latLng ?? _selectedPickup?.latLng ?? const LatLng(12.9279, 77.6271));
    final result = await Navigator.push(context, _smoothPageRoute(page: MapPickerScreen(initialLocation: startLoc, isPickup: pickingPickup)));
    if (result != null && result is Map<String, dynamic>) {
      final latLng = result['latLng'] as LatLng;
      final address = result['address'] as String;
      final name = address.split(',').first;
      final location = SavedLocation(latLng: latLng, address: address, name: name, subtitle: address);
      if (pickingPickup) {
        setState(() { _selectedPickup = location; _pickupController.text = name; });
        _dropoffFocus.requestFocus();
      } else {
        setState(() { _selectedDropoff = location; _dropoffController.text = name; });
        await PreferencesManager.saveRecentSearch(location);
        _checkBothSelected();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              _AnimatedPressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Set Location', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          ),

          // Input fields
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: IntrinsicHeight(
              child: Row(children: [
                Column(children: [
                  const SizedBox(height: 14),
                  Container(width: 12, height: 12, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.green,
                    boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.4), blurRadius: 4)],
                  )),
                  Expanded(child: _DottedVerticalLine(height: double.infinity, color: AppColors.border)),
                  Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.red)),
                  const SizedBox(height: 14),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(children: [
                    Row(children: [
                      const Text('PICKUP', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ]),
                    TextField(
                      controller: _pickupController, focusNode: _pickupFocus, onChanged: _onSearchQueryChanged,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Pickup location', hintStyle: const TextStyle(color: AppColors.textTertiary), border: InputBorder.none,
                        isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: _pickupController.text.isNotEmpty && _isPickupActive
                            ? IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary), onPressed: () { _pickupController.clear(); _clearSearch(); }) : null,
                      ),
                    ),
                    Divider(color: AppColors.border.withValues(alpha: 0.4), height: 1),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text('DROP', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ]),
                    TextField(
                      controller: _dropoffController, focusNode: _dropoffFocus, onChanged: _onSearchQueryChanged,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Where to?', hintStyle: const TextStyle(color: AppColors.textTertiary), border: InputBorder.none,
                        isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixIcon: _dropoffController.text.isNotEmpty && !_isPickupActive
                            ? IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary), onPressed: () { _dropoffController.clear(); _clearSearch(); }) : null,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // Choose on map
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AnimatedPressable(
              onTap: _openMapPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.map_outlined, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  const Text('Choose location on map', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Results
          if (_isSearching) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final res = _searchResults[index];
                  final poi = res['poi'] as Map<String, dynamic>?;
                  final addr = res['address'] as Map<String, dynamic>?;
                  
                  final name = poi?['name']?.toString() ?? addr?['freeformAddress']?.toString() ?? 'Location';
                  final icon = Icons.location_on;
                  final typeColor = AppColors.accent;
                  final subtitle = addr?['freeformAddress']?.toString() ?? '';
                  return _AnimatedPressable(
                    onTap: () => _onSearchResultTapped(res),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: index < _searchResults.length - 1 ? Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3))) : null,
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, color: typeColor, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                          if (subtitle.isNotEmpty) ...[const SizedBox(height: 2),
                            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))],
                        ])),
                      ]),
                    ),
                  ).animate().fade(duration: 200.ms, delay: (index * 30).ms);
                },
              ),
            )
          else if (_hasSearched)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No results found.', style: TextStyle(color: AppColors.textSecondary)))),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCREEN 3 — MAP PICKER
// ═══════════════════════════════════════════════════════════

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final bool isPickup;
  const MapPickerScreen({super.key, required this.initialLocation, required this.isPickup});
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with TickerProviderStateMixin {
  late LatLng _currentLocation;
  String _currentAddress = "Loading address...";
  bool _isDragging = false;
  bool _isLoadingAddress = false;
  late final AnimationController _pinController;
  Timer? _debounce;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
    _mapController = MapController();
    _pinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), lowerBound: 0.0, upperBound: 1.0);
    _reverseGeocode(_currentLocation);
  }

  @override
  void dispose() { _pinController.dispose(); _mapController.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _reverseGeocode(LatLng location) async {
    setState(() => _isLoadingAddress = true);
    try {
      final url = Uri.parse('https://api.tomtom.com/search/2/reverseGeocode/${location.latitude},${location.longitude}.json?key=47pvAQxSQNZcPg4HySLLqOCygidP4YOi');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = data['addresses'] as List?;
        final addrStr = (addresses != null && addresses.isNotEmpty) ? addresses[0]['address']['freeformAddress'] : "Unknown Location";
        if (mounted) setState(() { _currentAddress = addrStr?.toString() ?? "Unknown Location"; _isLoadingAddress = false; });
      } else { if (mounted) setState(() => _isLoadingAddress = false); }
    } catch (e) { if (mounted) setState(() => _isLoadingAddress = false); }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _currentLocation = camera.center;
      if (!_isDragging) { setState(() => _isDragging = true); _pinController.forward(); }
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) { setState(() => _isDragging = false); _pinController.reverse(); _reverseGeocode(_currentLocation); }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _currentLocation, initialZoom: 16, onPositionChanged: _onPositionChanged),
          children: [TileLayer(urlTemplate: _tileUrl, subdomains: _tileSubdomains, userAgentPackageName: 'com.rideagg.app', retinaMode: true)],
        ),
        // Center pin
        Center(
          child: AnimatedBuilder(
            animation: _pinController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -24 - (18 * _pinController.value)),
                child: Icon(
                  widget.isPickup ? Icons.radio_button_checked : Icons.location_on,
                  color: widget.isPickup ? AppColors.green : AppColors.red, size: 40,
                ),
              );
            },
          ),
        ),
        // Shadow dot under pin
        Center(
          child: AnimatedBuilder(
            animation: _pinController,
            builder: (context, _) => Transform.translate(
              offset: const Offset(0, 2),
              child: Container(
                width: 8 + (4 * _pinController.value), height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3 - (0.15 * _pinController.value)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 10, left: 10,
          child: _AnimatedPressable(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
        ),
        // Bottom confirm
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -6))],
            ),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.isPickup ? 'SELECT PICKUP LOCATION' : 'SELECT DROP-OFF LOCATION',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(widget.isPickup ? Icons.radio_button_checked : Icons.location_on,
                    color: widget.isPickup ? AppColors.green : AppColors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isLoadingAddress
                          ? const Text("Resolving address...", key: ValueKey('loading'), style: TextStyle(color: AppColors.textSecondary))
                          : Text(_currentAddress, key: ValueKey(_currentAddress), maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _AnimatedPressable(
                  onTap: _isLoadingAddress ? null : () => Navigator.pop(context, {'latLng': _currentLocation, 'address': _currentAddress}),
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: _isLoadingAddress ? AppColors.cardElevated : AppColors.accent),
                    child: Center(child: Text('Confirm Location', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _isLoadingAddress ? AppColors.textTertiary : Colors.white))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WIDGET — CONFIRM PICKUP BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class ConfirmPickupSheet extends StatefulWidget {
  final SavedLocation pickup;
  final SavedLocation dropoff;
  final String vehicleType;
  const ConfirmPickupSheet({super.key, required this.pickup, required this.dropoff, required this.vehicleType});
  @override
  State<ConfirmPickupSheet> createState() => _ConfirmPickupSheetState();
}

class _ConfirmPickupSheetState extends State<ConfirmPickupSheet> with SingleTickerProviderStateMixin {
  int _countdown = 3;
  Timer? _timer;
  late final AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) { if (mounted) setState(() => _countdown--); }
      else { timer.cancel(); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); _progressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Confirm Ride', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              _AnimatedPressable(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppColors.cardElevated, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                ),
              ),
            ]),
          ),
          // Mini Map
          SizedBox(
            height: 160, width: double.infinity,
            child: FlutterMap(
              options: MapOptions(initialCenter: widget.pickup.latLng, initialZoom: 16.5,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
              children: [
                TileLayer(urlTemplate: _tileUrl, subdomains: _tileSubdomains, userAgentPackageName: 'com.rideagg.app'),
                MarkerLayer(markers: [
                  Marker(point: widget.pickup.latLng, width: 44, height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: const Icon(Icons.person, color: AppColors.accent, size: 22),
                    )),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.pickup.address, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              // Countdown progress bar
              AnimatedBuilder(
                animation: _progressCtrl,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 1.0 - _progressCtrl.value, backgroundColor: AppColors.cardElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent), minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: _AnimatedPressable(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.cardElevated),
                      child: const Center(child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _AnimatedPressable(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.accent,
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                      child: Center(child: Text('Confirm Ride ($_countdown)',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCREEN 4 — RESULTS: Available Rides + Filters + Logos
// ═══════════════════════════════════════════════════════════

class ResultsScreen extends StatefulWidget {
  final SavedLocation pickup;
  final SavedLocation dropoff;
  final String vehicleType;
  final int? budget;
  const ResultsScreen({super.key, required this.pickup, required this.dropoff, required this.vehicleType, this.budget});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;
  double _distanceKm = 0;
  String _distanceStr = "";
  double _durationMins = 0; // used in _generateAllRides
  List<Map<String, dynamic>> _allRides = [];
  String _activeFilter = 'all'; // all, bike, auto, cab
  bool _fastMode = false;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.vehicleType.toLowerCase();
    _calculateRouteAndPrices();
  }

  Future<void> _calculateRouteAndPrices() async {
    try {
      final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${widget.pickup.latLng.longitude},${widget.pickup.latLng.latitude};${widget.dropoff.latLng.longitude},${widget.dropoff.latLng.latitude}?overview=false');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          _distanceKm = route['distance'] / 1000.0;
          _distanceStr = "${_distanceKm.toStringAsFixed(1)} km";
          _durationMins = route['duration'] / 60.0;
        }
      }
    } catch (e) {
      _distanceKm = _calculateDistanceKm(widget.pickup.latLng, widget.dropoff.latLng);
      _distanceStr = "${_distanceKm.toStringAsFixed(1)} km";
      _durationMins = _distanceKm * 3.0;
    }
    _allRides = _generateAllRides();
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _generateAllRides() {
    final rand = math.Random();
    int r() => rand.nextInt(12) - 6;

    final templates = [
      // Bike
      {'platform': 'Rapido', 'type': 'Bike', 'vt': 'bike', 'base': 20, 'perKm': 8.0},
      {'platform': 'Uber', 'type': 'Moto', 'vt': 'bike', 'base': 25, 'perKm': 9.0},
      {'platform': 'Ola', 'type': 'Bike', 'vt': 'bike', 'base': 22, 'perKm': 8.5},
      {'platform': 'Namma Yatri', 'type': 'Bike', 'vt': 'bike', 'base': 18, 'perKm': 7.5},
      // Auto
      {'platform': 'Rapido', 'type': 'Auto', 'vt': 'auto', 'base': 30, 'perKm': 12.0},
      {'platform': 'Namma Yatri', 'type': 'Auto', 'vt': 'auto', 'base': 28, 'perKm': 11.0},
      {'platform': 'Ola', 'type': 'Auto', 'vt': 'auto', 'base': 35, 'perKm': 14.0},
      {'platform': 'Uber', 'type': 'Auto', 'vt': 'auto', 'base': 38, 'perKm': 15.0},
      {'platform': 'Nagara Meter', 'type': 'Auto', 'vt': 'auto', 'base': 25, 'perKm': 13.0},
      {'platform': 'Jugnoo', 'type': 'Auto', 'vt': 'auto', 'base': 26, 'perKm': 12.5},
      {'platform': 'Yatri Sathi', 'type': 'Auto', 'vt': 'auto', 'base': 24, 'perKm': 11.5},
      // Cab
      {'platform': 'Rapido', 'type': 'Cab', 'vt': 'cab', 'base': 42, 'perKm': 16.0},
      {'platform': 'Uber', 'type': 'Go', 'vt': 'cab', 'base': 50, 'perKm': 20.0},
      {'platform': 'Ola', 'type': 'Mini', 'vt': 'cab', 'base': 48, 'perKm': 18.0},
      {'platform': 'Meru', 'type': 'Cab', 'vt': 'cab', 'base': 58, 'perKm': 22.0},
      {'platform': 'Quick Ride', 'type': 'Cab', 'vt': 'cab', 'base': 44, 'perKm': 17.0},
      {'platform': 'Bharat Taxi', 'type': 'Cab', 'vt': 'cab', 'base': 45, 'perKm': 17.5},
      {'platform': 'Volta Cabs', 'type': 'Cab', 'vt': 'cab', 'base': 40, 'perKm': 16.5},
      {'platform': 'Mega Cabs', 'type': 'Cab', 'vt': 'cab', 'base': 55, 'perKm': 21.0},
      {'platform': 'BlaBlaCar', 'type': 'Pool', 'vt': 'cab', 'base': 30, 'perKm': 10.0},
    ];

    List<Map<String, dynamic>> results = [];
    for (final t in templates) {
      final price = ((t['base'] as int) + _distanceKm * (t['perKm'] as double)).round() + r();
      final eta = 3 + rand.nextInt(8);
      results.add({
        'platform': t['platform'] as String,
        'type': t['type'] as String,
        'vehicleType': t['vt'] as String,
        'price': price,
        'eta': '$eta min',
      });
    }
    results.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));
    return results;
  }

  List<Map<String, dynamic>> get _filteredRides {
    List<Map<String, dynamic>> rides = List.from(_allRides);
    if (_activeFilter != 'all') {
      rides = rides.where((r) => r['vehicleType'] == _activeFilter).toList();
    }
    if (widget.budget != null) {
      rides.sort((a, b) {
        int diffA = ((a['price'] as int) - widget.budget!).abs();
        int diffB = ((b['price'] as int) - widget.budget!).abs();
        return diffA.compareTo(diffB);
      });
    }
    return rides;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppColors.accent),
        const SizedBox(height: 24),
        Text('Finding rides on ONDC...', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      ])));
    }

    final rides = _filteredRides;
    final cheapestPrice = rides.isNotEmpty ? rides.first['price'] as int : 0;
    final mostExpensivePrice = rides.isNotEmpty ? rides.last['price'] as int : 0;
    final savings = mostExpensivePrice - cheapestPrice;

    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _AnimatedPressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
                  child: Row(children: [
                    Expanded(child: Text('${widget.pickup.name} → ${widget.dropoff.name}', overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(_distanceStr, style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ]),
          ).animate().fade(duration: 350.ms).slideY(begin: -0.12, duration: 350.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // Compare / Fast Mode toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _buildToggle('Compare', !_fastMode, () => setState(() => _fastMode = false)),
                _buildToggle('Fast Mode ⚡', _fastMode, () => setState(() => _fastMode = true)),
              ]),
            ),
          ),

          const SizedBox(height: 14),

          // Filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _buildFilterTab('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterTab('Bike', 'bike'),
              const SizedBox(width: 8),
              _buildFilterTab('Auto', 'auto'),
              const SizedBox(width: 8),
              _buildFilterTab('Cab', 'cab'),
            ]),
          ),

          const SizedBox(height: 14),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text('Available Rides', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          ),

          const SizedBox(height: 12),

          // Ride List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _fastMode ? (rides.isNotEmpty ? 1 : 0) : rides.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final ride = rides[index];
                final isBest = index == 0;
                final platform = ride['platform'] as String;
                final rideType = ride['type'] as String;
                final price = ride['price'] as int;
                final eta = ride['eta'] as String;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AnimatedPressable(
                    onTap: () async {
                      final detailsConfirmed = await showModalBottomSheet<bool>(
                        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                        builder: (ctx) => RideDetailsSheet(
                          pickup: widget.pickup, dropoff: widget.dropoff,
                          platform: platform, type: rideType, price: price, distanceStr: _distanceStr,
                        ),
                      );
                      
                      if (detailsConfirmed != true || !mounted) return;

                      final confirmed = await showModalBottomSheet<bool>(
                        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                        builder: (ctx) => ConfirmPickupSheet(pickup: widget.pickup, dropoff: widget.dropoff, vehicleType: widget.vehicleType),
                      );
                      if (confirmed == true && mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const _FindingCaptainDialog(),
                        );
                        await Future.delayed(const Duration(seconds: 3));
                        if (!mounted || !context.mounted) return;
                        Navigator.pop(context); // close dialog
                        Navigator.push(context, _smoothPageRoute(
                          page: RideStatusScreen(
                            pickup: widget.pickup, dropoff: widget.dropoff,
                            platformName: '$platform $rideType', price: price,
                          ),
                          fromCenter: true,
                        ));
                      }
                    },
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: isBest ? const BorderRadius.vertical(top: Radius.circular(16)) : BorderRadius.circular(16),
                          border: Border.all(color: isBest ? AppColors.accent : AppColors.border.withValues(alpha: 0.5), width: isBest ? 1.5 : 1),
                        ),
                        child: Row(children: [
                          PlatformBrands.logo(platform),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text('$platform $rideType', overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                              if (isBest) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Best Price', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.access_time_filled, color: AppColors.textTertiary, size: 13),
                              const SizedBox(width: 4),
                              Text('ETA: $eta', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(width: 10),
                              const Text('•', style: TextStyle(color: AppColors.textTertiary)),
                              const SizedBox(width: 10),
                              const Text('ONDC', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                            ]),
                          ])),
                          Text('₹$price', style: TextStyle(
                            color: isBest ? AppColors.accent : AppColors.textPrimary,
                            fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        ]),
                      ),
                      // Green savings footer for best option
                      if (isBest && savings > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
                          ),
                          child: Center(
                            child: Text('🎉 You\'re saving ₹$savings compared to most expensive!',
                              style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ]),
                  ),
                ).animate().fade(duration: 350.ms, delay: (80 + index * 80).ms).slideY(begin: 0.15, duration: 350.ms, delay: (80 + index * 80).ms, curve: Curves.easeOutQuad);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildToggle(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: _AnimatedPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(label, style: TextStyle(
            color: active ? Colors.black : AppColors.textSecondary,
            fontSize: 14, fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String filter) {
    final active = _activeFilter == filter;
    return _AnimatedPressable(
      onTap: () => setState(() => _activeFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.cardElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.border : AppColors.border.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(
          color: active ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _FindingCaptainDialog extends StatefulWidget {
  const _FindingCaptainDialog();
  @override
  State<_FindingCaptainDialog> createState() => _FindingCaptainDialogState();
}

class _FindingCaptainDialogState extends State<_FindingCaptainDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _radarCtrl,
                    builder: (context, _) => Container(
                      width: 80 + (_radarCtrl.value * 40),
                      height: 80 + (_radarCtrl.value * 40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent.withValues(alpha: 1.0 - _radarCtrl.value), width: 2),
                      ),
                    ),
                  ),
                  Container(
                    width: 60, height: 60,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                    child: const Icon(Icons.search_rounded, color: Colors.white, size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Finding your Captain...', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Connecting you to the nearest driver', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 300.ms).scale(begin: const Offset(0.9, 0.9));
  }
}


// ═══════════════════════════════════════════════════════════
//  SCREEN 5 — RIDE STATUS: OTP, Driver, Live Status
// ═══════════════════════════════════════════════════════════

class RideStatusScreen extends StatefulWidget {
  final SavedLocation pickup;
  final SavedLocation dropoff;
  final String platformName;
  final int price;
  const RideStatusScreen({super.key, required this.pickup, required this.dropoff, required this.platformName, required this.price});
  @override
  State<RideStatusScreen> createState() => _RideStatusScreenState();
}

class _RideStatusScreenState extends State<RideStatusScreen> with SingleTickerProviderStateMixin {
  late final String _otp;
  late final String _driverName;
  late final String _vehicleNumber;
  int _etaMinutes = 5;
  Timer? _etaTimer;
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    final rand = math.Random();
    _otp = '${1000 + rand.nextInt(9000)}';
    _driverName = ['Rajesh K.', 'Amit S.', 'Suresh M.', 'Prakash R.', 'Vijay T.', 'Arjun D.'][rand.nextInt(6)];
    _vehicleNumber = 'KA ${10 + rand.nextInt(40)} ${String.fromCharCode(65 + rand.nextInt(26))}${String.fromCharCode(65 + rand.nextInt(26))} ${1000 + rand.nextInt(9000)}';
    _etaMinutes = 3 + rand.nextInt(5);

    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
    _checkCtrl.forward();

    _etaTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_etaMinutes > 1 && mounted) {
        setState(() => _etaMinutes--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() { _etaTimer?.cancel(); _checkCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // Map area
        Expanded(
          flex: 3,
          child: Stack(children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  (widget.pickup.latLng.latitude + widget.dropoff.latLng.latitude) / 2,
                  (widget.pickup.latLng.longitude + widget.dropoff.latLng.longitude) / 2,
                ),
                initialZoom: 13,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(urlTemplate: _tileUrl, subdomains: _tileSubdomains, userAgentPackageName: 'com.rideagg.app', retinaMode: true),
                PolylineLayer(polylines: [
                  Polyline(points: [widget.pickup.latLng, widget.dropoff.latLng], strokeWidth: 4, color: AppColors.accent),
                ]),
                MarkerLayer(markers: [
                  Marker(point: widget.pickup.latLng, width: 30, height: 30,
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)]),
                    )),
                  Marker(point: widget.dropoff.latLng, width: 16, height: 16,
                    child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red,
                      border: Border.all(color: Colors.white, width: 2)))),
                ]),
              ],
            ),
            // Back
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, left: 10,
              child: _AnimatedPressable(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ),
          ]),
        ),

        // Bottom panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Green status bar
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.directions_car_filled, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Pickup arriving in $_etaMinutes min', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                ).animate().fade(duration: 400.ms).slideY(begin: -0.1, duration: 400.ms),

                const SizedBox(height: 28),

                // Confirmed badge
                Center(
                  child: ScaleTransition(
                    scale: _checkAnim,
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.green.withValues(alpha: 0.12),
                        border: Border.all(color: AppColors.green, width: 2.5),
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.green, size: 42),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text('Ride Confirmed', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                ).animate().fade(duration: 400.ms, delay: 200.ms),
                Center(
                  child: Text(widget.platformName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ).animate().fade(duration: 400.ms, delay: 300.ms),

                const SizedBox(height: 28),

                // OTP Section
                const Text('YOUR OTP', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _otp.split('').map((digit) => Container(
                    width: 56, height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Center(child: Text(digit, style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800))),
                  )).toList(),
                ).animate().fade(duration: 400.ms, delay: 400.ms).scale(begin: const Offset(0.9, 0.9), duration: 400.ms, delay: 400.ms),

                const SizedBox(height: 28),

                // Driver Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: AppColors.cardElevated, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.person, color: AppColors.textSecondary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_driverName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_vehicleNumber, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                    ])),
                    // Call button
                    _AnimatedPressable(
                      onTap: () { HapticFeedback.lightImpact(); },
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.phone, color: AppColors.green, size: 22),
                      ),
                    ),
                  ]),
                ).animate().fade(duration: 400.ms, delay: 500.ms).slideY(begin: 0.1, duration: 400.ms, delay: 500.ms),

                const SizedBox(height: 16),

                // Price
                Center(
                  child: Text('₹${widget.price}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800)),
                ).animate().fade(duration: 400.ms, delay: 600.ms),

                const SizedBox(height: 24),

                // Cancel Ride
                Center(
                  child: _AnimatedPressable(
                    onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.cardElevated, borderRadius: BorderRadius.circular(14)),
                      child: const Text('Cancel Ride', style: TextStyle(color: AppColors.red, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ).animate().fade(duration: 400.ms, delay: 700.ms),

                const SizedBox(height: 20),

                // Done
                _AnimatedPressable(
                  onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 1.5)),
                    child: const Center(child: Text('Done', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                  ),
                ).animate().fade(duration: 400.ms, delay: 800.ms),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  UTILITY WIDGETS
// ═══════════════════════════════════════════════════════════

class _PulsingDot extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _PulsingDot({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        return Stack(alignment: Alignment.center, children: [
          Container(
            width: 44 * pulseAnim.value, height: 44 * pulseAnim.value,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.6 * (1.0 - pulseAnim.value))),
          ),
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: AppColors.accent, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
            ),
          ),
        ]);
      },
    );
  }
}

class _DottedVerticalLine extends StatelessWidget {
  final double height;
  final Color color;
  const _DottedVerticalLine({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxHeight = constraints.constrainHeight(height);
        if (boxHeight.isInfinite) return const SizedBox();
        const dashHeight = 4.0;
        const dashSpace = 4.0;
        final dashCount = (boxHeight / (dashHeight + dashSpace)).floor();
        return Flex(
          direction: Axis.vertical, mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) => SizedBox(
            width: 2, height: dashHeight,
            child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
          )),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  BUDGET PROMPT SHEET
// ═══════════════════════════════════════════════════════════

class BudgetPromptSheet extends StatefulWidget {
  const BudgetPromptSheet({super.key});
  @override
  State<BudgetPromptSheet> createState() => _BudgetPromptSheetState();
}

class _BudgetPromptSheetState extends State<BudgetPromptSheet> {
  final TextEditingController _budgetController = TextEditingController();

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.15), blurRadius: 40, spreadRadius: 0, offset: const Offset(0, -10)),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48, height: 5,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Set Your Budget', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('We will find and rank the best rides tailored to your budget.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card, 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 2),
                boxShadow: [
                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  const Text('₹', style: TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                      decoration: const InputDecoration(
                        hintText: '0', hintStyle: TextStyle(color: AppColors.border),
                        border: InputBorder.none, isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: _AnimatedPressable(
                    onTap: () => Navigator.pop(context, null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated, 
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: const Center(child: Text('Skip', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _AnimatedPressable(
                    onTap: () {
                      final val = int.tryParse(_budgetController.text);
                      Navigator.pop(context, val);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF0056B3)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Center(child: Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  RIDE DETAILS SHEET
// ═══════════════════════════════════════════════════════════

class RideDetailsSheet extends StatelessWidget {
  final SavedLocation pickup;
  final SavedLocation dropoff;
  final String platform;
  final String type;
  final int price;
  final String distanceStr;

  const RideDetailsSheet({
    super.key, required this.pickup, required this.dropoff,
    required this.platform, required this.type, required this.price, required this.distanceStr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  PlatformBrands.logo(platform, size: 48),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$platform $type', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Est. distance: $distanceStr', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              Text('₹$price', style: const TextStyle(color: AppColors.accent, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(pickup.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4.5, top: 4, bottom: 4),
                  child: Align(alignment: Alignment.centerLeft, child: Container(width: 1, height: 12, color: AppColors.border)),
                ),
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(dropoff.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _AnimatedPressable(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: AppColors.cardElevated, borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('Cancel', style: TextStyle(color: AppColors.red, fontSize: 16, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _AnimatedPressable(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('Pickup', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}