import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/business.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/sale.dart';
import '../models/business_expense.dart';
import '../models/closing.dart';
import '../models/seller.dart';
import '../models/seller_inventory.dart';

class BusinessProvider with ChangeNotifier {
  // Hive Boxes
  late Box<Business> _businessBox;
  late Box<Product> _productBox;
  late Box<Sale> _saleBox;
  late Box<BusinessExpense> _expenseBox;
  late Box<Closing> _closingBox;
  late Box<ProductCategory> _productCategoryBox;
  late Box<Seller> _sellerBox;
  late Box<SellerInventory> _sellerInventoryBox;

  // Data Lists
  List<Business> _businesses = [];
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<BusinessExpense> _expenses = [];
  List<Closing> _closings = [];
  List<ProductCategory> _productCategories = [];
  List<Seller> _sellers = [];
  List<SellerInventory> _sellerInventory = [];

  // Current Active Business
  String? _activeBusinessId;

  // Currency Settings
  String _mainCurrency = 'CUP';
  Map<String, double> _exchangeRates = {};

  bool _isLoading = true;

  final Uuid _uuid = const Uuid();

  // Getters
  bool get isLoading => _isLoading;
  List<Business> get businesses => _businesses;
  String get mainCurrency => _mainCurrency;
  Business? get activeBusiness {
    if (_activeBusinessId == null || _businesses.isEmpty) return null;
    try {
      return _businesses.firstWhere((b) => b.id == _activeBusinessId);
    } catch (e) {
      return _businesses.first;
    }
  }

  // Get data for active business only
  List<ProductCategory> get productCategories => _activeBusinessId == null
      ? []
      : _productCategories.where((c) => c.businessId == _activeBusinessId).toList();

  List<Product> get products => _activeBusinessId == null
      ? []
      : _products.where((p) => p.businessId == _activeBusinessId).toList();

  List<Sale> get sales => _activeBusinessId == null
      ? []
      : _sales.where((s) => s.businessId == _activeBusinessId).toList();

  List<BusinessExpense> get expenses => _activeBusinessId == null
      ? []
      : _expenses.where((e) => e.businessId == _activeBusinessId).toList();

  List<Closing> get closings => _activeBusinessId == null
      ? []
      : _closings.where((c) => c.businessId == _activeBusinessId).toList();

  List<Seller> get sellers => _activeBusinessId == null
      ? []
      : _sellers.where((s) => s.businessId == _activeBusinessId).toList();

  List<SellerInventory> get sellerInventory => _activeBusinessId == null
      ? []
      : _sellerInventory.where((si) => si.businessId == _activeBusinessId).toList();

  List<SellerInventory> getSellerInventoryBySeller(String sellerId) {
    return sellerInventory.where((si) => si.sellerId == sellerId).toList();
  }

  // Expense Categories
  static const List<String> expenseCategories = [
    'Alquiler',
    'Servicios',
    'Salarios',
    'Insumos',
    'Marketing',
    'Transporte',
    'Otros',
  ];

  Future<void> init() async {
    _businessBox = await Hive.openBox<Business>('businesses');
    _productBox = await Hive.openBox<Product>('products');
    _saleBox = await Hive.openBox<Sale>('sales');
    _expenseBox = await Hive.openBox<BusinessExpense>('business_expenses');
    _closingBox = await Hive.openBox<Closing>('closings');
    _productCategoryBox = await Hive.openBox<ProductCategory>('product_categories');
    _sellerBox = await Hive.openBox<Seller>('sellers');
    _sellerInventoryBox = await Hive.openBox<SellerInventory>('seller_inventory');

    final prefs = await SharedPreferences.getInstance();
    _mainCurrency = prefs.getString('main_currency') ?? 'CUP';
    final ratesJson = prefs.getString('exchange_rates');
    if (ratesJson != null) {
      try {
        final decoded = jsonDecode(ratesJson) as Map<String, dynamic>;
        _exchangeRates = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
      } catch (e) {
        _exchangeRates = {};
      }
    } else {
      final oldRate = prefs.getDouble('exchange_rate');
      if (oldRate != null) {
        _exchangeRates = {'USD': oldRate};
      } else {
        _exchangeRates = {'USD': 320.0, 'EUR': 340.0, 'MLC': 270.0};
      }
    }

    _fetchData();
    _isLoading = false;
    notifyListeners();
  }

