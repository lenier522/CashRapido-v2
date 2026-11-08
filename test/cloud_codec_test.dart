import 'package:flutter_test/flutter_test.dart';

import 'package:cashrapido/models/borrower.dart';
import 'package:cashrapido/models/closing.dart';
import 'package:cashrapido/models/loan.dart';
import 'package:cashrapido/models/models.dart';
import 'package:cashrapido/models/sale.dart';
import 'package:cashrapido/services/cloud_codec.dart';

void main() {
  void expectRoundTrip(String table, Object model) {
    final Map<String, dynamic> json = CloudCodec.toJson(model);
    final Object decoded = CloudCodec.fromJson(table, json);

    expect(CloudCodec.toJson(decoded), json, reason: 'campos de $table');
    expect(CloudCodec.idOf(decoded), CloudCodec.idOf(model));
  }

  test('categoría y movimiento conservan todos sus campos', () {
    expectRoundTrip(
      'categories',
      Category(
        id: 'cat-1',
        name: 'Comida',
        iconCode: 58795,
        colorValue: 0xFF00AA55,
        isCustom: true,
        monthlyBudget: 250.5,
        type: CategoryTypes.expense,
      ),
    );

    expectRoundTrip(
      'transactions',
      InternalTransaction(
        id: 'tx-1',
        amount: 12.75,
        currency: 'USD',
        categoryId: 'cat-1',
        date: DateTime.utc(2026, 11, 6, 14, 30),
        title: 'Almuerzo',
        cardId: 'card-1',
      ),
    );
  });

  test('cuenta conserva saldo, PIN y datos de tarjeta de crédito', () {
    expectRoundTrip(
      'cards',
      AccountCard(
        id: 'card-1',
        name: 'VISA',
        balance: 1050.25,
        currency: 'CUP',
        cardNumber: '1234',
        expiryDate: '12/28',
        colorValue: 0xFF112233,
        isLocked: true,
        pin: '4321',
        spendingLimit: 500,
        bankName: 'BPA',
        accountType: AccountTypes.savings,
        interestEnabled: true,
        interestRateEA: 3.5,
        interestFrequency: 'monthly',
        nextInterestAt: DateTime.utc(2026, 12, 1),
        creditLimit: 2000,
        cutoffDay: 20,
        paymentDueDay: 5,
        annualInterestRate: 24,
        monthlyManagementFee: 50,
      ),
    );
  });

  test('préstamo conserva cuotas, mora y estado', () {
    expectRoundTrip(
      'loans',
      Loan(
        id: 'loan-1',
        borrowerName: 'Ana Pérez',
        amount: 1000,
        interestRate: 10,
        interestType: 'simple',
        frequency: 'monthly',
        durationValue: 3,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 4, 1),
        isNotificationsEnabled: true,
        notes: 'Sin aval',
        remainingAmount: 733.33,
        status: 'active',
        cardId: 'card-1',
        currency: 'CUP',
        borrowerId: 'borrower-1',
        lateFeeType: 'percent',
        lateFeeValue: 2,
        lastMoraAppliedDate: DateTime.utc(2026, 3, 1),
        installments: <Installment>[
          Installment(
            number: 1,
            dueDate: DateTime.utc(2026, 2, 1),
            amount: 333.33,
            paidAmount: 333.33,
            status: 'paid',
          ),
          Installment(
            number: 2,
            dueDate: DateTime.utc(2026, 3, 1),
            amount: 333.33,
            paidAmount: 0,
            status: 'overdue',
          ),
        ],
      ),
    );
  });

  test('venta conserva sus líneas y descuentos', () {
    expectRoundTrip(
      'sales',
      Sale(
        id: 'sale-1',
        businessId: 'biz-1',
        items: <SaleItem>[
          SaleItem(
            productId: 'p-1',
            productName: 'Café 1kg',
            quantity: 1.5,
            unitPrice: 120,
            subtotal: 180,
          ),
        ],
        total: 160,
        paymentMethod: 'Efectivo',
        date: DateTime.utc(2026, 11, 6),
        discount: 20,
        clientName: 'Luis',
        status: 'pending',
        sellerId: 'seller-1',
        sellerName: 'Marta',
      ),
    );
  });

  test('cierre, deudor y conversación de IA conservan todo', () {
    expectRoundTrip(
      'closings',
      Closing(
        id: 'close-1',
        businessId: 'biz-1',
        period: 'monthly',
        startDate: DateTime.utc(2026, 10, 1),
        endDate: DateTime.utc(2026, 10, 31),
        income: 5000,
        expenses: 1800,
        profit: 3200,
        roi: 64,
        salesCount: 40,
        expensesCount: 12,
        soldProductsJson: '[{"id":"p-1","qty":2}]',
        addedProductsJson: '[{"id":"p-2","qty":5}]',
        bestSellerName: 'Café 1kg',
        bestSellerQty: 18,
        paymentMethodsJson: '{"Efectivo": 3000}',
        expenseCategoriesJson: '{"Insumos": 900}',
        totalDiscounts: 75,
        sellerStatsJson: '{"Marta": 1200}',
        costOfGoodsSold: 1400,
        netProfit: 1800,
        transferredAmount: 500,
      ),
    );

    expectRoundTrip(
      'borrowers',
      Borrower(
        id: 'borrower-1',
        name: 'Ana',
        lastName: 'Pérez',
        phone: '5551234',
        address: 'Calle 1',
        writtenLocation: 'Centro',
        riskLevel: 'medium',
        localPhotoPath: '/fotos/ana.jpg',
        personalReference: 'María',
        notes: 'Paga puntual',
        registrationDate: DateTime.utc(2026, 2, 14),
      ),
    );

    final DateTime created = DateTime.utc(2026, 11, 6, 9);
    expectRoundTrip(
      'ai_chats',
      ChatConversation(
        id: 'chat-1',
        title: 'Resumen del mes',
        createdAt: created,
        updatedAt: created.add(const Duration(minutes: 5)),
        messages: <ChatMessage>[
          ChatMessage(role: 'user', text: '¿Cuánto gasté?', timestamp: created),
          ChatMessage(
            role: 'model',
            text: 'Gastaste 120 CUP.',
            timestamp: created.add(const Duration(minutes: 1)),
          ),
        ],
      ),
    );
  });
}
