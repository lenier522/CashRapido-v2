import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/business.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/business_expense.dart';
import '../models/closing.dart';

class BusinessProvider with ChangeNotifier {
  // Hive Boxes
  late Box<Business> _businessBox;
  late Box<Product> _productBox;
  late Box<Sale> _saleBox;
  late Box<BusinessExpense> _expenseBox;
  late Box<Closing> _closingBox;

  // Data Lists
  List<Business> _businesses = [];
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<BusinessExpense> _expenses = [];
  List<Closing> _closings = [];

  // Current Active Business
  String? _activeBusinessId;

  bool _isLoading = true;

  final Uuid _uuid = const Uuid();

  // Getters
  bool get isLoading => _isLoading;
  List<Business> get businesses => _businesses;
  Business? get activeBusiness {
    if (_activeBusinessId == null || _businesses.isEmpty) return null;
    try {
      return _businesses.firstWhere((b) => b.id == _activeBusinessId);
    } catch (e) {
      return _businesses.first;
    }
  }

  // Get data for active business only
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

    // Set active business to first if none selected
    if (_businesses.isNotEmpty && _activeBusinessId == null) {
      _activeBusinessId = _businesses.first.id;
    }
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
    required int initialQuantity,
    required double costPerUnit,
    required String currency,
    required double salePrice,
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
      currentStock: initialQuantity, // Start with initial quantity
      salePrice: salePrice,
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

  Future<void> updateStock(String productId, int newStock) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _products[index];
      final updated = product.copyWith(currentStock: newStock);
      await editProduct(updated);
    }
  }

  // ========== SALES MANAGEMENT ==========

  Future<void> addSale({
    required List<SaleItem> items,
    required String paymentMethod,
  }) async {
    if (_activeBusinessId == null) return;

    final total = items.fold<double>(0.0, (sum, item) => sum + item.subtotal);

    final sale = Sale(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      items: items,
      total: total,
      paymentMethod: paymentMethod,
      date: DateTime.now(),
    );

    await _saleBox.add(sale);
    _sales.add(sale);

    // Update stock for each product
    for (var item in items) {
      final product = _products.firstWhere((p) => p.id == item.productId);
      final newStock = product.currentStock - item.quantity;
      await updateStock(product.id, newStock);
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

  // ========== CLOSING MANAGEMENT ==========

  Future<void> createClosing({
    required String period,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_activeBusinessId == null) return;

    final stats = calculatePeriodStats(startDate, endDate);

    final closing = Closing(
      id: _uuid.v4(),
      businessId: _activeBusinessId!,
      period: period,
      startDate: startDate,
      endDate: endDate,
      income: stats['income']!,
      expenses: stats['expenses']!,
      profit: stats['profit']!,
      roi: stats['roi']!,
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
      (sum, e) => sum + e.amount,
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
    return expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  // Total Profit (all time)
  double get totalProfit => totalRevenue - totalExpenses;

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
    final Map<String, int> productSales = {};

    for (var sale in sales) {
      for (var item in sale.items) {
        productSales[item.productId] =
            (productSales[item.productId] ?? 0) + item.quantity;
      }
    }

    final sorted = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) {
      final product = _products.firstWhere((p) => p.id == e.key);
      return {'product': product, 'quantitySold': e.value};
    }).toList();
  }
}