  void _fetchData() {
    _businesses = _businessBox.values.toList();
    _products = _productBox.values.toList();
    _sales = _saleBox.values.toList();
    _expenses = _expenseBox.values.toList();
    _closings = _closingBox.values.toList();
    _productCategories = _productCategoryBox.values.toList();
    _sellers = _sellerBox.values.toList();
    _sellerInventory = _sellerInventoryBox.values.toList();

    // Set active business to first if none selected
    if (_businesses.isNotEmpty && _activeBusinessId == null) {
      _activeBusinessId = _businesses.first.id;
    }
  }

  void updateCurrencyConfig(String currency, Map<String, double> rates) {
    _mainCurrency = currency;
    _exchangeRates = rates;
    notifyListeners();
  }

  double convertAmount(double amount, String currency) => _convertAmount(amount, currency);

  double _convertAmount(double amount, String currency) {
    if (currency == _mainCurrency) return amount;
    
    final rateToMain = _exchangeRates[currency];
    if (rateToMain != null && rateToMain > 0) {
      return amount * rateToMain;
    }
    
    return amount;
  }

  // ========== BUSINESS MANAGEMENT ==========

  Future<void> createBusiness({
    required String name,
    required String type,
    required String iconCode,
    required int colorValue,
  }) async {
    final business = Business(
      id: _uuid.v4(),
      name: name,
      type: type,
      iconCode: iconCode,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );

    await _businessBox.add(business);
    _businesses.add(business);

    // Set as active if first business
    if (_businesses.length == 1) {
      _activeBusinessId = business.id;
    }

    notifyListeners();
  }

  Future<void> editBusiness(Business updatedBusiness) async {
    final index = _businesses.indexWhere((b) => b.id == updatedBusiness.id);
    if (index == -1) return;

    final key = _businessBox.keys.firstWhere(
      (k) => _businessBox.get(k)?.id == updatedBusiness.id,
      orElse: () => null,
    );

    if (key != null) {
      await _businessBox.put(key, updatedBusiness);
      _businesses[index] = updatedBusiness;
      notifyListeners();
    }
  }

  Future<void> deleteBusiness(String id) async {
    final index = _businesses.indexWhere((b) => b.id == id);
    if (index == -1) return;

    // Delete all associated data
    await _deleteBusinessData(id);

    final key = _businessBox.keys.firstWhere(
      (k) => _businessBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      await _businessBox.delete(key);
      _businesses.removeAt(index);

      // Switch to another business if this was active
      if (_activeBusinessId == id) {
        _activeBusinessId = _businesses.isNotEmpty
            ? _businesses.first.id
            : null;
      }

      notifyListeners();
    }
  }

  Future<void> _deleteBusinessData(String businessId) async {
    // Delete products
    final productsToDelete = _products
        .where((p) => p.businessId == businessId)
        .toList();
    for (var product in productsToDelete) {
      await deleteProduct(product.id);
    }

    // Delete sales
    final salesToDelete = _sales
        .where((s) => s.businessId == businessId)
        .toList();
    for (var sale in salesToDelete) {
      await deleteSale(sale.id);
    }

    // Delete expenses
    final expensesToDelete = _expenses
        .where((e) => e.businessId == businessId)
        .toList();
    for (var expense in expensesToDelete) {
      await deleteExpense(expense.id);
    }

    // Delete closings
    final closingsToDelete = _closings
        .where((c) => c.businessId == businessId)
        .toList();
    for (var closing in closingsToDelete) {
      await deleteClosing(closing.id);
    }

    // Delete product categories
    final categoriesToDelete = _productCategories
        .where((c) => c.businessId == businessId)
        .toList();
    for (var category in categoriesToDelete) {
      await deleteProductCategory(category.id);
    }

    // Delete sellers
    final sellersToDelete = _sellers
        .where((s) => s.businessId == businessId)
        .toList();
    for (var seller in sellersToDelete) {
      await deleteSeller(seller.id);
    }

    // Delete seller inventory
    final inventoryToDelete = _sellerInventory
        .where((si) => si.businessId == businessId)
        .toList();
    for (var inv in inventoryToDelete) {
      final key = _sellerInventoryBox.keys.firstWhere(
        (k) => _sellerInventoryBox.get(k)?.id == inv.id,
        orElse: () => null,
      );
      if (key != null) {
        await _sellerInventoryBox.delete(key);
        _sellerInventory.removeWhere((si) => si.id == inv.id);
      }
    }
  }

