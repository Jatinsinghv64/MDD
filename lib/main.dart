// main.dart
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'DineInScreen.dart';
import 'OrderScreen.dart';
import 'Profile.dart';
import 'Takeaway Screen.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check if it's the first launch
  final prefs = await SharedPreferences.getInstance();
  final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class MyApp extends StatefulWidget {
  final bool isFirstLaunch;

  const MyApp({Key? key, required this.isFirstLaunch}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mitra Da Dhaba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        // Add bottom navigation theme if needed
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If connection is waiting, show a loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If there's an error, show an error message
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          }

          // If there's an authenticated user
          if (snapshot.hasData && snapshot.data != null) {
            // Removed ChangeNotifierProvider as CartService is a singleton
            return const MainApp();
          } else {
            // No authenticated user
            if (widget.isFirstLaunch) {
              return const WelcomeScreen();
            } else {
              return const LoginScreen();
            }
          }
        },
      ),
    );
  }
}
class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  // Create controllers/preserved state for each tab
  final List<Widget> _screens = [
    const HomeScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
    const TakeAwayScreen(),
    const DineInScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.takeout_dining),
            label: 'Take Away',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Dine In',
          ),
        ],
      ),
    );
  }
}




class AppColors {
  static const Color primaryBlue = Color(0xFF2196F3); // A standard blue
  static const Color accentBlue = Color(0xFF64B5F6); // Lighter blue
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF333333);
}

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.darkGrey,
  );
  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.darkGrey,
  );
  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    color: AppColors.darkGrey,
  );
  static const TextStyle buttonText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );
}

class Address {
  final firestore.GeoPoint geolocation; // Use aliased GeoPoint
  final String city;
  final bool isDefault;
  final String label;
  final String street;

  Address({
    required this.city,
    required this.geolocation,
    required this.isDefault,
    required this.label,
    required this.street,
  });

