import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';


import 'main.dart';



class DineInScreen extends StatefulWidget {
  const DineInScreen({Key? key}) : super(key: key);

  @override
  State<DineInScreen> createState() => _DineInScreenState();
}

class _DineInScreenState extends State<DineInScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentBranchId = 'Old_Airport';
  final DineInCartService _dineInCartService = DineInCartService();


  int _selectedCategoryIndex = 0;
  int _selectedTableNumber = 0;
  List<MenuCategory> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTable = 0;
  final List<int> _availableTables = List.generate(20, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _dineInCartService.loadCartFromPrefs();
    _loadTables(); // Add this li
  }

  // Replace the existing table-related variables with these:
  List<Map<String, dynamic>> _tables = [];

// Update the initState to load tables


// Add this new method to load tables from Firestore
  Future<void> _loadTables() async {
    try {
      // Get just the Old_Airport document:
      final doc = await _firestore
          .collection('Tables')
          .doc('Old_Airport')
          .get();

      // The data() is a Map<String, dynamic> where keys are "T01", "T02"…
      final data = doc.data() ?? {};

      setState(() {
        _tables = data.entries.map((e) {
          // e.key is "T01", e.value is the map { isAvailable: true }
          final tableMap = e.value as Map<String, dynamic>;
          return {
            'number': e.key,
            'isAvailable': tableMap['isAvailable'] as bool? ?? false,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading tables: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() => _isLoading = true);

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
          _errorMessage = 'Failed to load menu. Please try again.';
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dine In',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                Text(
                  _selectedTableNumber == 0
                      ? 'No table selected'
                      : 'Table $_selectedTableNumber',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant),
            color: Colors.white,
            onPressed: _showTableSelectionDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              // Table Selection & Category Chips
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
                          const Icon(Icons.table_bar, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTable == 0
                                ? 'No table selected'
                                : 'Table $_selectedTable',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                    : _selectedTable == 0
                    ? _buildTableSelectionPrompt()
                    : _buildMenuGrid(),
              ),
            ],
          ),

          // Persistent Cart Bar
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

  Widget _buildTableSelectionPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_restaurant, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text(
            'Select Your Table',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please choose an available table to start ordering',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _showTableSelectionDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Select Table',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  void _showTableSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Your Table'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _tables.length,
              itemBuilder: (context, index) {
                final table = _tables[index];
                final tableNumber = int.parse(table['number'].substring(1)); // Convert "T01" to 1
                final isAvailable = table['isAvailable'];

                return InkWell(
                  onTap: isAvailable
                      ? () {
                    setState(() {
                      _selectedTableNumber = tableNumber;
                      _selectedTable = tableNumber; // Add this line to update both variables
                    });
                    Navigator.pop(context);
                  }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: !isAvailable
                          ? Colors.grey[400]
                          : _selectedTableNumber == tableNumber
                          ? AppColors.primaryBlue
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'T${tableNumber.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: !isAvailable
                                  ? Colors.white
                                  : _selectedTableNumber == tableNumber
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          if (!isAvailable)
                            const Text(
                              'Reserved',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
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

        final items = snapshot.data!.docs
            .map((doc) => MenuItem.fromFirestore(doc))
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
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
    final isInCart = _dineInCartService.items.any((cartItem) => cartItem.id == item.id);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                      top: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
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

            // Quantity Indicator (replaces the add button)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showItemDetails(item),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isInCart ? AppColors.primaryBlue : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    isInCart
                        ? _dineInCartService.items
                        .firstWhere((cartItem) => cartItem.id == item.id)
                        .quantity
                        .toString()
                        : '+',
                    style: TextStyle(
                      color: isInCart ? Colors.white : AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: isInCart ? 16 : 20,
                    ),
                  ),
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
  }



  Widget _buildDineInCartBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Badge(
            label: Text('${_dineInCartService.itemCount}'),
            backgroundColor: AppColors.primaryBlue,
            textColor: Colors.white,
            child: const Icon(Icons.restaurant, size: 30),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Table $_selectedTableNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'QAR ${_dineInCartService.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              if (_selectedTableNumber == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a table first'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DineInCartScreen(
                    cartService: _dineInCartService,
                    tableNumber: _selectedTableNumber,
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
            child: const Text(
              'View Order',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showItemDetails(MenuItem item) {
    final isInCart = _dineInCartService.items.any((cartItem) => cartItem.id == item.id);
    int quantity = isInCart
        ? _dineInCartService.items.firstWhere((cartItem) => cartItem.id == item.id).quantity
        : 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void updateQuantity(int newQuantity) {
              if (newQuantity < 1) {
                _dineInCartService.removeFromCart(item.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed ${item.name} from order'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              setModalState(() => quantity = newQuantity);
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
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
                            child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
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
                                mainAxisSize: MainAxisSize.min,
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
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'QAR ${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 24),
                              color: quantity == 1 ? Colors.grey : AppColors.primaryBlue,
                              onPressed: () => updateQuantity(quantity - 1),
                            ),
                            Container(
                              width: 50,
                              alignment: Alignment.center,
                              child: Text(
                                quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 24),
                              color: AppColors.primaryBlue,
                              onPressed: () => updateQuantity(quantity + 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isInCart) {
                              _dineInCartService.updateQuantity(item.id, quantity);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Updated ${item.name} quantity to $quantity'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              _dineInCartService.addToCart(item, quantity: quantity);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${item.name} to order'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isInCart ? Colors.orange : AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            isInCart ? 'UPDATE QUANTITY' : 'ADD TO ORDER',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {}); // Refresh parent widget state
      }
    });
  }

}


class DineInCartScreen extends StatefulWidget {
  final DineInCartService cartService;
  final int tableNumber; // This should be properly defined

  const DineInCartScreen({
    Key? key,
    required this.cartService,
    required this.tableNumber, // This should be required
  }) : super(key: key);

  @override
  State<DineInCartScreen> createState() => _DineInCartScreenState();
}

class _DineInCartScreenState extends State<DineInCartScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isCheckingOut = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Order'),
            Text(
              'Table ${widget.tableNumber}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.cartService.items.isEmpty
                ? null
                : () => _showClearCartDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: widget.cartService,
              builder: (context, child) {
                return widget.cartService.items.isEmpty
                    ? _buildEmptyCart()
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: widget.cartService.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.cartService.items[index];
                    return _buildCartItem(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.cartService,
        builder: (context, child) {
          return widget.cartService.items.isEmpty
              ? const SizedBox.shrink()
              : _buildCheckoutBar();
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text(
            'Your Order is Empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add delicious dishes from our menu',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Browse Menu',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartModel item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
            content: Text('Removed ${item.name} from order'),
            action: SnackBarAction(
              label: 'UNDO',
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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
        child: Row(
          children: [
            // Item Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                width: 100,
                height: 100,
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

            // Item Details
            Expanded(
              child: Padding(
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
                      'QAR ${item.totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            if (item.quantity > 1) {
                              widget.cartService.updateQuantity(
                                  item.id, item.quantity - 1);
                            } else {
                              widget.cartService.removeFromCart(item.id);
                            }
                          },
                        ),
                        Text(
                          item.quantity.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            widget.cartService.updateQuantity(
                                item.id, item.quantity + 1);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final subtotal = widget.cartService.totalAmount;
    final tax = subtotal * 0.10; // 10% tax
    final total = subtotal + tax;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order Summary
          InkWell(
            onTap: _showOrderSummary,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.cartService.itemCount} ITEMS',
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

          // Special Instructions
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Add special instructions...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // Total and Checkout Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'QAR ${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 150,
                child: ElevatedButton(
                  onPressed: _isCheckingOut ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Order?'),
        content: const Text('Are you sure you want to clear your order?'),
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
                const SnackBar(
                  content: Text('Order cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderSummary() {
    final subtotal = widget.cartService.totalAmount;
    final tax = subtotal * 0.10;
    final total = subtotal + tax;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildBillRow('Subtotal', subtotal),
              _buildBillRow('Tax (10%)', tax),
              const Divider(height: 24),
              _buildBillRow('Total', total, isTotal: true),
              const SizedBox(height: 16),
              if (_notesController.text.isNotEmpty) ...[
                const Text(
                  'Special Instructions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_notesController.text),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primaryBlue,
                ),
                child: const Text('OK'),
              ),
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
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'QAR ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppColors.primaryBlue : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (widget.cartService.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isCheckingOut = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception("User not logged in. Please sign in to place an order.");
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final counterRef = FirebaseFirestore.instance
          .collection('daily_counters')
          .doc(today);
      final orderDoc = FirebaseFirestore.instance.collection('Orders').doc();

      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Processing Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while we process your order...'),
            ],
          ),
        ),
      );

      // Execute transaction
      final orderId = await FirebaseFirestore.instance.runTransaction<String>(
            (transaction) async {
          // Get or create daily counter
          final counterSnap = await transaction.get(counterRef);
          int dailyCount = 1;

          if (counterSnap.exists) {
            dailyCount = (counterSnap.get('count') as int) + 1;
            transaction.update(counterRef, {'count': dailyCount});
          } else {
            transaction.set(counterRef, {'count': 1});
          }

          // Generate order ID
          final paddedOrderNumber = dailyCount.toString().padLeft(3, '0');
          final orderId = 'DI-$today-$paddedOrderNumber';

          // Prepare order data
          final items = widget.cartService.items.map((item) => {
            'itemId': item.id,
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'total': item.totalPrice,
            'variants': item.variants,
            'addons': item.addons,
          }).toList();

          final subtotal = widget.cartService.totalAmount;
          final tax = subtotal * 0.10;
          final total = subtotal + tax;

          final orderData = {
            'orderId': orderId,
            'dailyOrderNumber': dailyCount,
            'date': today,
            'customerId': user.email,
            'customerName': user.displayName ?? 'Guest',
            'items': items,
            'notes': _notesController.text.trim(),
            'status': 'pending',
            'subtotal': subtotal,
            'tax': tax,
            'totalAmount': total,
            'timestamp': FieldValue.serverTimestamp(),
            'orderType': 'dine-in',
            'tableNumber': widget.tableNumber,
            'branchId': 'Old_Airport',
          };

          // Update table status
          final tableKey = 'T${widget.tableNumber.toString().padLeft(2, '0')}';
          transaction.update(
            FirebaseFirestore.instance.collection('Tables').doc('Old_Airport'),
            {
              tableKey: {
                'isAvailable': false,
                'orderId': orderId,
                'occupiedAt': FieldValue.serverTimestamp(),
              },
            },
          );

          // Create order document
          transaction.set(orderDoc, orderData);

          return orderId;
        },
      );

      // Clear cart only after successful transaction
      await widget.cartService.clearCart();

      // Close processing dialog
      if (mounted) Navigator.of(context).pop();

      // Show success and navigate
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Order Placed Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ID: $orderId'),
                const SizedBox(height: 8),
                Text('Table: ${widget.tableNumber}'),
                const SizedBox(height: 16),
                const Text('Your food will be served shortly.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => DineInScreen()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close processing dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      debugPrint('Order submission error: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }}

class DineInCartService extends ChangeNotifier {
  static final DineInCartService _instance = DineInCartService._internal();
  factory DineInCartService() => _instance;
  DineInCartService._internal() {
    loadCartFromPrefs(); // Changed from _loadCartFromPrefs to loadCartFromPrefs
  }

  final List<CartModel> _items = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CartModel> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount => _items.fold(0, (sum, item) => sum + item.totalPrice);

  // Changed from _loadCartFromPrefs to loadCartFromPrefs (removed underscore)
  Future<void> loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('dinein_cart_items');

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

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_items.map((item) => item.toMap()).toList());
      await prefs.setString('dinein_cart_items', cartJson);
    } catch (e) {
      debugPrint('Error saving dine-in cart to SharedPreferences: $e');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dinein_cart_items');
    notifyListeners(); // Explicitly remove the cart data
  }}