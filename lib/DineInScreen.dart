import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// --- Placeholder Classes (Assumed to be in main.dart or a shared file) ---
// You should replace these with your actual definitions if they are elsewhere.

class AppColors {
  static const Color primaryBlue = Color(0xFF007BFF); // Example blue color
  static const Color accentOrange = Color(0xFFFF9800); // Example accent color
}

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> getEstimatedTime(String branchId) async {
    try {
      final doc = await _firestore.collection('restaurant_settings').doc(branchId).get();
      if (doc.exists && doc.data()!.containsKey('estimatedDineInTime')) {
        return doc.data()!['estimatedDineInTime'] as String;
      }
      return '25-30 min'; // Default if not found
    } catch (e) {
      debugPrint('Error fetching estimated time: $e');
      return '25-30 min'; // Fallback on error
    }
  }
}

class MenuCategory {
  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;

  MenuCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });

  factory MenuCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuCategory(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? false,
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  final String branchId;
  final bool isAvailable;
  final bool isPopular;
  final int sortOrder;
  final Map<String, dynamic> tags;
  final Map<String, dynamic> variants;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    required this.branchId,
    required this.isAvailable,
    required this.isPopular,
    required this.sortOrder,
    required this.tags,
    required this.variants,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
      categoryId: data['categoryId'] ?? '',
      branchId: data['branchId'] ?? '',
      isAvailable: data['isAvailable'] ?? false,
      isPopular: data['isPopular'] ?? false,
      sortOrder: data['sortOrder'] ?? 0,
      tags: Map<String, dynamic>.from(data['tags'] ?? {}),
      variants: Map<String, dynamic>.from(data['variants'] ?? {}),
    );
  }
}

class CartModel {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  int quantity;
  final Map<String, dynamic>? variants;
  final List<String>? addons;

  CartModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.quantity = 1,
    this.variants,
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
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['quantity'] ?? 0,
      variants: map['variants'] as Map<String, dynamic>?,
      addons: (map['addons'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}

// --- End Placeholder Classes ---


class DineInScreen extends StatefulWidget {
  const DineInScreen({Key? key}) : super(key: key);

  @override
  State<DineInScreen> createState() => _DineInScreenState();
}

class _DineInScreenState extends State<DineInScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Assuming a fixed branch ID for simplicity, or it could be passed dynamically
  final String _currentBranchId = 'Old_Airport';
  String _estimatedTime = 'Loading...'; // For general order preparation time

  int _selectedCategoryIndex = 0;
  List<MenuCategory> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  final DineInCartService _dineInCartService = DineInCartService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadEstimatedTime();
    _dineInCartService.loadCartFromPrefs(); // Load cart on init
  }