  // Convert an Address object into a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'geolocation': geolocation,
      'isDefault': isDefault,
      'label': label,
      'street': street,
    };
  }

  // Create an Address object from a Map (from Firestore)
  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      city: map['city'] ?? '',
      geolocation: map['geolocation'] ?? const firestore.GeoPoint(0, 0), // Use aliased GeoPoint
      isDefault: map['isDefault'] ?? false,
      label: map['label'] ?? '',
      street: map['street'] ?? '',
    );
  }
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String imageUrl;
  final List<Address> addresses; // List of Address objects

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.imageUrl = '',
    this.addresses = const [],
  });

  // Convert an AppUser object into a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'imageUrl': imageUrl,
      'address': addresses.map((address) => address.toJson()).toList(), // Convert list of Address to list of Maps
    };
  }

  // Create an AppUser object from a DocumentSnapshot (from Firestore)
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      addresses: (data['address'] as List<dynamic>?)
          ?.map((addrMap) => Address.fromMap(addrMap as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Sign up with email and password
  Future<User?> signUp(String email, String password, String name, String phone) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        // Create a default address for the new user
        final defaultAddress = Address(
          city: "Doha", // Default city as per your example
          geolocation: const firestore.GeoPoint(25.25327165244221, 51.546596585184076), // Use aliased GeoPoint
          isDefault: true,
          label: "Home",
          street: "al dawadh",
        );

        // Create an AppUser object
        AppUser newUser = AppUser(
          id: user.uid,
          name: name,
          email: email,
          phone: phone,
          imageUrl: '', // Empty image URL initially
          addresses: [defaultAddress], // Add the default address
        );

        // Save user data to Firestore
        await _firestoreService.saveUserData(user.uid, newUser.toJson());
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error (Sign Up): ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Error (Sign Up): $e');
      throw Exception('An unknown error occurred during sign up.');
    }
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error (Sign In): ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Error (Sign In): $e');
      throw Exception('An unknown error occurred during sign in.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print('Error (Sign Out): $e');
      throw Exception('An error occurred during sign out.');
    }
  }

  // Get current user stream
  Stream<User?> get user {
    return _auth.authStateChanges();
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference for users
  final String _usersCollection = 'Users';

  // Save or update user data
  Future<void> saveUserData(String userId, Map<String, dynamic> userData) async {
    try {
      await _db.collection(_usersCollection).doc(userId).set(userData, SetOptions(merge: true));
      print('User data saved successfully for $userId');
    } catch (e) {
      print('Error saving user data: $e');
      throw Exception('Failed to save user data.');
    }
  }

  // Get user data by ID
  Future<AppUser?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      } else {
        print('User document does not exist for $userId');
        return null;
      }
    } catch (e) {
      print('Error getting user data: $e');
      throw Exception('Failed to retrieve user data.');
    }
  }

  // Stream user data for real-time updates
  Stream<AppUser?> streamUserData(String userId) {
    return _db.collection(_usersCollection).doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return AppUser.fromFirestore(snapshot);
      } else {
        return null;
      }
    });
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _setFirstLaunchFlag();
  }

  // Set the flag so this screen doesn't show again on subsequent launches
  Future<void> _setFirstLaunchFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Restaurant Logo/Image
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentBlue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 100,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Welcome Text
              Text(
                'Welcome to Punjabi Bites!',
                style: AppTextStyles.headline1.copyWith(color: AppColors.primaryBlue),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your authentic taste of Punjab, delivered right to your doorstep.',
                style: AppTextStyles.bodyText1.copyWith(color: AppColors.darkGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              // Get Started Button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                  shadowColor: AppColors.primaryBlue.withOpacity(0.5),
                ),
                child: Text(
                  'Get Started',
                  style: AppTextStyles.buttonText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RestaurantService _restaurantService = RestaurantService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _currentBranchId = 'Old_Airport';
  String _estimatedTime = 'Loading...';
  final PageController _pageController = PageController();
  List<String> _carouselImages = [];
  int _currentPage = 0;
  Timer? _carouselTimer;


  int _selectedCategoryIndex = -1;
  List<MenuCategory> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Address handling variables
  String _userAddress = 'Loading address...';
  List<Map<String, dynamic>> _allAddresses = [];



  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUserAddresses();
    _loadEstimatedTime();
    _loadCarouselImages();
    _startCarouselTimer();

  }
  Future<void> _loadCarouselImages() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Branch')
          .doc(_currentBranchId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final images = List<String>.from(data['offer_carousel'] ?? []);
        setState(() {
          _carouselImages = images;
        });
      }
    } catch (e) {
      debugPrint('Error loading carousel images: $e');
    }
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_carouselImages.isEmpty) return;

      if (_currentPage < _carouselImages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadEstimatedTime() async {
    final time = await _restaurantService.getEstimatedTime(_currentBranchId);
    if (mounted) {
      setState(() => _estimatedTime = time);
    }
  }


  @override
  void dispose() {
    _searchController.dispose();
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final querySnapshot = await _firestore
          .collection('menu_categories')
          .where('branchId', isEqualTo: _currentBranchId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      if (mounted) {
        setState(() {
          _categories = querySnapshot.docs.map((doc) => MenuCategory.fromFirestore(doc)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load menu. Please try again.';
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _loadUserAddresses() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        setState(() => _userAddress = 'Not logged in');
        return;
      }

      debugPrint('Loading addresses for user: ${user.email}');
      final doc = await _firestore.collection('Users').doc(user.email).get();

      if (!doc.exists) {
        debugPrint('User document not found');
        setState(() => _userAddress = 'No address set');
        return;
      }

      final data = doc.data();
      if (data == null || !data.containsKey('address')) {
        debugPrint('No address field in document');
        setState(() => _userAddress = 'No address set');
        return;
      }

      final addresses = data['address'] as List;
      debugPrint('Found ${addresses.length} addresses');

      if (addresses.isEmpty) {
        setState(() => _userAddress = 'No address set');
        return;
      }

      // Convert to List<Map<String, dynamic>> and handle potential null values
      final addressList = addresses.map((a) {
        return {
          'city': a['city'] ?? '',
          'street': a['street'] ?? '',
          'label': a['label'] ?? '',
          'isDefault': a['isDefault'] ?? false,
        };
      }).toList();

      // Find default address or use first one
      final defaultAddress = addressList.firstWhere(
            (a) => a['isDefault'] == true,
        orElse: () => addressList.first,
      );

      setState(() {
        _allAddresses = addressList;
        _userAddress = '${defaultAddress['street']}, ${defaultAddress['city']}';
      });

      debugPrint('Default address set to: $_userAddress');
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      setState(() => _userAddress = 'Error loading address');
    }
  }

  void _showAddressBottomSheet() {
    if (_allAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No addresses available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Address',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _allAddresses.length,
                  itemBuilder: (context, index) {
                    final address = _allAddresses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          address['isDefault'] ? Icons.home : Icons.location_on,
                          color: address['isDefault'] ? Colors.blue : Colors.grey,
                        ),
                        title: Text(address['label']),
                        subtitle: Text('${address['street']}, ${address['city']}'),
                        trailing: address['isDefault']
                            ? const Icon(Icons.check, color: Colors.blue)
                            : null,
                        onTap: () async {
                          Navigator.pop(context);
                          await _setDefaultAddress(address);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _setDefaultAddress(Map<String, dynamic> address) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      setState(() => _isLoading = true);

      // Update all addresses in Firestore
      final updatedAddresses = _allAddresses.map((a) => {
        ...a,
        'isDefault': a == address,
      }).toList();

      await _firestore.collection('Users').doc(user.email).update({
        'address': updatedAddresses,
      });

      // Update local state
      setState(() {
        _allAddresses = updatedAddresses;
        _userAddress = '${address['street']}, ${address['city']}';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${address['label']} set as default')),
      );
    } catch (e) {
      debugPrint('Error setting default address: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update address')),
      );
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // In your build method, modify these sections:

          SliverAppBar(
            expandedHeight: 260.0,
            pinned: true,
            backgroundColor: Colors.transparent,  // make the whole bar transparent by default
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // … your “Deliver to” InkWell …
                InkWell(
                  onTap: _showAddressBottomSheet,
                  child: Row(
                    children: [
                      const Text(
                        'Deliver to',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _userAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ],
                  ),
                ),

                // estimated time
                Text(
                  _estimatedTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final topBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                final collapsed = constraints.biggest.height <= topBarHeight + 1;

                return Stack(
                  children: [
                    // Always paint the toolbar-height region blue, at the very top:
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topBarHeight,
                      child: Container(color: Colors.blue),
                    ),

                    // Only when expanded, show the carousel *below* that blue strip:
                    if (!collapsed)
                      Padding(
                        padding: EdgeInsets.only(
                          top: topBarHeight + 16,
                          left: 16,
                          right: 16,
                          bottom: 16,
                        ),
                        child: ImageCarousel(images: _carouselImages),
                      ),
                  ],
                );
              },
            ),
          ),




// Search Bar - Remove top padding
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0), // Removed top padding
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search menu items...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                        ),
                        onChanged: (txt) => setState(() => searchQuery = txt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.filter_list, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),

          // Categories Section
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategoryIndex == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategoryIndex = isSelected ? -1 : index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryBlue.withOpacity(0.2)
                                  : Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: category.imageUrl.isNotEmpty
                                ? CircleAvatar(
                              radius: 21,
                              backgroundImage: NetworkImage(category.imageUrl),
                              backgroundColor: Colors.transparent,
                            )
                                : Icon(
                              Icons.fastfood,
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : Colors.grey[700],
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? AppColors.primaryBlue
                                : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMenuContent(),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: CartService(),
        builder: (context, child) {
          return _buildPersistentCartBar();
        },
      ),
    );
  }


  Widget _buildMenuContent() {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_categories.isEmpty) {
      return const Center(child: Text('No categories available'));
    }

    return Column(
      children: [
        if (_selectedCategoryIndex == -1)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('menu_items')
                .where('branchId', isEqualTo: _currentBranchId)
                .where('isPopular', isEqualTo: true)
                .where('isAvailable', isEqualTo: true)
                .orderBy('sortOrder')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const SizedBox(
                  height: 250,
                  child: Center(child: Text('Error loading popular dishes')),
                );
              }

              final popularItems = snapshot.data!.docs
                  .map((doc) => MenuItem.fromFirestore(doc))
                  .toList();

              if (popularItems.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Popular Dishes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: popularItems.length,
                      itemBuilder: (context, index) {
                        final item = popularItems[index];
                        return GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => DishDetailsBottomSheet(item: item),
                            );
                          },
                          child: Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                  child: SizedBox(
                                    width: 180,
                                    height: 140,
                                    child: Image.network(
                                      item.imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (BuildContext context,
                                          Widget child,
                                          ImageChunkEvent? loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                  .expectedTotalBytes !=
                                                  null
                                                  ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (BuildContext context,
                                          Object error, StackTrace? stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(Icons.fastfood,
                                                color: Colors.grey),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'QAR ${item.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (item.tags['isSpicy'] == true)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.local_fire_department_rounded,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Spicy',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),

        if (_selectedCategoryIndex == -1)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'All The Dishes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        StreamBuilder<QuerySnapshot>(
          stream: _selectedCategoryIndex == -1
              ? _firestore
              .collection('menu_items')
              .where('branchId', isEqualTo: _currentBranchId)
              .where('isAvailable', isEqualTo: true)
              .orderBy('sortOrder')
              .snapshots()
              : _firestore
              .collection('menu_items')
              .where('branchId', isEqualTo: _currentBranchId)
              .where('categoryId', isEqualTo: _categories[_selectedCategoryIndex].id)
              .where('isAvailable', isEqualTo: true)
              .orderBy('sortOrder')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data!.docs
                .map((doc) => MenuItem.fromFirestore(doc))
                .where((item) => item.name.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No items found', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search or filters',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: items.length,
              itemBuilder: (_, index) => MenuItemCard(item: items[index]),
            );
          },
        ),
      ],
    );
  }



  Widget _buildPersistentCartBar() {
    final cartService = CartService();
    final itemCount = cartService.itemCount;
    final totalAmount = cartService.totalAmount;

    if (itemCount == 0) return const SizedBox.shrink();

    return Container(
      // Add top margin to prevent overlap with content
      margin: const EdgeInsets.only(bottom: 16),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$itemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'View Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'QAR ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  // Widget _buildBody() {
  //   if (_isLoading) {
  //     return const Center(child: CircularProgressIndicator());
  //   }
  //
  //   if (_errorMessage != null) {
  //     return Center(child: Text(_errorMessage!));
  //   }
  //
  //   if (_categories.isEmpty) {
  //     return const Center(child: Text('No categories available'));
  //   }
  //
  //   return _buildMenuBody();
  // }

  // Widget _buildMenuBody() {
  //   return SingleChildScrollView(
  //     child: Column(
  //       children: [
  //         // Search bar
  //         Padding(
  //           padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
  //           child: Material(
  //             elevation: 2,
  //             borderRadius: BorderRadius.circular(12),
  //             child: TextField(
  //               controller: _searchController,
  //               decoration: InputDecoration(
  //                 hintText: 'Search menu items...',
  //                 prefixIcon: const Icon(Icons.search, color: Colors.grey),
  //                 suffixIcon: searchQuery.isNotEmpty
  //                     ? IconButton(
  //                   icon: const Icon(Icons.clear, color: Colors.grey),
  //                   onPressed: () {
  //                     setState(() {
  //                       searchQuery = '';
  //                       _searchController.clear();
  //                     });
  //                   },
  //                 )
  //                     : null,
  //                 filled: true,
  //                 fillColor: Colors.white,
  //                 border: OutlineInputBorder(
  //                   borderRadius: BorderRadius.circular(12),
  //                   borderSide: BorderSide.none,
  //                 ),
  //                 contentPadding: const EdgeInsets.symmetric(vertical: 0),
  //               ),
  //               onChanged: (txt) => setState(() => searchQuery = txt),
  //             ),
  //           ),
  //         ),
  //
  //         // Category filter chips
  //         SizedBox(
  //           height: 60,
  //           child: ListView.builder(
  //             scrollDirection: Axis.horizontal,
  //             padding: const EdgeInsets.symmetric(horizontal: 16),
  //             itemCount: _categories.length,
  //             itemBuilder: (_, i) {
  //               final category = _categories[i];
  //               final isSelected = _selectedCategoryIndex == i;
  //
  //               return Padding(
  //                 padding: const EdgeInsets.only(right: 12),
  //                 child: Container(
  //                   height: 60,
  //                   child: FilterChip(
  //                     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //                     avatar: category.imageUrl.isNotEmpty
  //                         ? CircleAvatar(
  //                       radius: 18,
  //                       backgroundImage: NetworkImage(category.imageUrl),
  //                       backgroundColor: Colors.transparent,
  //                     )
  //                         : null,
  //                     label: Text(category.name),
  //                     selected: isSelected,
  //                     onSelected: (selected) {
  //                       setState(() {
  //                         _selectedCategoryIndex = selected ? i : -1;
  //                       });
  //                     },
  //                     selectedColor: AppColors.primaryBlue.withOpacity(0.2),
  //                     checkmarkColor: AppColors.primaryBlue,
  //                     labelStyle: TextStyle(
  //                       fontSize: 16,
  //                       color: isSelected
  //                           ? AppColors.primaryBlue
  //                           : Colors.grey[700],
  //                       fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
  //                     ),
  //                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
  //                   ),
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //
  //         // Show banner only when no category is selected
  //         if (_selectedCategoryIndex == -1)
  //           Container(
  //             height: 160,
  //             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //             decoration: BoxDecoration(
  //               borderRadius: BorderRadius.circular(12),
  //               image: const DecorationImage(
  //                 image: NetworkImage('https://lh3.googleusercontent.com/r5Nb5HFce28INXU8C4dZnRShoAtPufEJfiuv6t_XMzmBvCusyEJqCsfpx51rCrMfzGmiESNdNZt5Ru2GpXv-LVMi_tiTUpvm8EmESAk=s750'),
  //                 fit: BoxFit.cover,
  //               ),
  //             ),
  //           ),
  //
  //         // Show popular dishes only when no category is selected
  //         if (_selectedCategoryIndex == -1)
  //           StreamBuilder<QuerySnapshot>(
  //             stream: _firestore
  //                 .collection('menu_items')
  //                 .where('branchId', isEqualTo: _currentBranchId)
  //                 .where('isPopular', isEqualTo: true)
  //                 .where('isAvailable', isEqualTo: true)
  //                 .orderBy('sortOrder')
  //                 .snapshots(),
  //             builder: (context, snapshot) {
  //               if (!snapshot.hasData) {
  //                 return const SizedBox(
  //                   height: 250,
  //                   child: Center(child: CircularProgressIndicator()),
  //                 );
  //               }
  //
  //               if (snapshot.hasError) {
  //                 return const SizedBox(
  //                   height: 250,
  //                   child: Center(child: Text('Error loading popular dishes')),
  //                 );
  //               }
  //
  //               final popularItems = snapshot.data!.docs
  //                   .map((doc) => MenuItem.fromFirestore(doc))
  //                   .toList();
  //
  //               if (popularItems.isEmpty) {
  //                 return const SizedBox.shrink();
  //               }
  //
  //               return Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Padding(
  //                     padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
  //                     child: Text(
  //                       'Popular Dishes',
  //                       style: TextStyle(
  //                         fontSize: 20,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                   ),
  //                   SizedBox(
  //                     height: 250,
  //                     child: ListView.builder(
  //                       scrollDirection: Axis.horizontal,
  //                       padding: const EdgeInsets.symmetric(horizontal: 16),
  //                       itemCount: popularItems.length,
  //                       itemBuilder: (context, index) {
  //                         final item = popularItems[index];
  //                         return GestureDetector(
  //                           // In the popular dishes ListView.builder, update the onTap handler:
  //                           onTap: () {
  //                             showModalBottomSheet(
  //                               context: context,
  //                               isScrollControlled: true,
  //                               backgroundColor: Colors.transparent,
  //                               builder: (context) => DishDetailsBottomSheet(item: item),
  //                             );
  //                           },
  //                           child: Container(
  //                             width: 180,
  //                             margin: const EdgeInsets.only(right: 16),
  //                             decoration: BoxDecoration(
  //                               color: Colors.white,
  //                               borderRadius: BorderRadius.circular(16),
  //                               boxShadow: [
  //                                 BoxShadow(
  //                                   color: Colors.black.withOpacity(0.1),
  //                                   blurRadius: 6,
  //                                   offset: const Offset(0, 3),
  //                                 ),
  //                               ],
  //                             ),
  //                             child: Column(
  //                               crossAxisAlignment: CrossAxisAlignment.start,
  //                               children: [
  //                                 ClipRRect(
  //                                   borderRadius: const BorderRadius.vertical(
  //                                       top: Radius.circular(16)),
  //                                   child: SizedBox(
  //                                     width: 180,
  //                                     height: 140,
  //                                     child: Image.network(
  //                                       item.imageUrl,
  //                                       fit: BoxFit.cover,
  //                                       loadingBuilder: (BuildContext context,
  //                                           Widget child,
  //                                           ImageChunkEvent? loadingProgress) {
  //                                         if (loadingProgress == null) return child;
  //                                         return Container(
  //                                           color: Colors.grey[200],
  //                                           child: Center(
  //                                             child: CircularProgressIndicator(
  //                                               value: loadingProgress
  //                                                   .expectedTotalBytes !=
  //                                                   null
  //                                                   ? loadingProgress
  //                                                   .cumulativeBytesLoaded /
  //                                                   loadingProgress
  //                                                       .expectedTotalBytes!
  //                                                   : null,
  //                                             ),
  //                                           ),
  //                                         );
  //                                       },
  //                                       errorBuilder: (BuildContext context,
  //                                           Object error, StackTrace? stackTrace) {
  //                                         return Container(
  //                                           color: Colors.grey[200],
  //                                           child: const Center(
  //                                             child: Icon(Icons.fastfood,
  //                                                 color: Colors.grey),
  //                                           ),
  //                                         );
  //                                       },
  //                                     ),
  //                                   ),
  //                                 ),
  //                                 Padding(
  //                                   padding: const EdgeInsets.all(12),
  //                                   child: Column(
  //                                     crossAxisAlignment:
  //                                     CrossAxisAlignment.start,
  //                                     children: [
  //                                       Text(
  //                                         item.name,
  //                                         style: const TextStyle(
  //                                           fontWeight: FontWeight.bold,
  //                                           fontSize: 16,
  //                                         ),
  //                                         maxLines: 1,
  //                                         overflow: TextOverflow.ellipsis,
  //                                       ),
  //                                       const SizedBox(height: 6),
  //                                       Text(
  //                                         'QAR ${item.price.toStringAsFixed(2)}',
  //                                         style: TextStyle(
  //                                           color: AppColors.primaryBlue,
  //                                           fontWeight: FontWeight.bold,
  //                                           fontSize: 16,
  //                                         ),
  //                                       ),
  //                                       if (item.tags['isSpicy'] == true)
  //                                         Padding(
  //                                           padding: const EdgeInsets.only(top: 6),
  //                                           child: Row(
  //                                             children: [
  //                                               const Icon(
  //                                                 Icons.local_fire_department_rounded,
  //                                                 color: Colors.red,
  //                                                 size: 16,
  //                                               ),
  //                                               const SizedBox(width: 4),
  //                                               Text(
  //                                                 'Spicy',
  //                                                 style: TextStyle(
  //                                                   color: Colors.red,
  //                                                   fontSize: 14,
  //                                                   fontWeight: FontWeight.w500,
  //                                                 ),
  //                                               ),
  //                                             ],
  //                                           ),
  //                                         ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                               ],
  //                             ),
  //                           ),
  //                         );
  //                       },
  //                     ),
  //                   ),
  //                   const SizedBox(height: 8),
  //                 ],
  //               );
  //             },
  //           ),
  //
  //         // Show "All The Dishes" title only when no category is selected
  //         if (_selectedCategoryIndex == -1)
  //           const Padding(
  //             padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
  //             child: Align(
  //               alignment: Alignment.centerLeft,
  //               child: Text(
  //                 'All The Dishes',
  //                 style: TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ),
  //
  //         // Main dishes list - shows all when no category selected, or filtered when category selected
  //         StreamBuilder<QuerySnapshot>(
  //           stream: _selectedCategoryIndex == -1
  //               ? _firestore
  //               .collection('menu_items')
  //               .where('branchId', isEqualTo: _currentBranchId)
  //               .where('isAvailable', isEqualTo: true)
  //               .orderBy('sortOrder')
  //               .snapshots()
  //               : _firestore
  //               .collection('menu_items')
  //               .where('branchId', isEqualTo: _currentBranchId)
  //               .where('categoryId', isEqualTo: _categories[_selectedCategoryIndex].id)
  //               .where('isAvailable', isEqualTo: true)
  //               .orderBy('sortOrder')
  //               .snapshots(),
  //           builder: (context, snapshot) {
  //             if (snapshot.hasError) {
  //               return Center(child: Text('Error: ${snapshot.error}'));
  //             }
  //
  //             if (snapshot.connectionState == ConnectionState.waiting) {
  //               return const Center(child: CircularProgressIndicator());
  //             }
  //
  //             final items = snapshot.data!.docs
  //                 .map((doc) => MenuItem.fromFirestore(doc))
  //                 .where((item) => item.name.toLowerCase().contains(searchQuery.toLowerCase()))
  //                 .toList();
  //
  //             if (items.isEmpty) {
  //               return Center(
  //                 child: Column(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
  //                     const SizedBox(height: 16),
  //                     const Text('No items found', style: TextStyle(fontSize: 18)),
  //                     const SizedBox(height: 8),
  //                     Text(
  //                       'Try adjusting your search or filters',
  //                       style: TextStyle(color: Colors.grey[600], fontSize: 14),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             }
  //
  //             return ListView.builder(
  //               physics: const NeverScrollableScrollPhysics(),
  //               shrinkWrap: true,
  //               padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  //               itemCount: items.length,
  //               itemBuilder: (_, index) => MenuItemCard(item: items[index]),
  //             );
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }


}

