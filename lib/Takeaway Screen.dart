import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'main.dart';




class TakeAwayScreen extends StatefulWidget {
  const TakeAwayScreen({Key? key}) : super(key: key);

  @override
  State<TakeAwayScreen> createState() => _TakeAwayScreenState();
}

class _TakeAwayScreenState extends State<TakeAwayScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentBranchId = 'Old_Airport';
  String _estimatedTime = 'Loading...';

  int _selectedCategoryIndex = 0;
  List<MenuCategory> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TakeAwayCartService _takeAwayCartService = TakeAwayCartService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadEstimatedTime();
    _takeAwayCartService.loadCartFromPrefs();
  }

  Future<void> _loadEstimatedTime() async {
    try {
      final time = await _restaurantService.getEstimatedTime(_currentBranchId);
      if (mounted) {
        setState(() => _estimatedTime = time);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estimatedTime = '40 min');
      }
    }
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
          'Take Away',
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
                            'Ready in $_estimatedTime',
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
              listenable: _takeAwayCartService,
              builder: (context, child) {
                return _takeAwayCartService.items.isEmpty
                    ? const SizedBox.shrink()
                    : _buildTakeAwayCartBar();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
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
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildMenuItemCard(items[index]),
        );
      },
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {

    return ListenableBuilder(
      listenable: _takeAwayCartService,
      builder: (context, child) {
        final cartItem = _takeAwayCartService.items.firstWhere(
              (cartItem) => cartItem.id == item.id,
          orElse: () => CartModel(
            id: '',
            name: '',
            imageUrl: '',
            price: 0,
            quantity: 0,
          ), // Return empty CartModel instead of null
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
                      onPressed: () => _takeAwayCartService.addToCart(item),
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
  Widget _buildTakeAwayCartBar() {
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
            label: Text('${_takeAwayCartService.itemCount}'),
            backgroundColor: AppColors.primaryBlue,
            textColor: Colors.white,
            child: const Icon(Icons.shopping_bag_outlined, size: 30),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Take Away Order',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'QAR ${_takeAwayCartService.totalAmount.toStringAsFixed(2)}',
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
                  builder: (context) => TakeAwayCartScreen(
                    cartService: _takeAwayCartService,
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

  void _showItemDetails(MenuItem item) {
    final isInCart = _takeAwayCartService.items.any((cartItem) => cartItem.id == item.id);

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
                        _takeAwayCartService.removeFromCart(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Removed ${item.name} from order'),
                          ),
                        );
                      } else {
                        _takeAwayCartService.addToCart(item);
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
                      isInCart ? 'Remove from Order' : 'Add to Take Away Order',
                      style: const TextStyle(fontSize: 16),
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
                // Implement search functionality
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
class TakeAwayMenuItemCard extends StatefulWidget {
  final MenuItem item;
  final TakeAwayCartService cartService;

  const TakeAwayMenuItemCard({
    Key? key,
    required this.item,
    required this.cartService,
  }) : super(key: key);

  @override
  State<TakeAwayMenuItemCard> createState() => _TakeAwayMenuItemCardState();
}

class _TakeAwayMenuItemCardState extends State<TakeAwayMenuItemCard> {
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

  void _updateQuantity(int newQuantity) {
    if (newQuantity > 0) {
      widget.cartService.updateQuantity(widget.item.id, newQuantity);
    } else {
      widget.cartService.removeFromCart(widget.item.id);
    }
  }

  void _addItemToCart(MenuItem item) {
    widget.cartService.addToCart(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to take away order'),
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
    final index = widget.cartService.items.indexWhere((i) => i.id == widget.item.id);
    final itemCount = index != -1 ? widget.cartService.items[index].quantity : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
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
                                        _updateQuantity(itemCount - 1);
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
                                        _updateQuantity(itemCount + 1);
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
                                    _addItemToCart(widget.item);
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
  }
}

class TakeAwayCartService extends ChangeNotifier {
  final List<CartModel> _items = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CartModel> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount => _items.fold(0, (sum, item) => sum + item.totalPrice);

  Future<void> loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('takeaway_cart_items');

      if (cartJson != null) {
        final List<dynamic> cartData = json.decode(cartJson);
        _items.clear();
        _items.addAll(cartData.map((item) => CartModel.fromMap(item)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading takeaway cart from SharedPreferences: $e');
    }
  }

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_items.map((item) => item.toMap()).toList());
      await prefs.setString('takeaway_cart_items', cartJson);
    } catch (e) {
      debugPrint('Error saving takeaway cart to SharedPreferences: $e');
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
    notifyListeners(); // Make sure this is called
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
    notifyListeners(); // Make sure this is called
    await _saveCartToPrefs();
  }
}

class TakeAwayCartScreen extends StatefulWidget {
  final TakeAwayCartService cartService;

  const TakeAwayCartScreen({Key? key, required this.cartService}) : super(key: key);

  @override
  State<TakeAwayCartScreen> createState() => _TakeAwayCartScreenState();
}

class _TakeAwayCartScreenState extends State<TakeAwayCartScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  String _estimatedTime = 'Loading...';
  final String _currentBranchId = 'Old_Airport';

  bool _isLoading = false;
  bool _isCheckingOut = false;
  String? _selectedPickupType;
  TextEditingController _carNumberController = TextEditingController();
  TextEditingController _carModelController = TextEditingController();
  TextEditingController _carColorController = TextEditingController();
  TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEstimatedTime();
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
    _carNumberController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
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

  Widget _buildPickupTypeSection() {
    // Initialize with Walk-In selected if no selection exists
    _selectedPickupType ??= 'walk_in';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT PICKUP METHOD',
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
            child: Column(
              children: [
                // Pickup Type Toggle
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _selectedPickupType = 'walk_in';
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _selectedPickupType == 'walk_in'
                                  ? AppColors.primaryBlue
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: _selectedPickupType == 'walk_in'
                                  ? Border.all(
                                  color: AppColors.primaryBlue.withOpacity(0.2),
                                  width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_walk,
                                    color: _selectedPickupType == 'walk_in'
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'WALK-IN',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedPickupType == 'walk_in'
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _selectedPickupType = 'by_car';
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _selectedPickupType == 'by_car'
                                  ? AppColors.primaryBlue
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: _selectedPickupType == 'by_car'
                                  ? Border.all(
                                  color: AppColors.primaryBlue.withOpacity(0.2),
                                  width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    color: _selectedPickupType == 'by_car'
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'BY CAR',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedPickupType == 'by_car'
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Car Details Form (animated)
                // Added SingleChildScrollView here to prevent pixel overflow
                if (_selectedPickupType == 'by_car') // Conditional rendering of the scroll view
                  SingleChildScrollView(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text(
                                'CAR DETAILS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStyledTextField(
                            controller: _carNumberController,
                            label: 'Car Number Plate',
                            icon: Icons.confirmation_number,
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStyledTextField(
                            controller: _carModelController,
                            label: 'Car Model',
                            icon: Icons.directions_car,
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),
                          _buildStyledTextField(
                            controller: _carColorController,
                            label: 'Car Color',
                            icon: Icons.color_lens,
                            isRequired: true,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRequired)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isRequired ? null : label,
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cartService,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Take Away Order',
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
            Icon(Icons.shopping_cart_outlined,
                size: 100, color: AppColors.primaryBlue.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              'Your Take Away Order is Empty',
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
                Navigator.of(context).pop();
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

    // PASTE THE NEW COLUMN WIDGET HERE (replacing the old one)
    return Column(
      children: [
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

        // Pickup Type Section
        _buildPickupTypeSection(),

        // Order Items List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100, top: 8),
            children: [
              ListView.separated(
                physics: NeverScrollableScrollPhysics(),
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

  Widget _buildCartItem(CartModel item) {
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
                widget.cartService.addToCart(
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

  Widget _buildCheckoutBar() {
    final double subtotal = widget.cartService.totalAmount;
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
                'PLACE TAKE AWAY ORDER',
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
  Future<void> _proceedToCheckout() async {
    if (_selectedPickupType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a pickup type')),
      );
      return;
    }

    if (_selectedPickupType == 'by_car' &&
        (_carNumberController.text.isEmpty ||
            _carModelController.text.isEmpty ||
            _carColorController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter all car details')),
      );
      return;
    }

    final String notes = _notesController.text.trim();
    setState(() => _isCheckingOut = true);

    try {
      final cartItems = widget.cartService.items;
      final subtotal = widget.cartService.totalAmount;
      final tax = subtotal * 0.10;
      final total = subtotal + tax;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception("User not found");

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
        final String orderId = 'TA-$today-$paddedOrderNumber';

        final List<Map<String, dynamic>> items = cartItems.map((item) => {
          'itemId': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'variants': item.variants,
          'addons': item.addons,
          'total': item.totalPrice,
        }).toList();

        // Add pickup details to order data
        final Map<String, dynamic> pickupDetails = {
          'type': _selectedPickupType,
        };

        if (_selectedPickupType == 'by_car') {
          pickupDetails['carNumber'] = _carNumberController.text;
          pickupDetails['carModel'] = _carModelController.text;
          pickupDetails['carColor'] = _carColorController.text;
        }

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
          'Order_type': 'take_away',
          'pickupDetails': pickupDetails, // Add pickup details to order
        };

        transaction.set(orderDoc, orderData);
      });

      // Clear the cart after successful order placement
      widget.cartService.clearCart();
      _notesController.clear();
      _carNumberController.clear();
      _carModelController.clear();
      _carColorController.clear();
      setState(() => _selectedPickupType = null);

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order placed successfully!'),
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


  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Order?'),
        content: const Text('Are you sure you want to remove all items from your take away order?'),
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
                  content: Text('Take away order cleared'),
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
                'Take Away Order Summary',
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


}
