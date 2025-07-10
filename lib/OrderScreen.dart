import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'main.dart'; // Assuming MainNavigationWrapper is defined here

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrdersScreen> {
  final _auth = FirebaseAuth.instance;
  Stream<List<Map<String, dynamic>>>? _ordersStream;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = []; // Stores all fetched orders before search filter
  List<Map<String, dynamic>> _filteredOrders = []; // Stores orders after applying search filter
  String? _selectedFilter;
  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Preparing',
    'On the Way',
    'Delivered',
    'Cancelled'
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedFilter = 'All';
    _ordersStream = _getOrdersStream();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applySearchFilter();
    });
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredOrders = List.from(_allOrders);
    } else {
      _filteredOrders = _allOrders.where((order) {
        final restaurantName = (order['Old_Airport'] as String? ?? '').toLowerCase();
        final items = (order['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        final anyItemMatches = items.any((item) {
          final itemName = (item['name'] as String? ?? '').toLowerCase();
          return itemName.contains(_searchQuery);
        });
        return restaurantName.contains(_searchQuery) || anyItemMatches;
      }).toList();
    }
  }

  Stream<List<Map<String, dynamic>>> _getOrdersStream() {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return Stream.value([]);
    }

    Query query = _firestore
        .collection('Orders')
        .where('customerId', isEqualTo: user.email)
        .orderBy('timestamp', descending: true);

    if (_selectedFilter != null && _selectedFilter != 'All') {
      query = query.where('status', isEqualTo: _selectedFilter!.toLowerCase());
    }

    return query.snapshots().asyncMap((querySnapshot) async {
      List<Map<String, dynamic>> fetchedOrders = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        final castItems = items.cast<Map<String, dynamic>>();
        final restaurantId = data['restaurantId'] as String?;

        String restaurantName = 'Mitra Da Dhaba';
        String restaurantImageUrl = 'https://via.placeholder.com/150';
        String restaurantAddress = '';

        if (restaurantId != null) {
          final restaurantDoc = await _firestore.collection('Branch').doc(restaurantId).get();
          if (restaurantDoc.exists) {
            final restaurantData = restaurantDoc.data();
            if (restaurantData != null) {
              restaurantName = restaurantData['name'] as String? ?? restaurantName;
              restaurantImageUrl = restaurantData['logoUrl'] as String? ?? restaurantImageUrl;

              final addressMap = restaurantData['address'] as Map<String, dynamic>?;
              if (addressMap != null) {
                final line1 = addressMap['line1'] as String? ?? '';
                final line2 = addressMap['line2'] as String? ?? '';
                final city = addressMap['city'] as String? ?? '';
                final state = addressMap['state'] as String? ?? '';
                final zip = addressMap['zip'] as String? ?? '';
                final landmark = addressMap['landmark'] as String? ?? '';

                String fullAddress = '';

                if (line1.isNotEmpty) fullAddress += line1;
                if (line2.isNotEmpty) {
                  if (fullAddress.isNotEmpty) fullAddress += ', ';
                  fullAddress += line2;
                }

                String townInfo = '';
                if (city.isNotEmpty) townInfo += city;
                if (state.isNotEmpty) {
                  if (townInfo.isNotEmpty) townInfo += ', ';
                  townInfo += state;
                }
                if (zip.isNotEmpty) {
                  if (townInfo.isNotEmpty) townInfo += ' - ';
                  townInfo += zip;
                }

                if (townInfo.isNotEmpty) {
                  if (fullAddress.isNotEmpty) fullAddress += ', ';
                  fullAddress += townInfo;
                }

                if (landmark.isNotEmpty) {
                  if (fullAddress.isNotEmpty) fullAddress += ' ';
                  fullAddress += '($landmark)';
                }
                restaurantAddress = fullAddress;
              }
            }
          }
        }

        fetchedOrders.add({
          ...data,
          'id': doc.id,
          'items': castItems,
          'formattedDate': _formatTimestamp(data['timestamp'] as Timestamp?),
          'statusDisplay': _formatOrderStatus(data['status'] as String? ?? ''),
          'restaurantName': restaurantName,
          'restaurantImageUrl': restaurantImageUrl,
          'restaurantAddress': restaurantAddress,
        });
      }

      return fetchedOrders;
    });
  }
  String _formatOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'waiting':
        return 'Pending';
      case 'preparing':
      case 'cooking':
        return 'Preparing';
      case 'on the way':
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return status?.isNotEmpty == true
            ? status![0].toUpperCase() + status.substring(1)
            : 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA726); // Orange
      case 'preparing':
        return const Color(0xFF42A5F5); // Blue
      case 'on the way':
        return const Color(0xFFAB47BC); // Purple
      case 'delivered':
        return const Color(0xFF66BB6A); // Green
      case 'cancelled':
        return const Color(0xFFEF5350); // Red
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '--';
    final date = timestamp.toDate();
    return DateFormat('d MMM, h:mm a').format(date); // Example: 10 Apr, 8:10 PM
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final items = (order['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    final orderType = order['Order_type'] as String? ?? 'delivery';
    final restaurantAddress = order['restaurantAddress'] as String? ?? ''; // Now correctly populated

    String formattedOrderType;
    switch (orderType.toLowerCase()) {
      case 'delivery':
        formattedOrderType = 'Delivery Order';
        break;
      case 'dine-in':
      case 'dine_in':
        formattedOrderType = 'Dine In Order';
        break;
      case 'take_away':
        formattedOrderType = 'Takeaway Order';
        break;
      default:
        formattedOrderType = 'Order';
    }
    final itemCount = items.length;
    final firstItemName = itemCount > 0
        ? items[0]['name'] as String? ?? 'Item'
        : 'Item';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4, // Increased elevation for more shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Type Info (replacing restaurant info)
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Icon(
                        orderType.toLowerCase() == 'delivery'
                            ? Icons.delivery_dining
                            : orderType.toLowerCase() == 'dine-in'
                            ? Icons.restaurant
                            : Icons.takeout_dining,
                        size: 24,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedOrderType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (restaurantAddress.isNotEmpty)
                          Text(
                            restaurantAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        // You can remove or modify the "View menu" section if not needed
                        GestureDetector(
                          onTap: () {
                            print('View details tapped');
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_right,
                                  size: 16,
                                  color: Colors.deepOrange,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Colors.black12),
              const SizedBox(height: 12),

              // Ordered Items and Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_drop_up, size: 24, color: Colors.grey.shade700), // Up arrow icon
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$itemCount x $firstItemName', // E.g., '1 x Chicken Hot N Sour Soup'
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order placed on ${order['formattedDate']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          order['statusDisplay'] as String? ?? '', // e.g., Delivered
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(order['status']),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}', // Assuming Rupee symbol from image
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                // Changed to ElevatedButton.icon for red background and white text
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Handle reorder logic here
                    print('Reorder tapped for order: ${order['id']}');
                  },
                  icon: const Icon(Icons.replay, size: 18, color: Colors.white), // White icon
                  label: const Text('Reorder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Red background
                    foregroundColor: Colors.white, // White text
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusFilters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = selected ? filter : 'All';
                    _ordersStream = _getOrdersStream(); // Refresh stream with new filter
                  });
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Your Orders',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.black87,
        actions: const [],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by restaurant or dish',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Status filter chips
          _buildFilterChips(),

          // Order list
          Expanded(
            child: _auth.currentUser == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please sign in to view your orders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )
                : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final orders = snapshot.data ?? [];
                _allOrders = orders;
                _applySearchFilter();

                return _filteredOrders.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No orders yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your orders will appear here',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: () async {
                    // Force refresh by recreating the stream
                    setState(() {
                      _ordersStream = _getOrdersStream();
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(_filteredOrders[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  void _navigateToOrderDetails(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(order: order),
      ),
    );
  }
}


// The OrderDetailsScreen and its helper methods remain unchanged.
class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  void _showContactUsDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final _messageController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    final orderId = order['id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Your message',
                  hintText: 'Describe your issue with this order',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your message';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  await FirebaseFirestore.instance.collection('support').add({
                    'userId': user?.uid,
                    'userEmail': user?.email,
                    'orderId': orderId,
                    'message': _messageController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message sent to support')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error sending message: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List<dynamic>? ?? [];
    final status = order['status'] as String? ?? 'Pending';
    final statusColor = _getStatusColor(status);
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (order['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final tax = (order['tax'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = order['paymentMethod'] as String? ?? 'Cash';
    final notes = order['customerNotes'] as String? ?? 'None';
    final address = order['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final formattedDate = order['formattedDate'] as String? ?? '--';
    final orderId = order['id'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Consistent background color
      appBar: AppBar(
        title: Text(
          'Order #${orderId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(
            color: Colors.black87, // Explicitly set text color
            // You can also add fontWeight or fontSize if desired
          ),
        ),
        elevation: 2, // Added a subtle elevation for consistency
        backgroundColor: Colors.white, // Ensure it's white
        foregroundColor: Colors.black87, // This is for icons, but good to have
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Order Details Card (combining items and delivery info)
                  Card(
                    elevation: 4, // Consistent elevation
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ORDER ITEMS Section
                              const Text(
                                'ORDER ITEMS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Items list
                              Column(
                                children: items.map<Widget>((item) {
                                  final itemMap = item as Map<String, dynamic>;
                                  final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
                                  final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 1;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Item image
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.grey.shade100,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              itemMap['imageUrl'] as String? ?? '',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Icon(
                                                  Icons.fastfood,
                                                  size: 24,
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Item details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemMap['name'] as String? ?? 'Item',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '\$${price.toStringAsFixed(2)} × $quantity',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              if ((itemMap['options'] as List<dynamic>?)?.isNotEmpty ?? false)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    (itemMap['options'] as List<dynamic>).join(', '),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Item total
                                        Text(
                                          '\$${(price * quantity).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),

                              const Divider(height: 24, thickness: 1, color: Colors.black12),

                              // Price breakdown
                              _buildPriceRow('Subtotal', subtotal),
                              _buildPriceRow('Delivery Fee', deliveryFee),
                              _buildPriceRow('Tax', tax),
                              const Divider(height: 24, thickness: 1, color: Colors.black12),
                              _buildPriceRow(
                                'Total',
                                totalAmount,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              // DELIVERY INFORMATION Section (moved here)
                              const SizedBox(height: 24), // Spacer between sections
                              const Text(
                                'DELIVERY INFORMATION',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Address
                              _buildInfoRow(
                                icon: Icons.location_on_outlined,
                                title: 'Delivery Address',
                                value: '${address['street'] ?? ''}\n'
                                    '${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['zipCode'] ?? ''}',
                              ),

                              const SizedBox(height: 16),

                              // Payment method
                              _buildInfoRow(
                                icon: Icons.payment_outlined,
                                title: 'Payment Method',
                                value: paymentMethod == 'cash'
                                    ? 'Cash on Delivery'
                                    : 'Credit/Debit Card',
                              ),

                              const SizedBox(height: 16),

                              // Order time
                              _buildInfoRow(
                                icon: Icons.access_time_outlined,
                                title: 'Order Time',
                                value: formattedDate,
                              ),

                              if (notes.isNotEmpty && notes != 'None') ...[
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  icon: Icons.note_outlined,
                                  title: 'Special Instructions',
                                  value: notes,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Status badge in top-right corner
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _formatOrderStatus(status),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contact Us button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.support_agent, color: Colors.white),
                label: const Text(
                  'Contact Us About This Order',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Red background color
                  foregroundColor: Colors.white, // Ripple & disabled color
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Consistent border radius
                  ),
                ),
                onPressed: () => _showContactUsDialog(context),
              ),

            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style ??
                const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: style ??
                const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500, // Slightly bolder for values
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87, // Consistent text color
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'waiting':
        return 'Pending';
      case 'preparing':
      case 'cooking':
        return 'Preparing';
      case 'on the way':
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return status?.isNotEmpty == true
            ? status![0].toUpperCase() + status.substring(1)
            : 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA726); // Orange
      case 'preparing':
        return const Color(0xFF42A5F5); // Blue
      case 'on the way':
        return const Color(0xFFAB47BC); // Purple
      case 'delivered':
        return const Color(0xFF66BB6A); // Green
      case 'cancelled':
        return const Color(0xFFEF5350); // Red
      default:
        return Colors.grey;
    }
  }
}