class MenuItem {
  final String id;
  final String branchId;
  final String categoryId;
  final String description;
  final String imageUrl;
  final bool isAvailable;
  final bool isPopular;
  final String name;
  final double price;
  final int sortOrder;
  final Map<String, dynamic> tags;
  final Map<String, dynamic> variants;

  MenuItem({
    required this.id,
    required this.branchId,
    required this.categoryId,
    required this.description,
    required this.imageUrl,
    required this.isAvailable,
    required this.isPopular,
    required this.name,
    required this.price,
    required this.sortOrder,
    required this.tags,
    required this.variants,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      branchId: data['branchId'] ?? '',
      categoryId: data['categoryId'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      isPopular: data['isPopular'] ?? false,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      sortOrder: data['sortOrder'] ?? 0,
      tags: data['tags'] ?? {},
      variants: data['variants'] ?? {},
    );
  }
}

class MenuCategory {
  final String id;
  final String branchId;
  final String imageUrl;
  final bool isActive;
  final String name;
  final int sortOrder;

  MenuCategory({
    required this.id,
    required this.branchId,
    required this.imageUrl,
    required this.isActive,
    required this.name,
    required this.sortOrder,
  });

  factory MenuCategory.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return MenuCategory(
      id: doc.id,
      branchId: data['branchId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      isActive: data['isActive'] ?? false,
      name: data['name'] ?? '',
      sortOrder: data['sortOrder'] ?? 0,
    );
  }
}class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoginMode = true; // True for login, false for sign up
  bool _isLoading = false;
  String? _errorMessage;

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }


  Future<void> _authenticate() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    if (_isLoginMode) {
      // Login
      await _authService.signIn(_emailController.text.trim(), _passwordController.text.trim());
    } else {
      // Sign Up
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        throw Exception('Name and Phone are required for sign up.');
      }
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        _phoneController.text.trim(),
      );
    }
    // Navigate to Home Screen on success
    // The StreamBuilder in main.dart will now handle navigation after successful login/signup
  } on FirebaseAuthException catch (e) {
    setState(() {
      _errorMessage = e.message;
    });
    _showErrorDialog(e.message ?? 'An unknown Firebase error occurred.');
  } catch (e) {
    setState(() {
      _errorMessage = e.toString().replaceFirst('Exception: ', ''); // Clean up 'Exception: ' prefix
    });
    _showErrorDialog(_errorMessage ?? 'An unknown error occurred.');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String labelText,
  required IconData icon,
  bool obscureText = false,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.lightGrey,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          spreadRadius: 2,
          blurRadius: 5,
          offset: const Offset(0, 3),
        ),
      ],
    ),


    child: TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppColors.darkGrey),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      style: AppTextStyles.bodyText1,
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.white,
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo/Icon
            Icon(
              Icons.fastfood,
              size: 120,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 30),
            Text(
              _isLoginMode ? 'Welcome Back!' : 'Join Punjabi Bites!',
              style: AppTextStyles.headline1.copyWith(color: AppColors.primaryBlue),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _isLoginMode ? 'Login to continue your delicious journey.' : 'Sign up to explore authentic Punjabi flavors.',
              style: AppTextStyles.bodyText1.copyWith(color: AppColors.darkGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Name and Phone fields for Sign Up mode
            if (!_isLoginMode) ...[
              _buildTextField(
                controller: _nameController,
                labelText: 'Name',
                icon: Icons.person,
              ),
              _buildTextField(
                controller: _phoneController,
                labelText: 'Phone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
            ],

            // Email and Password fields
            _buildTextField(
              controller: _emailController,
              labelText: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            _buildTextField(
              controller: _passwordController,
              labelText: 'Password',
              icon: Icons.lock,
              obscureText: true,
            ),
            const SizedBox(height: 30),

            // Login/Sign Up Button
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                : ElevatedButton(
              onPressed: _authenticate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
                shadowColor: AppColors.primaryBlue.withOpacity(0.5),
              ),
              child: Text(
                _isLoginMode ? 'Login' : 'Sign Up',
                style: AppTextStyles.buttonText,
              ),
            ),
            const SizedBox(height: 20),

            // Toggle between Login and Sign Up
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoginMode = !_isLoginMode;
                  _errorMessage = null; // Clear error message when switching modes
                });
              },
              child: Text(
                _isLoginMode
                    ? 'Don\'t have an account? Sign Up'
                    : 'Already have an account? Login',
                style: AppTextStyles.bodyText1.copyWith(color: AppColors.primaryBlue),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class CartModel {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  int quantity;
  final Map<String, dynamic> variants;
  final List<String>? addons;

  CartModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.quantity = 1,
    this.variants = const {},
    this.addons,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'quantity': quantity,
      'variants': variants,
      'addons': addons,
    };
  }

  factory CartModel.fromMap(Map<String, dynamic> map) {
    return CartModel(
      id: map['id'],
      name: map['name'],
      imageUrl: map['imageUrl'],
      price: map['price'].toDouble(),
      quantity: map['quantity'],
      variants: map['variants'] ?? {},
      addons: map['addons'] != null ? List<String>.from(map['addons']) : null,
    );
  }
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal() {
    _loadCartFromPrefs();
  }

  final List<CartModel> _items = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CartModel> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount => _items.fold(0, (sum, item) => sum + item.totalPrice);

  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');

      if (cartJson != null) {
        final List<dynamic> cartData = json.decode(cartJson);
        _items.clear();
        _items.addAll(cartData.map((item) => CartModel.fromMap(item)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart from SharedPreferences: $e');
    }
  }

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_items.map((item) => item.toMap()).toList());
      await prefs.setString('cart_items', cartJson);
    } catch (e) {
      debugPrint('Error saving cart to SharedPreferences: $e');
    }
  }

  Future<void> addToCart(MenuItem menuItem, {int quantity = 1, Map<String, dynamic>? variants, List<String>? addons}) async {
    final existingIndex = _items.indexWhere((item) => item.id == menuItem.id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartModel(
        id: menuItem.id,
        name: menuItem.name,
        imageUrl: menuItem.imageUrl,
        price: menuItem.price,
        quantity: quantity,
        variants: variants ?? {},
        addons: addons,
      ));
    }

    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<void> removeFromCart(String itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<void> updateQuantity(String itemId, int newQuantity) async {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      if (newQuantity > 0) {
        _items[index].quantity = newQuantity;
      } else {
        _items.removeAt(index);
      }
    }
    notifyListeners();
    await _saveCartToPrefs();
  }

  Future<void> clearCart() async {
    _items.clear();
    notifyListeners();
    await _saveCartToPrefs();
  }
}