  void setActiveBusiness(String businessId) {
    _activeBusinessId = businessId;
    notifyListeners();
  }

  // ========== PRODUCT MANAGEMENT ==========

  Future<void> addProduct({
    required String name,
    required String description,
    required String sku,
    required DateTime investmentDate,
    required double initialQuantity,
    required double costPerUnit,
    required String currency,
    required double salePrice,
    double additionalCosts = 0.0,
    String unit = 'uds',
    String? categoryId,
    String? subcategoryId,
  }) async {
    if (_activeBusinessId == null) return;

    final totalInvestment = initialQuantity * costPerUnit;

    final product = Product(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      name: name,
      description: description,
      sku: sku,
      investmentDate: investmentDate,
      initialQuantity: initialQuantity,
      costPerUnit: costPerUnit,
      currency: currency,
      totalInvestment: totalInvestment,
      additionalCosts: additionalCosts,
      currentStock: initialQuantity, // Start with initial quantity
      salePrice: salePrice,
      unit: unit,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
    );

    await _productBox.add(product);
    _products.add(product);
    notifyListeners();
  }

  Future<void> editProduct(Product updatedProduct) async {
    final index = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (index == -1) return;

    final key = _productBox.keys.firstWhere(
      (k) => _productBox.get(k)?.id == updatedProduct.id,
      orElse: () => null,
    );

    if (key != null) {
      await _productBox.put(key, updatedProduct);
      _products[index] = updatedProduct;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final key = _productBox.keys.firstWhere(
      (k) => _productBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      await _productBox.delete(key);
      _products.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> updateStock(String productId, double newStock) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _products[index];
      final stockDiff = newStock - product.currentStock;

      final newInitialQuantity = stockDiff > 0
          ? product.initialQuantity + stockDiff
          : product.initialQuantity;

      final updated = product.copyWith(
        currentStock: newStock,
        initialQuantity: newInitialQuantity,
        totalInvestment: newInitialQuantity * product.costPerUnit,
      );
      await editProduct(updated);
    }
  }

  // ========== CATEGORY MANAGEMENT ==========

  Future<void> addProductCategory({
    required String name,
    String? parentId,
  }) async {
    if (_activeBusinessId == null) return;

    final category = ProductCategory(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      name: name,
      parentId: parentId,
    );

    await _productCategoryBox.add(category);
    _productCategories.add(category);
    notifyListeners();
  }

  Future<void> editProductCategory(ProductCategory updated) async {
    final index = _productCategories.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;

    final key = _productCategoryBox.keys.firstWhere(
      (k) => _productCategoryBox.get(k)?.id == updated.id,
      orElse: () => null,
    );

    if (key != null) {
      await _productCategoryBox.put(key, updated);
      _productCategories[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteProductCategory(String id) async {
    // If it's a parent, also delete all subcategories
    final subcats = _productCategories.where((c) => c.parentId == id).toList();
    for (final sub in subcats) {
      await deleteProductCategory(sub.id);
    }

    final index = _productCategories.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final key = _productCategoryBox.keys.firstWhere(
      (k) => _productCategoryBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      await _productCategoryBox.delete(key);
      _productCategories.removeAt(index);
      notifyListeners();
    }
  }

  // Helper getters for categories
  List<ProductCategory> get rootCategories =>
      productCategories.where((c) => c.parentId == null).toList();

  List<ProductCategory> getSubcategories(String categoryId) =>
      productCategories.where((c) => c.parentId == categoryId).toList();

  ProductCategory? getCategoryById(String id) {
    try {
      return _productCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ========== SELLER MANAGEMENT ==========

  Future<void> addSeller({
    required String name,
    required String lastName,
    required String phone,
    String email = '',
    String ci = '',
    String address = '',
    String role = '',
    double commissionRate = 0.0,
    double salary = 0.0,
    required DateTime hireDate,
    bool isActive = true,
    String notes = '',
  }) async {
    if (_activeBusinessId == null) return;

    final seller = Seller(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      name: name,
      lastName: lastName,
      phone: phone,
      email: email,
      ci: ci,
      address: address,
      role: role,
      commissionRate: commissionRate,
      salary: salary,
      hireDate: hireDate,
      isActive: isActive,
      notes: notes,
    );

    await _sellerBox.add(seller);
    _sellers.add(seller);
    notifyListeners();
  }

  Future<void> editSeller(Seller updatedSeller) async {
    final index = _sellers.indexWhere((s) => s.id == updatedSeller.id);
    if (index == -1) return;

    final key = _sellerBox.keys.firstWhere(
      (k) => _sellerBox.get(k)?.id == updatedSeller.id,
      orElse: () => null,
    );

    if (key != null) {
      await _sellerBox.put(key, updatedSeller);
      _sellers[index] = updatedSeller;
      notifyListeners();
    }
  }

  Future<void> deleteSeller(String id) async {
    final index = _sellers.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final key = _sellerBox.keys.firstWhere(
      (k) => _sellerBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      await _sellerBox.delete(key);
      _sellers.removeAt(index);
      notifyListeners();
    }
  }

  Seller? getSellerById(String id) {
    try {
      return _sellers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ========== SELLER INVENTORY MANAGEMENT ==========

  Future<void> assignProductToSeller({
    required String sellerId,
    required String productId,
    required String productName,
    required double quantity,
  }) async {
    if (_activeBusinessId == null) return;

    final existing = _sellerInventory.where(
      (si) => si.sellerId == sellerId && si.productId == productId,
    ).toList();

    if (existing.isNotEmpty) {
      final updated = SellerInventory(
        id: existing.first.id,
        businessId: _activeBusinessId!,
        sellerId: sellerId,
        productId: productId,
        productName: productName,
        assignedQuantity: quantity,
      );
      final key = _sellerInventoryBox.keys.firstWhere(
        (k) => _sellerInventoryBox.get(k)?.id == existing.first.id,
        orElse: () => null,
      );
      if (key != null) {
        await _sellerInventoryBox.put(key, updated);
        final idx = _sellerInventory.indexWhere((si) => si.id == existing.first.id);
        if (idx != -1) _sellerInventory[idx] = updated;
      }
    } else {
      final inventory = SellerInventory(
        id: _uuid.v4(),
        businessId: _activeBusinessId!,
        sellerId: sellerId,
        productId: productId,
        productName: productName,
        assignedQuantity: quantity,
      );
      await _sellerInventoryBox.add(inventory);
      _sellerInventory.add(inventory);
    }
    notifyListeners();
  }

  Future<void> removeProductFromSeller(String inventoryId) async {
    final index = _sellerInventory.indexWhere((si) => si.id == inventoryId);
    if (index == -1) return;

    final key = _sellerInventoryBox.keys.firstWhere(
      (k) => _sellerInventoryBox.get(k)?.id == inventoryId,
      orElse: () => null,
    );

    if (key != null) {
      await _sellerInventoryBox.delete(key);
      _sellerInventory.removeAt(index);
      notifyListeners();
    }
  }

  Map<String, double> calculateSellerSales(String sellerId, DateTime start, DateTime end) {
    final periodSales = _sales.where(
      (s) =>
          s.sellerId == sellerId &&
          s.businessId == _activeBusinessId &&
          s.date.isAfter(start) &&
          s.date.isBefore(end.add(const Duration(days: 1))),
    );
    final total = periodSales.fold<double>(0.0, (sum, s) => sum + s.total);
    return {'total': total, 'count': periodSales.length.toDouble()};
  }

  double getSellerTotalSales(String sellerId) {
    return _sales.where(
      (s) => s.sellerId == sellerId && s.businessId == _activeBusinessId,
    ).fold<double>(0.0, (sum, s) => sum + s.total);
  }

  double getSellerAssignedValue(String sellerId) {
    final inv = getSellerInventoryBySeller(sellerId);
    double total = 0;
    for (final item in inv) {
      try {
        final product = _products.firstWhere((p) => p.id == item.productId);
        total += item.assignedQuantity * product.salePrice;
      } catch (_) {}
    }
    return total;
  }

  double getSellerRemainingValue(String sellerId) {
    return getSellerAssignedValue(sellerId);
  }

  double calculateSellerCommission(String sellerId) {
    final seller = getSellerById(sellerId);
    if (seller == null || seller.commissionRate <= 0) return 0;
    final totalSales = getSellerTotalSales(sellerId);
    return totalSales * (seller.commissionRate / 100);
  }

  // ========== SALES MANAGEMENT ==========

  Future<void> addSale({
    required List<SaleItem> items,
    required String paymentMethod,
    double discount = 0.0,
    String? clientName,
    String status = 'paid',
    String? sellerId,
    String? sellerName,
  }) async {
    if (_activeBusinessId == null) return;

    final subtotal = items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final total = (subtotal - discount) > 0 ? (subtotal - discount) : 0.0;

    final sale = Sale(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      items: items,
      total: total,
      paymentMethod: paymentMethod,
      date: DateTime.now(),
      discount: discount,
      clientName: clientName,
      status: status,
      sellerId: sellerId,
      sellerName: sellerName,
    );

    await _saleBox.add(sale);
    _sales.add(sale);

    // Update stock for each product
    for (var item in items) {
      final product = _products.firstWhere((p) => p.id == item.productId);
      final newStock = product.currentStock - item.quantity;
      await updateStock(product.id, newStock);
    }

    // Deduct from seller's assigned inventory
    if (sellerId != null) {
      for (var item in items) {
        final existing = _sellerInventory.where(
          (si) => si.sellerId == sellerId && si.productId == item.productId,
        ).toList();
        if (existing.isNotEmpty) {
          final inv = existing.first;
          final remaining = inv.assignedQuantity - item.quantity;
          if (remaining <= 0) {
            await removeProductFromSeller(inv.id);
          } else {
            await assignProductToSeller(
              sellerId: sellerId,
              productId: item.productId,
              productName: item.productName,
              quantity: remaining,
            );
          }
        }
      }
    }

    notifyListeners();
  }

  Future<void> deleteSale(String id) async {
    final index = _sales.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final key = _saleBox.keys.firstWhere(
      (k) => _saleBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      await _saleBox.delete(key);
      _sales.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> markSaleAsPaid(String id) async {
    final index = _sales.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final key = _saleBox.keys.firstWhere(
      (k) => _saleBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      final oldSale = _sales[index];
      final newSale = Sale(
        id: oldSale.id,
        businessId: oldSale.businessId,
        items: oldSale.items,
        total: oldSale.total,
        paymentMethod: oldSale.paymentMethod,
        date: oldSale.date,
        discount: oldSale.discount,
        clientName: oldSale.clientName,
        sellerId: oldSale.sellerId,
        sellerName: oldSale.sellerName,
        status: 'paid',
      );
      
      await _saleBox.put(key, newSale);
      _sales[index] = newSale;
      notifyListeners();
    }
  }

  // ========== EXPENSE MANAGEMENT ==========

  Future<void> addExpense({
    required double amount,
    required String category,
    required String description,
    required String currency,
  }) async {
    if (_activeBusinessId == null) return;

    final expense = BusinessExpense(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      amount: amount,
      category: category,
      description: description,
      currency: currency,
      date: DateTime.now(),
    );

    await _expenseBox.add(expense);
    _expenses.add(expense);
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final key = _expenseBox.keys.firstWhere(
      (k) => _expenseBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      await _expenseBox.delete(key);
      _expenses.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> editExpense(BusinessExpense updatedExpense) async {
    final index = _expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (index == -1) return;

    final key = _expenseBox.keys.firstWhere(
      (k) => _expenseBox.get(k)?.id == updatedExpense.id,
      orElse: () => null,
    );

    if (key != null) {
      await _expenseBox.put(key, updatedExpense);
      _expenses[index] = updatedExpense;
      notifyListeners();
    }
  }

  // ========== CLOSING MANAGEMENT ==========

  Future<void> createClosing({
    required String period,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_activeBusinessId == null) return;

    final periodSales = sales.where(
      (s) =>
          s.date.isAfter(startDate) &&
          s.date.isBefore(endDate.add(const Duration(days: 1))),
    ).toList();

    final periodExpenses = expenses.where(
      (e) =>
          e.date.isAfter(startDate) &&
          e.date.isBefore(endDate.add(const Duration(days: 1))),
    ).toList();

    final double income = periodSales.fold<double>(0.0, (sum, s) => sum + s.total);
    final double expenseTotal = periodExpenses.fold<double>(
      0.0,
      (sum, e) => sum + _convertAmount(e.amount, e.currency),
    );
    final double profit = income - expenseTotal;

    final totalInvestment = products.fold<double>(
      0.0,
      (sum, p) => sum + p.totalInvestment,
    );
    final double roi = totalInvestment > 0 ? (profit / totalInvestment) * 100 : 0.0;

    // Detailed metrics computation
    final Map<String, Map<String, dynamic>> soldGroups = {};
    double totalDiscounts = 0.0;
    final Map<String, double> paymentMethods = {};
    double costOfGoodsSold = 0.0;

    for (final sale in periodSales) {
      totalDiscounts += sale.discount;
      paymentMethods[sale.paymentMethod] = (paymentMethods[sale.paymentMethod] ?? 0.0) + sale.total;
      for (final item in sale.items) {
        final key = item.productId;
        if (soldGroups.containsKey(key)) {
          soldGroups[key]!['qty'] = (soldGroups[key]!['qty'] as num).toDouble() + item.quantity;
          soldGroups[key]!['revenue'] = (soldGroups[key]!['revenue'] as double) + item.subtotal;
        } else {
          soldGroups[key] = {
            'name': item.productName,
            'qty': item.quantity,
            'revenue': item.subtotal,
          };
        }
        // Calculate cost of goods sold
        try {
          final product = _products.firstWhere((p) => p.id == item.productId);
          costOfGoodsSold += item.quantity * product.costPerUnit;
        } catch (_) {}
      }
    }
    final List<Map<String, dynamic>> soldList = soldGroups.values.toList();
    final soldProductsJson = jsonEncode(soldList);

    String bestSellerName = '';
    int bestSellerQty = 0;
    for (final item in soldList) {
      final double qty = (item['qty'] as num).toDouble();
      if (qty.round() > bestSellerQty) {
        bestSellerQty = qty.round();
        bestSellerName = item['name'] as String;
      }
    }

    final Map<String, double> expenseCategories = {};
    for (final exp in periodExpenses) {
      final category = exp.category;
      final double amtInMain = _convertAmount(exp.amount, exp.currency);
      expenseCategories[category] = (expenseCategories[category] ?? 0.0) + amtInMain;
    }
    final expenseCategoriesJson = jsonEncode(expenseCategories);
    final paymentMethodsJson = jsonEncode(paymentMethods);

    // Seller stats
    final Map<String, Map<String, dynamic>> sellerStats = {};
    for (final sale in periodSales) {
      if (sale.sellerId == null || sale.sellerName == null) continue;
      final name = sale.sellerName!;
      if (!sellerStats.containsKey(name)) {
        sellerStats[name] = {'total': 0.0, 'count': 0};
      }
      sellerStats[name]!['total'] = (sellerStats[name]!['total'] as double) + sale.total;
      sellerStats[name]!['count'] = (sellerStats[name]!['count'] as int) + 1;
    }
    final sellerStatsJson = jsonEncode(sellerStats);

    final periodAddedProducts = products.where(
      (p) =>
          p.investmentDate.isAfter(startDate) &&
          p.investmentDate.isBefore(endDate.add(const Duration(days: 1))),
    ).toList();
    
    final List<Map<String, dynamic>> addedList = periodAddedProducts.map((p) => {
      'name': p.name,
      'qty': p.initialQuantity,
      'cost': p.costPerUnit,
    }).toList();
    final addedProductsJson = jsonEncode(addedList);

    final closing = Closing(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      period: period,
      startDate: startDate,
      endDate: endDate,
      income: income,
      expenses: expenseTotal,
      profit: profit,
      roi: roi,
      salesCount: periodSales.length,
      expensesCount: periodExpenses.length,
      soldProductsJson: soldProductsJson,
      addedProductsJson: addedProductsJson,
      bestSellerName: bestSellerName,
      bestSellerQty: bestSellerQty,
      paymentMethodsJson: paymentMethodsJson,
      expenseCategoriesJson: expenseCategoriesJson,
      totalDiscounts: totalDiscounts,
      sellerStatsJson: sellerStatsJson,
      costOfGoodsSold: costOfGoodsSold,
      netProfit: profit - costOfGoodsSold,
    );

    await _closingBox.add(closing);
    _closings.add(closing);
    notifyListeners();
  }

  Future<void> deleteClosing(String id) async {
    final index = _closings.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final key = _closingBox.keys.firstWhere(
      (k) => _closingBox.get(k)?.id == id,
      orElse: () => null,
    );

    if (key != null) {
      await _closingBox.delete(key);
      _closings.removeAt(index);
      notifyListeners();
    }
  }

  // ========== CALCULATIONS & ANALYTICS ==========

  Map<String, double> calculatePeriodStats(DateTime start, DateTime end) {
    if (_activeBusinessId == null) {
      return {'income': 0, 'expenses': 0, 'profit': 0, 'roi': 0};
    }

    // Calculate income from sales
    final periodSales = sales.where(
      (s) =>
          s.date.isAfter(start) &&
          s.date.isBefore(end.add(const Duration(days: 1))),
    );
    final income = periodSales.fold<double>(0.0, (sum, s) => sum + s.total);

    // Calculate expenses
    final periodExpenses = expenses.where(
      (e) =>
          e.date.isAfter(start) &&
          e.date.isBefore(end.add(const Duration(days: 1))),
    );
    final expenseTotal = periodExpenses.fold<double>(
      0.0,
      (sum, e) => sum + _convertAmount(e.amount, e.currency),
    );

    final profit = income - expenseTotal;

    // Calculate ROI based on total investment in products
    final totalInvestment = products.fold<double>(
      0.0,
      (sum, p) => sum + p.totalInvestment,
    );
    final roi = totalInvestment > 0 ? (profit / totalInvestment) * 100 : 0.0;

    return {
      'income': income,
      'expenses': expenseTotal,
      'profit': profit,
      'roi': roi,
    };
  }

  // Total Revenue (all time)
  double get totalRevenue {
    return sales.fold<double>(0.0, (sum, s) => sum + s.total);
  }

  // Total Expenses (all time)
  double get totalExpenses {
    return expenses.fold<double>(0.0, (sum, e) => sum + _convertAmount(e.amount, e.currency));
  }

  // Total Profit (all time)
  double get totalProfit => totalRevenue - totalExpenses;

  // Cost of Goods Sold (from closings)
  double get totalCostOfGoodsSold {
    return _closings.where((c) => c.businessId == _activeBusinessId).fold<double>(0.0, (sum, c) => sum + c.costOfGoodsSold);
  }

  // Net Profit after COGS (sum of all closings' netProfit)
  double get totalNetProfit {
    return _closings.where((c) => c.businessId == _activeBusinessId).fold<double>(0.0, (sum, c) => sum + c.netProfit);
  }

  // Total Investment
  double get totalInvestment {
    return products.fold<double>(0.0, (sum, p) => sum + p.totalInvestment);
  }

  // Overall ROI
  double get overallROI {
    return totalInvestment > 0 ? (totalProfit / totalInvestment) * 100 : 0;
  }

  // Low stock products (stock < 10)
  List<Product> get lowStockProducts {
    return products.where((p) => p.currentStock < 10).toList();
  }

  // Best selling products (by quantity sold)
  List<Map<String, dynamic>> getBestSellingProducts({int limit = 5}) {
    final Map<String, double> productSales = {};

    for (var sale in sales) {
      for (var item in sale.items) {
        productSales[item.productId] =
            (productSales[item.productId] ?? 0.0) + item.quantity;
      }
    }

    final sorted = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) {
      final product = _products.firstWhere(
        (p) => p.id == e.key,
        orElse: () => _products.isNotEmpty ? _products.first : Product(
          id: '',
          businessId: '',
          name: 'Producto eliminado',
          description: '',
          sku: '',
          investmentDate: DateTime.now(),
          initialQuantity: 0,
          costPerUnit: 0,
          currency: 'CUP',
          totalInvestment: 0,
          currentStock: 0,
          salePrice: 0,
        ),
      );
      return {'product': product, 'quantitySold': e.value};
    }).toList();
  }
}
