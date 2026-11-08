import '../models/borrower.dart';
import '../models/business.dart';
import '../models/business_expense.dart';
import '../models/closing.dart';
import '../models/loan.dart';
import '../models/loan_activity.dart';
import '../models/models.dart';
import '../models/notification_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/recurring_transaction.dart';
import '../models/sale.dart';
import '../models/seller.dart';
import '../models/seller_inventory.dart';

/// Traduce los modelos de Hive al JSON que se guarda en Supabase y viceversa.
///
/// La nube guarda el JSON completo de cada registro, así que este archivo es
/// el único punto que conoce los campos: si un modelo gana un campo, solo hay
/// que añadirlo aquí. Las fechas viajan en ISO-8601.
abstract final class CloudCodec {
  /// Identificador estable de un registro (clave de la fila en Supabase).
  static String? idOf(Object? value) {
    return switch (value) {
      Category(:final id) => id,
      InternalTransaction(:final id) => id,
      AccountCard(:final id) => id,
      RecurringTransaction(:final id) => id,
      NotificationItem(:final id) => id,
      Business(:final id) => id,
      Product(:final id) => id,
      Sale(:final id) => id,
      BusinessExpense(:final id) => id,
      Closing(:final id) => id,
      ProductCategory(:final id) => id,
      Seller(:final id) => id,
      SellerInventory(:final id) => id,
      Loan(:final id) => id,
      LoanPayment(:final id) => id,
      Borrower(:final id) => id,
      LoanActivity(:final id) => id,
      ChatConversation(:final id) => id,
      _ => null,
    };
  }