class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  String _estimatedTime = 'Loading...';
  final String _currentBranchId = 'Old_Airport';

  bool _isLoading = false;
  bool _isCheckingOut = false;
  TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEstimatedTime();

    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    setState(() => _isLoading = false);
  }
  Future<void> _loadEstimatedTime() async {
    final time = await _restaurantService.getEstimatedTime(_currentBranchId);
    if (mounted) {
      setState(() => _estimatedTime = time);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Widget _buildTimeEstimate() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [

          Text(
            'Estimated preparation: $_estimatedTime',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, child) {
        final cartService = CartService();
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('My Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )),
            backgroundColor: AppColors.primaryBlue,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (cartService.items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _showClearCartDialog(cartService),
                ),
            ],
          ),
          body: _buildBody(cartService),

          bottomNavigationBar: cartService.items.isNotEmpty
              ? _buildCheckoutBar(cartService)
              : null,
        );
      },
    );
  }

  Widget _buildBody(CartService cartService) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryBlue,
        ),
      );
    }

    if (cartService.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 100, color: AppColors.primaryBlue.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              'Your Order is Empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Browse our menu and add delicious items to get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text(
                'View Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Restaurant Info Card with StreamBuilder
        // In the _buildBody method, replace the StreamBuilder with:
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(FirebaseAuth.instance.currentUser?.email)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                color: AppColors.primaryBlue.withOpacity(0.1),
                child: const Text('Loading address...'),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final addresses = userData?['address'] as List<dynamic>? ?? [];
            final defaultAddress = addresses.firstWhere(
                  (a) => a['isDefault'] == true,
              orElse: () => addresses.isNotEmpty ? addresses.first : null,
            );

            final addressText = defaultAddress != null
                ? '${defaultAddress['street']}, ${defaultAddress['city']}'
                : 'No address set';

            return GestureDetector(
              onTap: _showAddressBottomSheet,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                color: AppColors.primaryBlue.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.store, color: AppColors.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OUR LOCATION',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            addressText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Delivery Time Estimate
        // Delivery Time Estimate
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _buildTimeEstimate(),
                ],
              ),
            ],
          ),
        ),

        // Order Items List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100, top: 8),
            children: [
              ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: cartService.items.length,
                separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final item = cartService.items[index];
                  return _buildCartItem(item, cartService);
                },
              ),

              // Notes for Restaurant Section
              _buildNotesSection(),
            ],
          ),
        ),
      ],
    );
  }
  void _showAddressBottomSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.email)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final addresses = (userData?['address'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Delivery Address',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (addresses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No addresses saved yet'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: addresses.length,
                        itemBuilder: (context, index) {
                          final address = addresses[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                address['label'] == 'Home'
                                    ? Icons.home
                                    : Icons.work,
                                color: AppColors.primaryBlue,
                              ),
                              title: Text(address['label']),
                              subtitle: Text('${address['street']}, ${address['city']}'),
                              trailing: address['isDefault'] == true
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                // Update the UI with selected address
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${address['label']} selected for delivery'),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavedAddressesScreen(),
                          ),
                        );
                      },
                      child: const Text('Manage Addresses'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildCartItem(CartModel item, CartService cartService) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        cartService.removeFromCart(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} removed from order'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                cartService.addToCart(
                  MenuItem(
                    id: item.id,
                    branchId: '',
                    categoryId: '',
                    description: '',
                    imageUrl: item.imageUrl,
                    isAvailable: true,
                    isPopular: false,
                    name: item.name,
                    price: item.price,
                    sortOrder: 0,
                    tags: {},
                    variants: {},
                  ),
                  quantity: item.quantity,
                );
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.fastfood,
                      color: AppColors.primaryBlue.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'QAR ${item.totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (item.addons != null && item.addons!.isNotEmpty) ...[
                      Text(
                        'Add-ons: ${item.addons!.join(', ')}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Quantity selector
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primaryBlue),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.remove, size: 18, color: AppColors.primaryBlue),
                            onPressed: () {
                              if (item.quantity > 1) {
                                cartService.updateQuantity(item.id, item.quantity - 1);
                              } else {
                                cartService.removeFromCart(item.id);
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            item.quantity.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primaryBlue),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add, size: 18, color: AppColors.primaryBlue),
                            onPressed: () {
                              cartService.updateQuantity(item.id, item.quantity + 1);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            'Special Instructions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add notes for the restaurant (allergies, preferences, etc.)',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'e.g. "No onions", "Extra spicy", "Allergy: peanuts"',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(CartService cartService) {
    final double subtotal = cartService.totalAmount;
    final double tax = subtotal * 0.10;
    final double total = subtotal + tax;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order Summary
          InkWell(
            onTap: () => _showOrderSummary(cartService),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${cartService.itemCount} ITEMS IN ORDER',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'QAR ${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Notes preview if they exist
          if (_notesController.text.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.note, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: ${_notesController.text}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryBlue,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // Total Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'QAR ${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),

          // Checkout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCheckingOut ? null : _proceedToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isCheckingOut
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'PLACE ORDER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(CartService cartService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Order?'),
        content: const Text('Are you sure you want to remove all items from your order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartService.clearCart();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order cleared'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: Text(
              'Clear',
              style: TextStyle(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderSummary(CartService cartService) {
    final double subtotal = cartService.totalAmount;
    final double tax = subtotal * 0.10;
    final double total = subtotal + tax;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Order items
              _buildBillRow('Subtotal', subtotal),
              _buildBillRow('Tax (10%)', tax),
              const Divider(height: 24),
              _buildBillRow('Total Amount', total, isTotal: true),

              // Display notes if they exist
              if (_notesController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Special Instructions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _notesController.text,
                  style: const TextStyle(fontSize: 14),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBillRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isTotal ? Colors.black : Colors.grey,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'QAR ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              color: isTotal ? Colors.black : Colors.grey,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToCheckout() async {
    final String notes = _notesController.text.trim();
    setState(() => _isCheckingOut = true);

    try {
      final cartItems = CartService().items;
      final subtotal = CartService().totalAmount;
      final tax = subtotal * 0.10;
      final total = subtotal + tax;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception("User not found");

      // Get the user's default address
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.email)
          .get();

      if (!userDoc.exists) throw Exception("User document not found");

      final userData = userDoc.data() as Map<String, dynamic>;
      final String userName = userData['name'] ?? 'No name provided';
      final String userPhone = userData['phone'] ?? 'No phone provided';
      final addresses = (userData['address'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final Map<String, dynamic> defaultAddress = addresses.firstWhere(
            (a) => a['isDefault'] == true,
        // here we’re sure addresses.first exists, so we don’t return null
        orElse: () => addresses.first,
      );


      if (defaultAddress == null) {
        throw Exception("No delivery address set");
      }

      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final DocumentReference counterRef = FirebaseFirestore.instance
          .collection('daily_counters')
          .doc(today);
      final DocumentReference orderDoc = FirebaseFirestore.instance
          .collection('Orders')
          .doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);

        int dailyCount = 1;
        if (counterSnap.exists) {
          dailyCount = (counterSnap.get('count') as int) + 1;
          transaction.update(counterRef, {'count': dailyCount});
        } else {
          transaction.set(counterRef, {'count': 1});
        }

        final paddedOrderNumber = dailyCount.toString().padLeft(3, '0');
        final String orderId = 'FD-$today-$paddedOrderNumber';

        final List<Map<String, dynamic>> items = cartItems.map((item) => {
          'itemId': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'variants': item.variants,
          'addons': item.addons,
          'total': item.totalPrice,
        }).toList();

        final orderData = {
          'orderId': orderId,
          'dailyOrderNumber': dailyCount,
          'date': today,
          'customerId': user.email,
          'items': items,
          'customerName': userName,  // Added user's name
          'customerPhone': userPhone,  // Added user's phone
          'notes': notes,
          'status': 'pending',
          'subtotal': subtotal,
          'tax': tax,
          'totalAmount': total,
          'timestamp': FieldValue.serverTimestamp(),
          'Order_type': 'delivery',
          'deliveryAddress': {
            'street': defaultAddress['street'],
            'city': defaultAddress['city'],
            'label': defaultAddress['label'],
            'geolocation': defaultAddress['geolocation'],
          },
          'riderId': '',
          'riderPaymentAmount': '',
        };

        transaction.set(orderDoc, orderData);
      });

      CartService().clearCart();
      _notesController.clear();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: AppColors.primaryBlue, size: 60),
              const SizedBox(height: 16),
              const Text('Order Confirmed!', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your order has been placed successfully',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Back to Menu', style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    } finally {
      setState(() => _isCheckingOut = false);
    }
  }
}



class MenuItemCard extends StatefulWidget {
  final MenuItem item;

  const MenuItemCard({Key? key, required this.item}) : super(key: key);

  @override
  _MenuItemCardState createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool _isFavorite = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      final doc = await _firestore.collection('Users').doc(user.email).get();
      if (doc.exists && mounted) {
        final favorites = doc.data()?['favorites'] as Map<String, dynamic>? ?? {};
        setState(() {
          _isFavorite = favorites.containsKey(widget.item.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking favorites: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      await _firestore.collection('Users').doc(user.email).set({
        'favorites': {
          widget.item.id: _isFavorite ? _createFavoriteItemMap() : FieldValue.delete(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite; // Revert on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorites: ${e.toString()}')),
        );
      }
    }
  }

  Map<String, dynamic> _createFavoriteItemMap() {
    return {
      'id': widget.item.id,
      'name': widget.item.name,
      'imageUrl': widget.item.imageUrl,
      'price': widget.item.price,
      'description': widget.item.description,
      'isSpicy': widget.item.tags['isSpicy'] ?? false,
      'addedAt': FieldValue.serverTimestamp(),
    };
  }

  void _updateQuantity(int newQuantity, CartService cartService) {
    if (newQuantity > 0) {
      cartService.updateQuantity(widget.item.id, newQuantity);
    } else {
      cartService.removeFromCart(widget.item.id);
    }
  }

  void _addItemToCart(MenuItem item, CartService cartService) {
    cartService.addToCart(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, child) {
        final cartService = CartService();
        final index = cartService.items.indexWhere((i) => i.id == widget.item.id);
        final itemCount = index != -1 ? cartService.items[index].quantity : 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
              // In the MenuItemCard widget, update the onTap handler for the main card:
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => DishDetailsBottomSheet(item: widget.item),
                );
              },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.item.tags['isSpicy'] == true)
                              const Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: Icon(
                                      Icons.local_fire_department_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Spicy',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            Text(
                              widget.item.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'QAR ${widget.item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.item.description,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          if (widget.item.imageUrl.isNotEmpty)
                            Stack(
                              children: [
                                Container(
                                  width: 150,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(widget.item.imageUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: itemCount > 0
                                        ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          iconSize: 20,
                                          onPressed: () {
                                            _updateQuantity(itemCount - 1, cartService);
                                          },
                                        ),
                                        Text(
                                          itemCount.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          iconSize: 20,
                                          onPressed: () {
                                            _updateQuantity(itemCount + 1, cartService);
                                          },
                                        ),
                                      ],
                                    )
                                        : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                      ),
                                      onPressed: () {
                                        _addItemToCart(widget.item, cartService);
                                      },
                                      child: const Text(
                                        'ADD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 5),
                          const Text(
                            'customisable',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Row(
                      children: [
                        IconButton(
                          iconSize: 20,
                          padding: const EdgeInsets.all(4),
                          icon: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : AppColors.primaryBlue,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                        IconButton(
                          iconSize: 20,
                          padding: const EdgeInsets.all(4),
                          icon: Icon(Icons.share, color: AppColors.primaryBlue),
                          onPressed: () {
                            // Handle share action
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}



class DishDetailsBottomSheet extends StatefulWidget {
  final MenuItem item;

  const DishDetailsBottomSheet({Key? key, required this.item}) : super(key: key);

  @override
  _DishDetailsBottomSheetState createState() => _DishDetailsBottomSheetState();
}

class _DishDetailsBottomSheetState extends State<DishDetailsBottomSheet> {
  int _quantity = 1;
  final CartService _cartService = CartService();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 60,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Dish image
          Container(
            width: double.infinity,
            height: 180,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[100],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: widget.item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryBlue,
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.fastfood,
                  color: Colors.grey[400],
                  size: 40,
                ),
              )
                  : Icon(
                Icons.fastfood,
                color: Colors.grey[400],
                size: 40,
              ),
            ),
          ),

          // Dish name and price
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'QAR ${widget.item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),

          // Spicy indicator
          if (widget.item.tags['isSpicy'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.red[400],
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Spicy',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
            child: Text(
              widget.item.description.isNotEmpty
                  ? widget.item.description
                  : 'No description available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),

          // Quantity selector and Add to Cart button
          Row(
            children: [
              // Quantity selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: Colors.grey[700]),
                      onPressed: () {
                        if (_quantity > 1) {
                          setState(() => _quantity--);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          _quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.grey[700]),
                      onPressed: () => setState(() => _quantity++),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Add to Cart button
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: ElevatedButton(
                  onPressed: () {
                    _cartService.addToCart(widget.item, quantity: _quantity);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_quantity}x ${widget.item.name} added to cart',
                          style: const TextStyle(fontSize: 14),
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final List<String> images;
  const ImageCarousel({Key? key, required this.images}) : super(key: key);

  @override
  _ImageCarouselState createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late final PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  // you can also make this configurable via widget.height if you prefer

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // cycle every 4 seconds
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (widget.images.isEmpty) return;
      _currentPage = (_currentPage + 1) % widget.images.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      setState(() {}); // only rebuild this carousel
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return SizedBox(
        // height: 280,
        child: Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // <-- increased height here -->
        Container(
          // height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            allowImplicitScrolling: true,
            itemBuilder: (ctx, i) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),

        // gradient overlay also needs the same height
        IgnorePointer(
          child: Container(
            // height: 280,  // <-- and here
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              ),
            ),
          ),
        ),

        // indicators
        if (widget.images.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> getEstimatedTime(String branchId) async {
    try {
      final doc = await _firestore.collection('Branch').doc(branchId).get();
      if (doc.exists) {
        final data = doc.data();
        return '${data?['estimatedTime'] ?? 40} minutes'; // Default to 40 if not found
      }
      return '40 minutes'; // Default if document doesn't exist
    } catch (e) {
      debugPrint('Error getting estimated time: $e');
      return '40 minutes'; // Default on error
    }
  }
}