  /// Loads the estimated preparation time for dine-in orders from Firestore.
  Future<void> _loadEstimatedTime() async {
    try {
      final time = await _restaurantService.getEstimatedTime(_currentBranchId);
      if (mounted) {
        setState(() => _estimatedTime = time);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estimatedTime = '25-30 min'); // Fallback time
      }
    }
  }

  /// Loads menu categories from Firestore for the current branch.
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
          _categories = querySnapshot.docs
              .map((doc) => MenuCategory.fromFirestore(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load categories. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Dine In',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              // Preparation Time & Category Chips
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Order ready in $_estimatedTime', // General time for dine-in
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ChoiceChip(
                              label: Text(category.name),
                              selected: _selectedCategoryIndex == index,
                              selectedColor: AppColors.primaryBlue,
                              labelStyle: TextStyle(
                                color: _selectedCategoryIndex == index
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              avatar: category.imageUrl.isNotEmpty
                                  ? CircleAvatar(
                                backgroundImage: NetworkImage(category.imageUrl),
                              )
                                  : null,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryIndex = index;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Menu Items Grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _categories.isEmpty
                    ? const Center(child: Text('No categories available'))
                    : _buildMenuGrid(),
              ),
            ],
          ),

          // Persistent Cart Bar - Positioned at the bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ListenableBuilder(
              listenable: _dineInCartService,
              builder: (context, child) {
                return _dineInCartService.items.isEmpty
                    ? const SizedBox.shrink()
                    : _buildDineInCartBar();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the grid view for menu items based on the selected category.
  Widget _buildMenuGrid() {
    if (_categories.isEmpty) {
      return const Center(child: Text('No categories available.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('menu_items')
          .where('branchId', isEqualTo: _currentBranchId)
          .where('categoryId', isEqualTo: _categories[_selectedCategoryIndex].id)
          .where('isAvailable', isEqualTo: true)
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading menu items'));
        }

        final items = snapshot.data!.docs
            .map((doc) => MenuItem.fromFirestore(doc))
            .toList();

        if (items.isEmpty) {
          return const Center(child: Text('No items in this category'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75, // Adjust as needed for better card sizing
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildMenuItemCard(items[index]),
        );
      },
    );
  }

  /// Builds an individual menu item card.
  Widget _buildMenuItemCard(MenuItem item) {
    return ListenableBuilder(
      listenable: _dineInCartService,
      builder: (context, child) {
        final cartItem = _dineInCartService.items.firstWhere(
              (cartItem) => cartItem.id == item.id,
          orElse: () => CartModel(
            id: '',
            name: '',
            imageUrl: '',
            price: 0,
            quantity: 0,
          ), // Return empty CartModel if not found
        );
        final quantity = cartItem.id == item.id ? cartItem.quantity : 0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showItemDetails(item),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Food Image
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),

                    // Food Details
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 4),
                          Text(
                            'QAR ${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Quantity Indicator/Add Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: quantity > 0
                        ? Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          quantity.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                        : IconButton(
                      icon: Icon(Icons.add_circle,
                          color: AppColors.primaryBlue,
                          size: 32),
                      onPressed: () => _dineInCartService.addToCart(item),
                    ),
                  ),
                ),

                // Spicy Indicator
                if (item.tags['isSpicy'] == true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department,
                              size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Spicy',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the persistent cart bar at the bottom of the screen.
  Widget _buildDineInCartBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Badge(
            label: Text('${_dineInCartService.itemCount}'),
            backgroundColor: AppColors.primaryBlue,
            textColor: Colors.white,
            child: const Icon(Icons.restaurant_menu, size: 30), // Dine-in icon
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dine In Order',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'QAR ${_dineInCartService.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DineInCartScreen(
                    cartService: _dineInCartService,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('View Order', style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  /// Shows a modal bottom sheet with item details.
  void _showItemDetails(MenuItem item) {
    final isInCart = _dineInCartService.items.any((cartItem) => cartItem.id == item.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Ensure it takes minimum height
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (item.tags['isSpicy'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              'Spicy',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'QAR ${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isInCart) {
                        _dineInCartService.removeFromCart(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Removed ${item.name} from order'),
                          ),
                        );
                      } else {
                        _dineInCartService.addToCart(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${item.name} to order'),
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInCart ? Colors.red : AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isInCart ? 'Remove from Order' : 'Add to Dine In Order',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows a search dialog for menu items.
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        return AlertDialog(
          title: const Text('Search Menu'),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Search for dishes...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Implement search functionality here
                Navigator.pop(context);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }
}

class DineInCartService extends ChangeNotifier {
  final List<CartModel> _items = [];
  // Using a distinct key for dine-in cart in SharedPreferences
  static const String _prefsKey = 'dinein_cart_items';

  List<CartModel> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount => _items.fold(0, (sum, item) => sum + item.totalPrice);

  /// Loads the dine-in cart from SharedPreferences.
  Future<void> loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_prefsKey);

      if (cartJson != null) {
        final List<dynamic> cartData = json.decode(cartJson);
        _items.clear();
        _items.addAll(cartData.map((item) => CartModel.fromMap(item)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading dine-in cart from SharedPreferences: $e');
    }
  }

  /// Saves the current dine-in cart to SharedPreferences.
  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_items.map((item) => item.toMap()).toList());
      await prefs.setString(_prefsKey, cartJson);
    } catch (e) {
      debugPrint('Error saving dine-in cart to SharedPreferences: $e');
    }
  }

  /// Adds a menu item to the cart or increments its quantity if already present.
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

  /// Removes an item from the cart.
  Future<void> removeFromCart(String itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    notifyListeners();
    await _saveCartToPrefs();
  }

  /// Updates the quantity of a specific item in the cart.
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

  /// Clears all items from the cart.
  Future<void> clearCart() async {
    _items.clear();
    notifyListeners();
    await _saveCartToPrefs();
  }
}

class DineInCartScreen extends StatefulWidget {
  final DineInCartService cartService;

  const DineInCartScreen({Key? key, required this.cartService}) : super(key: key);

  @override
  State<DineInCartScreen> createState() => _DineInCartScreenState();
}

class _DineInCartScreenState extends State<DineInCartScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  String _estimatedTime = 'Loading...';
  final String _currentBranchId = 'Old_Airport'; // Consistent branch ID
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  bool _isLoading = false;
  bool _isCheckingOut = false;
  TextEditingController _notesController = TextEditingController();

  // New state variables for guests, number of tables, and time
  int? _selectedGuests;
  int? _selectedNumberOfTables; // Changed from String? _selectedTableNumber
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadEstimatedTime();
    _selectedTime = TimeOfDay.now(); // Initialize with current time
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Loads the estimated preparation time for the order.
  Future<void> _loadEstimatedTime() async {
    try {
      final time = await _restaurantService.getEstimatedTime(_currentBranchId);
      if (mounted) {
        setState(() => _estimatedTime = time);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estimatedTime = '25-30 min');
      }
    }
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

  Widget _buildTableDetailsSection() {
    // Example lists for dropdowns. In a real app, these might come from Firestore.
    final List<int> guestOptions = List.generate(10, (index) => index + 1); // 1 to 10 guests
    final List<int> numberOfTablesOptions = List.generate(5, (index) => index + 1); // 1 to 5 tables

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DINE-IN DETAILS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Number of Guests Dropdown
                  _buildDropdownField<int>(
                    value: _selectedGuests,
                    hintText: 'Number of Guests',
                    icon: Icons.people,
                    items: guestOptions.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value Guests'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedGuests = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Please select number of guests' : null,
                  ),
                  const SizedBox(height: 16),

                  // Number of Tables Dropdown
                  _buildDropdownField<int>( // Changed type to int
                    value: _selectedNumberOfTables, // Changed state variable
                    hintText: 'Number of Tables', // Changed hint text
                    icon: Icons.table_bar,
                    items: numberOfTablesOptions.map((int value) { // Changed options to int
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value Tables'), // Changed display text
                      );
                    }).toList(),
                    onChanged: (int? newValue) { // Changed onChanged parameter type
                      setState(() {
                        _selectedNumberOfTables = newValue; // Changed state variable
                      });
                    },
                    validator: (value) => value == null ? 'Please select number of tables' : null, // Changed validation message
                  ),
                  const SizedBox(height: 16),

                  // Time Picker
                  InkWell(
                    onTap: _selectTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Order Time',
                        prefixIcon: Icon(Icons.access_time, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primaryBlue,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                      child: Text(
                        _selectedTime?.format(context) ?? 'Select Time',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper for building styled dropdown fields.
  Widget _buildDropdownField<T>({
    required T? value,
    required String hintText,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    FormFieldValidator<T>? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      hint: Text(hintText),
      icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      dropdownColor: Colors.white,
    );
  }

  /// Shows the time picker and updates the selected time.
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cartService,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Dine In Order',
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
              if (widget.cartService.items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _showClearCartDialog(),
                ),
            ],
          ),
          body: _buildBody(),
          bottomNavigationBar: widget.cartService.items.isNotEmpty
              ? _buildCheckoutBar()
              : null,
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryBlue,
        ),
      );
    }

    if (widget.cartService.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu,
                size: 100, color: AppColors.primaryBlue.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              'Your Dine In Order is Empty',
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
                Navigator.of(context).pop(); // Go back to menu
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
        // Order Preparation Time Estimate
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

        // Table Details Section (updated)
        _buildTableDetailsSection(),

        // Order Items List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100, top: 8),
            children: [
              ListView.separated(
                physics: NeverScrollableScrollPhysics(), // Prevent inner scrolling
                shrinkWrap: true,
                itemCount: widget.cartService.items.length,
                separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final item = widget.cartService.items[index];
                  return _buildCartItem(item);
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

  /// Builds an individual cart item row with quantity controls and dismissible.
  Widget _buildCartItem(CartModel item) {
    return Dismissible(
      key: Key(item.id), // Unique key for Dismissible
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
        widget.cartService.removeFromCart(item.id);
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
                // Re-add the item if UNDO is pressed
                widget.cartService.addToCart(
                  MenuItem(
                    id: item.id,
                    branchId: '', // These can be empty for re-adding to cart
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
                                widget.cartService.updateQuantity(item.id, item.quantity - 1);
                              } else {
                                widget.cartService.removeFromCart(item.id);
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
                              widget.cartService.updateQuantity(item.id, item.quantity + 1);
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

  /// Builds the section for special notes to the restaurant.
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

  /// Builds the checkout bar at the bottom, showing total and checkout button.
  Widget _buildCheckoutBar() {
    final double subtotal = widget.cartService.totalAmount;
    final double tax = subtotal * 0.10; // Example 10% tax
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
            onTap: () => _showOrderSummary(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.cartService.itemCount} ITEMS IN ORDER',
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
                'PLACE DINE IN ORDER',
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

  /// Handles the checkout process, validating input and placing the order in Firestore.
  Future<void> _proceedToCheckout() async {
    if (_selectedGuests == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the number of guests')),
      );
      return;
    }
    if (_selectedNumberOfTables == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the number of tables')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an order time')),
      );
      return;
    }

    final String notes = _notesController.text.trim();
    setState(() => _isCheckingOut = true);

    try {
      final cartItems = widget.cartService.items;
      final subtotal = widget.cartService.totalAmount;
      final tax = subtotal * 0.10;
      final double total = subtotal + tax;

      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception("User not authenticated.");
      }

      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final DocumentReference counterRef = _firestore
          .collection('daily_counters')
          .doc(today);
      final DocumentReference orderDoc = _firestore
          .collection('Orders') // Store all orders in a single 'Orders' collection
          .doc();

      await _firestore.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);

        int dailyCount = 1;
        if (counterSnap.exists) {
          dailyCount = (counterSnap.get('count') as int) + 1;
          transaction.update(counterRef, {'count': dailyCount});
        } else {
          transaction.set(counterRef, {'count': 1});
        }

        final paddedOrderNumber = dailyCount.toString().padLeft(3, '0');
        final String orderId = 'DI-$today-$paddedOrderNumber'; // Dine-in prefix

        final List<Map<String, dynamic>> items = cartItems.map((item) => {
          'itemId': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'variants': item.variants,
          'addons': item.addons,
          'total': item.totalPrice,
        }).toList();

        // Format selected time for storage
        final DateTime now = DateTime.now();
        final DateTime selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        final orderData = {
          'orderId': orderId,
          'dailyOrderNumber': dailyCount,
          'date': today,
          'customerId': user.email,
          'items': items,
          'notes': notes,
          'status': 'pending',
          'subtotal': subtotal,
          'tax': tax,
          'totalAmount': total,
          'timestamp': FieldValue.serverTimestamp(),
          'Order_type': 'dine-in', // Explicitly mark as dine-in
          'numberOfGuests': _selectedGuests, // Add number of guests
          'numberOfTables': _selectedNumberOfTables, // Changed field name
          'orderTime': Timestamp.fromDate(selectedDateTime), // Add order time as Timestamp
          'branchId': _currentBranchId, // Add branch ID
        };

        transaction.set(orderDoc, orderData);
      });

      // Clear the cart after successful order placement
      widget.cartService.clearCart();
      _notesController.clear();
      setState(() {
        _selectedGuests = null;
        _selectedNumberOfTables = null; // Reset
        _selectedTime = TimeOfDay.now(); // Reset time
      });


      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst); // Go back to root
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dine In Order placed successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  /// Shows a confirmation dialog to clear the cart.
  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Order?'),
        content: const Text('Are you sure you want to remove all items from your dine in order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.cartService.clearCart();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                  content: Text('Dine in order cleared'),
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

  /// Shows a modal bottom sheet with the order summary.
  void _showOrderSummary() {
    final double subtotal = widget.cartService.totalAmount;
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Dine In Order Summary',
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

              // Display dine-in details
              const SizedBox(height: 16),
              const Text(
                'Dine-In Details:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedGuests != null)
                Text(
                  'Guests: $_selectedGuests',
                  style: const TextStyle(fontSize: 14),
                ),
              if (_selectedNumberOfTables != null) // Changed display
                Text(
                  'Tables: $_selectedNumberOfTables', // Changed display
                  style: const TextStyle(fontSize: 14),
                ),
              if (_selectedTime != null)
                Text(
                  'Time: ${_selectedTime!.format(context)}',
                  style: const TextStyle(fontSize: 14),
                ),

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

  /// Helper widget to build a row for bill details (e.g., Subtotal, Tax, Total).
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
}