  static Map<String, dynamic> toJson(Object value) {
    return switch (value) {
      Category c => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'iconCode': c.iconCode,
        'colorValue': c.colorValue,
        'isCustom': c.isCustom,
        'monthlyBudget': c.monthlyBudget,
        'type': c.type,
      },
      InternalTransaction t => <String, dynamic>{
        'id': t.id,
        'amount': t.amount,
        'currency': t.currency,
        'categoryId': t.categoryId,
        'date': t.date.toIso8601String(),
        'title': t.title,
        'cardId': t.cardId,
      },
      AccountCard c => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'balance': c.balance,
        'currency': c.currency,
        'cardNumber': c.cardNumber,
        'expiryDate': c.expiryDate,
        'colorValue': c.colorValue,
        'isLocked': c.isLocked,
        'pin': c.pin,
        'spendingLimit': c.spendingLimit,
        'bankName': c.bankName,
        'isCash': c.isCash,
        'accountType': c.accountType,
        'interestEnabled': c.interestEnabled,
        'interestRateEA': c.interestRateEA,
        'interestFrequency': c.interestFrequency,
        'nextInterestAt': c.nextInterestAt?.toIso8601String(),
        'creditLimit': c.creditLimit,
        'cutoffDay': c.cutoffDay,
        'paymentDueDay': c.paymentDueDay,
        'annualInterestRate': c.annualInterestRate,
        'monthlyManagementFee': c.monthlyManagementFee,
      },
      ChatConversation c => <String, dynamic>{
        'id': c.id,
        'title': c.title,
        'createdAt': c.createdAt.toIso8601String(),
        'updatedAt': c.updatedAt.toIso8601String(),
        'messages': c.messages
            .map(
              (ChatMessage m) => <String, dynamic>{
                'role': m.role,
                'text': m.text,
                'timestamp': m.timestamp.toIso8601String(),
              },
            )
            .toList(),
      },
      RecurringTransaction r => <String, dynamic>{
        'id': r.id,
        'title': r.title,
        'description': r.description,
        'amount': r.amount,
        'categoryId': r.categoryId,
        'accountId': r.accountId,
        'nextExecutionDate': r.nextExecutionDate.toIso8601String(),
        'recurrence': r.recurrence,
        'autoRegister': r.autoRegister,
        'isIncome': r.isIncome,
      },
      NotificationItem n => <String, dynamic>{
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'date': n.date.toIso8601String(),
        'isRead': n.isRead,
      },
      Business b => <String, dynamic>{
        'id': b.id,
        'name': b.name,
        'type': b.type,
        'iconCode': b.iconCode,
        'colorValue': b.colorValue,
        'createdAt': b.createdAt.toIso8601String(),
        'currency': b.currency,
        'initialCapital': b.initialCapital,
        'linkedCardId': b.linkedCardId,
      },
      Product p => <String, dynamic>{
        'id': p.id,
        'businessId': p.businessId,
        'name': p.name,
        'description': p.description,
        'sku': p.sku,
        'investmentDate': p.investmentDate.toIso8601String(),
        'initialQuantity': p.initialQuantity,
        'costPerUnit': p.costPerUnit,
        'currency': p.currency,
        'totalInvestment': p.totalInvestment,
        'additionalCosts': p.additionalCosts,
        'currentStock': p.currentStock,
        'salePrice': p.salePrice,
        'unit': p.unit,
        'categoryId': p.categoryId,
        'subcategoryId': p.subcategoryId,
      },
      Sale s => <String, dynamic>{
        'id': s.id,
        'businessId': s.businessId,
        'items': s.items
            .map(
              (SaleItem i) => <String, dynamic>{
                'productId': i.productId,
                'productName': i.productName,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
                'subtotal': i.subtotal,
              },
            )
            .toList(),
        'total': s.total,
        'paymentMethod': s.paymentMethod,
        'date': s.date.toIso8601String(),
        'discount': s.discount,
        'clientName': s.clientName,
        'status': s.status,
        'sellerId': s.sellerId,
        'sellerName': s.sellerName,
      },
      BusinessExpense e => <String, dynamic>{
        'id': e.id,
        'businessId': e.businessId,
        'amount': e.amount,
        'category': e.category,
        'description': e.description,
        'currency': e.currency,
        'date': e.date.toIso8601String(),
      },
      Closing c => <String, dynamic>{
        'id': c.id,
        'businessId': c.businessId,
        'period': c.period,
        'startDate': c.startDate.toIso8601String(),
        'endDate': c.endDate.toIso8601String(),
        'income': c.income,
        'expenses': c.expenses,
        'profit': c.profit,
        'roi': c.roi,
        'salesCount': c.salesCount,
        'expensesCount': c.expensesCount,
        'soldProductsJson': c.soldProductsJson,
        'addedProductsJson': c.addedProductsJson,
        'bestSellerName': c.bestSellerName,
        'bestSellerQty': c.bestSellerQty,
        'paymentMethodsJson': c.paymentMethodsJson,
        'expenseCategoriesJson': c.expenseCategoriesJson,
        'totalDiscounts': c.totalDiscounts,
        'sellerStatsJson': c.sellerStatsJson,
        'costOfGoodsSold': c.costOfGoodsSold,
        'netProfit': c.netProfit,
        'transferredAmount': c.transferredAmount,
      },
      ProductCategory c => <String, dynamic>{
        'id': c.id,
        'businessId': c.businessId,
        'name': c.name,
        'parentId': c.parentId,
      },
      Seller s => <String, dynamic>{
        'id': s.id,
        'businessId': s.businessId,
        'name': s.name,
        'lastName': s.lastName,
        'phone': s.phone,
        'email': s.email,
        'ci': s.ci,
        'address': s.address,
        'role': s.role,
        'commissionRate': s.commissionRate,
        'salary': s.salary,
        'hireDate': s.hireDate.toIso8601String(),
        'isActive': s.isActive,
        'notes': s.notes,
      },
      SellerInventory s => <String, dynamic>{
        'id': s.id,
        'businessId': s.businessId,
        'sellerId': s.sellerId,
        'productId': s.productId,
        'productName': s.productName,
        'assignedQuantity': s.assignedQuantity,
      },
      Loan l => <String, dynamic>{
        'id': l.id,
        'borrowerName': l.borrowerName,
        'amount': l.amount,
        'interestRate': l.interestRate,
        'interestType': l.interestType,
        'frequency': l.frequency,
        'durationValue': l.durationValue,
        'startDate': l.startDate.toIso8601String(),
        'dueDate': l.dueDate.toIso8601String(),
        'isNotificationsEnabled': l.isNotificationsEnabled,
        'notes': l.notes,
        'remainingAmount': l.remainingAmount,
        'status': l.status,
        'cardId': l.cardId,
        'currency': l.currency,
        'borrowerId': l.borrowerId,
        'lateFeeType': l.lateFeeType,
        'lateFeeValue': l.lateFeeValue,
        'lastMoraAppliedDate': l.lastMoraAppliedDate?.toIso8601String(),
        'installments': l.installments
            .map(
              (Installment i) => <String, dynamic>{
                'number': i.number,
                'dueDate': i.dueDate.toIso8601String(),
                'amount': i.amount,
                'paidAmount': i.paidAmount,
                'status': i.status,
              },
            )
            .toList(),
      },
      LoanPayment p => <String, dynamic>{
        'id': p.id,
        'loanId': p.loanId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        'notes': p.notes,
        'cardId': p.cardId,
        'affectedInstallmentNumbers': p.affectedInstallmentNumbers,
      },
      Borrower b => <String, dynamic>{
        'id': b.id,
        'name': b.name,
        'lastName': b.lastName,
        'phone': b.phone,
        'address': b.address,
        'writtenLocation': b.writtenLocation,
        'riskLevel': b.riskLevel,
        'localPhotoPath': b.localPhotoPath,
        'personalReference': b.personalReference,
        'notes': b.notes,
        'registrationDate': b.registrationDate.toIso8601String(),
      },
      LoanActivity a => <String, dynamic>{
        'id': a.id,
        'loanId': a.loanId,
        'timestamp': a.timestamp.toIso8601String(),
        'action': a.action,
        'description': a.description,
      },
      _ => throw ArgumentError(
        'Modelo sin serialización: ${value.runtimeType}',
      ),
    };
  }

  static Object fromJson(String table, Map<String, dynamic> j) {
    return switch (table) {
      'categories' => Category(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        iconCode: _int(j, 'iconCode'),
        colorValue: _int(j, 'colorValue'),
        isCustom: _bool(j, 'isCustom'),
        monthlyBudget: _doubleOrNull(j, 'monthlyBudget'),
        type: _str(j, 'type', CategoryTypes.both),
      ),
      'transactions' => InternalTransaction(
        id: _str(j, 'id'),
        amount: _double(j, 'amount'),
        currency: _str(j, 'currency', 'CUP'),
        categoryId: _str(j, 'categoryId'),
        date: _date(j, 'date'),
        title: _str(j, 'title'),
        cardId: _strOrNull(j, 'cardId'),
      ),
      'cards' => AccountCard(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        balance: _double(j, 'balance'),
        currency: _str(j, 'currency', 'CUP'),
        cardNumber: _str(j, 'cardNumber'),
        expiryDate: _str(j, 'expiryDate'),
        colorValue: _int(j, 'colorValue'),
        isLocked: _bool(j, 'isLocked'),
        pin: _strOrNull(j, 'pin'),
        spendingLimit: _doubleOrNull(j, 'spendingLimit'),
        bankName: _strOrNull(j, 'bankName'),
        isCash: _bool(j, 'isCash'),
        accountType: _strOrNull(j, 'accountType'),
        interestEnabled: _bool(j, 'interestEnabled'),
        interestRateEA: _doubleOrNull(j, 'interestRateEA'),
        interestFrequency: _strOrNull(j, 'interestFrequency'),
        nextInterestAt: _dateOrNull(j, 'nextInterestAt'),
        creditLimit: _doubleOrNull(j, 'creditLimit'),
        cutoffDay: _intOrNull(j, 'cutoffDay'),
        paymentDueDay: _intOrNull(j, 'paymentDueDay'),
        annualInterestRate: _doubleOrNull(j, 'annualInterestRate'),
        monthlyManagementFee: _doubleOrNull(j, 'monthlyManagementFee'),
      ),
      'ai_chats' => ChatConversation(
        id: _str(j, 'id'),
        title: _str(j, 'title'),
        createdAt: _date(j, 'createdAt'),
        updatedAt: _date(j, 'updatedAt'),
        messages: _maps(j['messages'])
            .map(
              (Map<String, dynamic> m) => ChatMessage(
                role: _str(m, 'role', 'user'),
                text: _str(m, 'text'),
                timestamp: _date(m, 'timestamp'),
              ),
            )
            .toList(),
      ),
      'recurring_transactions' => RecurringTransaction(
        id: _str(j, 'id'),
        title: _str(j, 'title'),
        description: _str(j, 'description'),
        amount: _double(j, 'amount'),
        categoryId: _str(j, 'categoryId'),
        accountId: _str(j, 'accountId'),
        nextExecutionDate: _date(j, 'nextExecutionDate'),
        recurrence: _str(j, 'recurrence', 'mensual'),
        autoRegister: _bool(j, 'autoRegister'),
        isIncome: _bool(j, 'isIncome', true),
      ),
      'notifications' => NotificationItem(
        id: _str(j, 'id'),
        title: _str(j, 'title'),
        body: _str(j, 'body'),
        date: _date(j, 'date'),
        isRead: _bool(j, 'isRead'),
      ),
      'businesses' => Business(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        type: _str(j, 'type'),
        iconCode: _str(j, 'iconCode'),
        colorValue: _int(j, 'colorValue'),
        createdAt: _date(j, 'createdAt'),
        currency: _str(j, 'currency', 'CUP'),
        initialCapital: _double(j, 'initialCapital'),
        linkedCardId: _strOrNull(j, 'linkedCardId'),
      ),
      'products' => Product(
        id: _str(j, 'id'),
        businessId: _str(j, 'businessId'),
        name: _str(j, 'name'),
        description: _str(j, 'description'),
        sku: _str(j, 'sku'),
        investmentDate: _date(j, 'investmentDate'),
        initialQuantity: _double(j, 'initialQuantity'),
        costPerUnit: _double(j, 'costPerUnit'),
        currency: _str(j, 'currency', 'CUP'),
        totalInvestment: _double(j, 'totalInvestment'),
        additionalCosts: _double(j, 'additionalCosts'),
        currentStock: _double(j, 'currentStock'),
        salePrice: _double(j, 'salePrice'),
        unit: _str(j, 'unit', 'uds'),
        categoryId: _strOrNull(j, 'categoryId'),
        subcategoryId: _strOrNull(j, 'subcategoryId'),
      ),
      'sales' => Sale(
        id: _str(j, 'id'),
        businessId: _str(j, 'businessId'),
        items: _maps(j['items'])
            .map(
              (Map<String, dynamic> i) => SaleItem(
                productId: _str(i, 'productId'),
                productName: _str(i, 'productName'),
                quantity: _double(i, 'quantity'),
                unitPrice: _double(i, 'unitPrice'),
                subtotal: _double(i, 'subtotal'),
              ),
            )
            .toList(),
        total: _double(j, 'total'),
        paymentMethod: _str(j, 'paymentMethod'),
        date: _date(j, 'date'),
        discount: _double(j, 'discount'),
        clientName: _strOrNull(j, 'clientName'),
        status: _str(j, 'status', 'paid'),
        sellerId: _strOrNull(j, 'sellerId'),
        sellerName: _strOrNull(j, 'sellerName'),
      ),
      'business_expenses' => BusinessExpense(
        id: _str(j, 'id'),
        businessId: _str(j, 'businessId'),
        amount: _double(j, 'amount'),
        category: _str(j, 'category'),
        description: _str(j, 'description'),
        currency: _str(j, 'currency', 'CUP'),
        date: _date(j, 'date'),
      ),
      'closings' => Closing(
        id: _str(j, 'id'),
        businessId: _str(j, 'businessId'),
        period: _str(j, 'period'),
        startDate: _date(j, 'startDate'),
        endDate: _date(j, 'endDate'),
        income: _double(j, 'income'),
        expenses: _double(j, 'expenses'),
        profit: _double(j, 'profit'),
        roi: _double(j, 'roi'),
        salesCount: _int(j, 'salesCount'),
        expensesCount: _int(j, 'expensesCount'),
        soldProductsJson: _str(j, 'soldProductsJson', '[]'),
        addedProductsJson: _str(j, 'addedProductsJson', '[]'),
        bestSellerName: _str(j, 'bestSellerName'),
        bestSellerQty: _int(j, 'bestSellerQty'),
        paymentMethodsJson: _str(j, 'paymentMethodsJson', '{}'),
        expenseCategoriesJson: _str(j, 'expenseCategoriesJson', '{}'),
        totalDiscounts: _double(j, 'totalDiscounts'),
        sellerStatsJson: _str(j, 'sellerStatsJson', '{}'),
        costOfGoodsSold: _double(j, 'costOfGoodsSold'),
        netProfit: _double(j, 'netProfit'),
        transferredAmount: _double(j, 'transferredAmount'),
      ),
      'product_categories' => ProductCategory(
        id: _str(j, 'id'),
        businessId: _str(j, 'businessId'),
        name: _str(j, 'name'),
        parentId: _strOrNull(j, 'parentId'),
      ),
      'sellers' => Seller(
        id: _str(j, 'id'),
        businessId: _str(j, 'businessId'),
        name: _str(j, 'name'),
        lastName: _str(j, 'lastName'),
        phone: _str(j, 'phone'),
        email: _str(j, 'email'),
        ci: _str(j, 'ci'),
        address: _str(j, 'address'),
        role: _str(j, 'role'),
        commissionRate: _double(j, 'commissionRate'),
        salary: _double(j, 'salary'),
        hireDate: _date(j, 'hireDate'),
        isActive: _bool(j, 'isActive', true),
        notes: _str(j, 'notes'),
      ),
      'seller_inventory' => SellerInventory(
        id: _str(j, 'id'),
        businessId: _str(j, 'businessId'),
        sellerId: _str(j, 'sellerId'),
        productId: _str(j, 'productId'),
        productName: _str(j, 'productName'),
        assignedQuantity: _double(j, 'assignedQuantity'),
      ),
      'loans' => Loan(
        id: _str(j, 'id'),
        borrowerName: _str(j, 'borrowerName'),
        amount: _double(j, 'amount'),
        interestRate: _double(j, 'interestRate'),
        interestType: _str(j, 'interestType', 'simple'),
        frequency: _str(j, 'frequency', 'monthly'),
        durationValue: _int(j, 'durationValue'),
        startDate: _date(j, 'startDate'),
        dueDate: _date(j, 'dueDate'),
        isNotificationsEnabled: _bool(j, 'isNotificationsEnabled', true),
        notes: _strOrNull(j, 'notes'),
        remainingAmount: _double(j, 'remainingAmount'),
        status: _str(j, 'status', 'active'),
        cardId: _strOrNull(j, 'cardId'),
        currency: _str(j, 'currency', 'CUP'),
        borrowerId: _strOrNull(j, 'borrowerId'),
        lateFeeType: _str(j, 'lateFeeType', 'none'),
        lateFeeValue: _double(j, 'lateFeeValue'),
        lastMoraAppliedDate: _dateOrNull(j, 'lastMoraAppliedDate'),
        installments: _maps(j['installments'])
            .map(
              (Map<String, dynamic> i) => Installment(
                number: _int(i, 'number'),
                dueDate: _date(i, 'dueDate'),
                amount: _double(i, 'amount'),
                paidAmount: _double(i, 'paidAmount'),
                status: _str(i, 'status', 'pending'),
              ),
            )
            .toList(),
      ),
      'loan_payments' => LoanPayment(
        id: _str(j, 'id'),
        loanId: _str(j, 'loanId'),
        amount: _double(j, 'amount'),
        date: _date(j, 'date'),
        notes: _strOrNull(j, 'notes'),
        cardId: _strOrNull(j, 'cardId'),
        affectedInstallmentNumbers: (j['affectedInstallmentNumbers'] as List?)
            ?.map((dynamic e) => (e as num).toInt())
            .toList(),
      ),
      'borrowers' => Borrower(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        lastName: _str(j, 'lastName'),
        phone: _str(j, 'phone'),
        address: _str(j, 'address'),
        writtenLocation: _strOrNull(j, 'writtenLocation'),
        riskLevel: _str(j, 'riskLevel', 'low'),
        localPhotoPath: _strOrNull(j, 'localPhotoPath'),
        personalReference: _strOrNull(j, 'personalReference'),
        notes: _strOrNull(j, 'notes'),
        registrationDate: _date(j, 'registrationDate'),
      ),
      'loan_activities' => LoanActivity(
        id: _str(j, 'id'),
        loanId: _str(j, 'loanId'),
        timestamp: _date(j, 'timestamp'),
        action: _str(j, 'action'),
        description: _str(j, 'description'),
      ),
      _ => throw ArgumentError('Tabla desconocida: $table'),
    };
  }

  // --- Lectura tolerante (los datos vienen de otra versión de la app) ---

  static String _str(Map<String, dynamic> j, String key, [String? fallback]) {
    final Object? value = j[key];
    if (value is String && value.isNotEmpty) return value;
    return fallback ?? '';
  }

  static String? _strOrNull(Map<String, dynamic> j, String key) {
    final Object? value = j[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static double _double(Map<String, dynamic> j, String key) =>
      (j[key] as num?)?.toDouble() ?? 0;

  static double? _doubleOrNull(Map<String, dynamic> j, String key) =>
      (j[key] as num?)?.toDouble();

  static int _int(Map<String, dynamic> j, String key) =>
      (j[key] as num?)?.toInt() ?? 0;

  static int? _intOrNull(Map<String, dynamic> j, String key) =>
      (j[key] as num?)?.toInt();

  static bool _bool(
    Map<String, dynamic> j,
    String key, [
    bool fallback = false,
  ]) => j[key] is bool ? j[key] as bool : fallback;

  static DateTime _date(Map<String, dynamic> j, String key) =>
      _dateOrNull(j, key) ?? DateTime.now();

  static DateTime? _dateOrNull(Map<String, dynamic> j, String key) {
    final Object? value = j[key];
    return value is String ? DateTime.tryParse(value) : null;
  }

  static List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}
