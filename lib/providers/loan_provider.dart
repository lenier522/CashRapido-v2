import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../models/loan.dart';
import '../models/borrower.dart';
import '../models/loan_activity.dart';
import '../services/notification_service.dart';
import 'app_provider.dart';

class LoanProvider with ChangeNotifier {
  late Box<Loan> _loanBox;
  late Box<LoanPayment> _paymentBox;
  late Box<Borrower> _borrowerBox;
  late Box<LoanActivity> _activityBox;

  List<Loan> _loans = [];
  List<LoanPayment> _payments = [];
  List<Borrower> _borrowers = [];
  List<LoanActivity> _activities = [];
  bool _isLoading = true;
  final Uuid _uuid = const Uuid();

  // Getters
  bool get isLoading => _isLoading;
  List<Loan> get loans => _loans;
  List<LoanPayment> get payments => _payments;
  List<Borrower> get borrowers => _borrowers;
  List<LoanActivity> get activities => _activities;

  List<Loan> get activeLoans => _loans.where((l) => l.status == 'active' || l.status == 'overdue').toList();
  List<Loan> get paidLoans => _loans.where((l) => l.status == 'paid').toList();
  List<Loan> get overdueLoans => _loans.where((l) => l.status == 'overdue').toList();

  // ========== INITIALIZATION & ENCRYPTION ==========

  Future<Box<T>> _openEncryptedBox<T>(String name) async {
    final encryptionKey = sha256.convert(utf8.encode("cashrapido_secure_loans_salt_2026")).bytes;
    try {
      return await Hive.openBox<T>(name, encryptionCipher: HiveAesCipher(encryptionKey));
    } catch (e) {
      // Fallback: If it was already opened unencrypted or can't decrypt, open it unencrypted
      return await Hive.openBox<T>(name);
    }
  }

  Future<void> init({AppProvider? appProvider}) async {
    _loanBox = await _openEncryptedBox<Loan>('loans');
    _paymentBox = await _openEncryptedBox<LoanPayment>('loan_payments');
    _borrowerBox = await _openEncryptedBox<Borrower>('borrowers');
    _activityBox = await _openEncryptedBox<LoanActivity>('loan_activities');

    _fetchData();

    if (appProvider != null) {
      await applyMoraPenalties(appProvider);
      await checkOverdueLoans(appProvider);
    }

    _isLoading = false;
    notifyListeners();
  }

  void _fetchData() {
    _loans = _loanBox.values.toList();
    _payments = _paymentBox.values.toList();
    _borrowers = _borrowerBox.values.toList();
    _activities = _activityBox.values.toList();

    _loans.sort((a, b) => b.startDate.compareTo(a.startDate));
    _payments.sort((a, b) => b.date.compareTo(a.date));
    _borrowers.sort((a, b) => a.name.compareTo(b.name));
    _activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ========== METRICS & REPORTS DATA ==========

  double getMetricTotalLoaned(String currency) {
    return _loans
        .where((l) => l.currency == currency)
        .fold(0.0, (sum, l) => sum + l.amount);
  }

  double getMetricOutstandingBalance(String currency) {
    return _loans
        .where((l) => l.currency == currency && l.status != 'written_off')
        .fold(0.0, (sum, l) => sum + l.remainingAmount);
  }

  double getMetricTotalCollected(String currency) {
    double total = 0.0;
    for (var l in _loans) {
      if (l.currency == currency) {
        final totalWithInterest = calculateTotalWithInterest(l.amount, l.interestRate, l.interestType, l.durationValue);
        total += (totalWithInterest - l.remainingAmount);
      }
    }
    return total;
  }

  double getMetricTotalDisbursedToday(String currency) {
    final today = DateTime.now();
    return _loans
        .where((l) => l.currency == currency && 
                      l.startDate.year == today.year && 
                      l.startDate.month == today.month && 
                      l.startDate.day == today.day)
        .fold(0.0, (sum, l) => sum + l.amount);
  }

  double getMetricTotalCollectedToday(String currency) {
    final today = DateTime.now();
    return _payments
        .where((p) {
          final l = _loans.firstWhere((item) => item.id == p.loanId, orElse: () => Loan(id: '', borrowerName: '', amount: 0, interestRate: 0, interestType: '', frequency: '', durationValue: 0, startDate: DateTime.now(), dueDate: DateTime.now(), isNotificationsEnabled: false, remainingAmount: 0, status: '', currency: ''));
          return l.id.isNotEmpty && l.currency == currency && 
                 p.date.year == today.year && 
                 p.date.month == today.month && 
                 p.date.day == today.day;
        })
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  List<LoanPayment> getPaymentsForLoan(String loanId) {
    return _payments.where((p) => p.loanId == loanId).toList();
  }

  int getMorososCount() {
    // Unique borrowers with overdue installments
    final uniqueBorrowers = <String>{};
    for (var l in _loans) {
      if (l.status == 'overdue') {
        uniqueBorrowers.add(l.borrowerId ?? l.borrowerName);
      } else {
        bool hasOverdueInstallment = l.installments.any((inst) => inst.status == 'overdue');
        if (hasOverdueInstallment) {
          uniqueBorrowers.add(l.borrowerId ?? l.borrowerName);
        }
      }
    }
    return uniqueBorrowers.length;
  }

  double getMetricGainGenerated(String currency) {
    // Intereses generados (Cobrados + Estimados devengados)
    double profit = 0.0;
    for (var l in _loans) {
      if (l.currency == currency && l.status != 'written_off') {
        final totalWithInterest = calculateTotalWithInterest(l.amount, l.interestRate, l.interestType, l.durationValue);
        final interestExpected = totalWithInterest - l.amount;
        profit += interestExpected;
      }
    }
    return profit;
  }

  // ========== BORROWER OPERATIONS ==========

  Future<void> createBorrower({
    required String name,
    required String lastName,
    required String phone,
    required String address,
    String? writtenLocation,
    required String riskLevel,
    String? localPhotoPath,
    String? personalReference,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final borrower = Borrower(
      id: id,
      name: name,
      lastName: lastName,
      phone: phone,
      address: address,
      writtenLocation: writtenLocation,
      riskLevel: riskLevel,
      localPhotoPath: localPhotoPath,
      personalReference: personalReference,
      notes: notes,
      registrationDate: DateTime.now(),
    );

    await _borrowerBox.put(id, borrower);
    _borrowers.add(borrower);
    _borrowers.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> editBorrower(Borrower updated) async {
    await _borrowerBox.put(updated.id, updated);
    final idx = _borrowers.indexWhere((b) => b.id == updated.id);
    if (idx != -1) {
      _borrowers[idx] = updated;
      _borrowers.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteBorrower(String id) async {
    await _borrowerBox.delete(id);
    _borrowers.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  // ========== AUDIT LOGGER HELPERS ==========

  Future<void> addActivity(String loanId, String action, String description) async {
    final id = _uuid.v4();
    final activity = LoanActivity(
      id: id,
      loanId: loanId,
      timestamp: DateTime.now(),
      action: action,
      description: description,
    );

    await _activityBox.put(id, activity);
    _activities.insert(0, activity);
    notifyListeners();
  }

  List<LoanActivity> getActivitiesForLoan(String loanId) {
    return _activities.where((a) => a.loanId == loanId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ========== CALCULATIONS & AMORTIZATION ==========

  double calculateTotalWithInterest(double principal, double rate, String type, int duration) {
    if (rate <= 0) return principal;
    switch (type) {
      case 'fixed':
        return principal + rate;
      case 'simple':
        return principal + (principal * (rate / 100));
      case 'compound':
        return principal * pow(1 + (rate / 100), duration);
      default:
        return principal;
    }
  }

  List<Installment> generateAmortizationSchedule({
    required double principal,
    required double rate,
    required String interestType,
    required String frequency,
    required int durationValue,
    required DateTime startDate,
  }) {
    final totalRepayment = calculateTotalWithInterest(principal, rate, interestType, durationValue);
    final installmentAmount = totalRepayment / durationValue;

    final schedule = <Installment>[];
    var currentDate = startDate;

    for (int i = 1; i <= durationValue; i++) {
      switch (frequency) {
        case 'daily':
          currentDate = currentDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case 'biweekly': // quincenal
          currentDate = currentDate.add(const Duration(days: 15));
          break;
        case 'monthly':
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
          break;
        case 'single':
        default:
          currentDate = currentDate.add(const Duration(days: 30));
          break;
      }

      schedule.add(Installment(
        number: i,
        dueDate: currentDate,
        amount: installmentAmount,
        paidAmount: 0.0,
        status: 'pending',
      ));
    }
    return schedule;
  }

  // ========== LOAN OPERATIONS ==========

  Future<void> createLoan({
    required String borrowerName,
    String? borrowerId,
    required double amount,
    required double interestRate,
    required String interestType, // 'simple', 'compound', 'fixed'
    required String frequency, // 'daily', 'weekly', 'biweekly', 'monthly', 'single'
    required int durationValue,
    required DateTime startDate,
    required DateTime dueDate,
    required bool isNotificationsEnabled,
    String? notes,
    String? cardId,
    required String currency,
    String lateFeeType = 'none',
    double lateFeeValue = 0.0,
    AppProvider? appProvider,
    bool deductFromCard = false,
  }) async {
    final id = _uuid.v4();
    final totalExpected = calculateTotalWithInterest(amount, interestRate, interestType, durationValue);

    // Schedule installments
    final installmentsList = generateAmortizationSchedule(
      principal: amount,
      rate: interestRate,
      interestType: interestType,
      frequency: frequency,
      durationValue: durationValue,
      startDate: startDate,
    );

    final loan = Loan(
      id: id,
      borrowerName: borrowerName,
      borrowerId: borrowerId,
      amount: amount,
      interestRate: interestRate,
      interestType: interestType,
      frequency: frequency,
      durationValue: durationValue,
      startDate: startDate,
      dueDate: dueDate,
      isNotificationsEnabled: isNotificationsEnabled,
      notes: notes,
      remainingAmount: totalExpected,
      status: DateTime.now().isAfter(dueDate) ? 'overdue' : 'active',
      cardId: cardId,
      currency: currency,
      lateFeeType: lateFeeType,
      lateFeeValue: lateFeeValue,
      installments: installmentsList,
    );

    await _loanBox.put(id, loan);
    _loans.insert(0, loan);

    await addActivity(id, "Creado", "Préstamo registrado por un total de \$${amount.toStringAsFixed(2)} $currency a retornar \$${totalExpected.toStringAsFixed(2)}.");

    if (deductFromCard && cardId != null && appProvider != null) {
      await appProvider.addTransaction(
        amount: -amount,
        title: "Desembolso Préstamo: $borrowerName",
        categoryId: 'general',
        currency: currency,
        cardId: cardId,
        date: startDate,
      );
      await addActivity(id, "Desembolsado", "Monto de \$${amount.toStringAsFixed(2)} $currency deducido de la cuenta vinculada.");
    }

    await _rescheduleLoanNotifications(loan);

    notifyListeners();
  }

  Future<void> editLoan(Loan updatedLoan) async {
    final index = _loans.indexWhere((l) => l.id == updatedLoan.id);
    if (index == -1) return;

    await _loanBox.put(updatedLoan.id, updatedLoan);
    _loans[index] = updatedLoan;
    
    await addActivity(updatedLoan.id, "Editado", "Los parámetros del préstamo fueron actualizados.");
    await _rescheduleLoanNotifications(updatedLoan);
    notifyListeners();
  }

  Future<void> deleteLoan(String loanId) async {
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index == -1) return;

    await _loanBox.delete(loanId);
    _loans.removeAt(index);

    // Delete payments
    final paymentsToDelete = _payments.where((p) => p.loanId == loanId).toList();
    for (var p in paymentsToDelete) {
      await _paymentBox.delete(p.id);
      _payments.removeWhere((item) => item.id == p.id);
    }

    // Delete activities
    final activitiesToDelete = _activities.where((a) => a.loanId == loanId).toList();
    for (var a in activitiesToDelete) {
      await _activityBox.delete(a.id);
      _activities.removeWhere((item) => item.id == a.id);
    }

    await _cancelAllLoanNotifications(loanId);

    notifyListeners();
  }

  Future<void> refinanceLoan({
    required String oldLoanId,
    required double newAmount,
    required double newInterestRate,
    required String newInterestType,
    required String newFrequency,
    required int newDurationValue,
    required DateTime newStartDate,
    required DateTime newDueDate,
    required String newCurrency,
    String? cardId,
    String lateFeeType = 'none',
    double lateFeeValue = 0.0,
    AppProvider? appProvider,
  }) async {
    final oldIdx = _loans.indexWhere((l) => l.id == oldLoanId);
    if (oldIdx == -1) return;

    final oldLoan = _loans[oldIdx];
    final remainingDebt = oldLoan.remainingAmount;

    // 1. Close old loan as refinanced
    final closedLoan = oldLoan.copyWith(
      status: 'refinanced',
      remainingAmount: 0.0,
    );
    await _loanBox.put(oldLoanId, closedLoan);
    _loans[oldIdx] = closedLoan;

    await addActivity(oldLoanId, "Refinanciado", "El saldo deudor restante de \$${remainingDebt.toStringAsFixed(2)} fue refinanciado en un nuevo acuerdo.");

    // 2. Create new loan (Principal = newAmount + remaining debt, or simply newAmount if remaining debt is already added in UI)
    await createLoan(
      borrowerName: oldLoan.borrowerName,
      borrowerId: oldLoan.borrowerId,
      amount: newAmount,
      interestRate: newInterestRate,
      interestType: newInterestType,
      frequency: newFrequency,
      durationValue: newDurationValue,
      startDate: newStartDate,
      dueDate: newDueDate,
      isNotificationsEnabled: oldLoan.isNotificationsEnabled,
      notes: "Refinanciación del préstamo previo del ${oldLoan.startDate.day}/${oldLoan.startDate.month}/${oldLoan.startDate.year}.",
      cardId: cardId,
      currency: newCurrency,
      lateFeeType: lateFeeType,
      lateFeeValue: lateFeeValue,
      appProvider: appProvider,
      deductFromCard: false, // Do not disburse again since it represents a rollover
    );
  }

  Future<void> markAsLost(String loanId) async {
    final idx = _loans.indexWhere((l) => l.id == loanId);
    if (idx == -1) return;

    final loan = _loans[idx];
    final remainingDebt = loan.remainingAmount;

    final updated = loan.copyWith(
      status: 'written_off',
      remainingAmount: remainingDebt, // keep for records, but mark status
    );

    await _loanBox.put(loanId, updated);
    _loans[idx] = updated;

    await addActivity(loanId, "Pérdida", "El préstamo ha sido declarado incobrable (Pérdida de \$${remainingDebt.toStringAsFixed(2)} ${loan.currency}).");
    notifyListeners();
  }

  // ========== PAYMENT OPERATIONS (QUICK COLLECTION) ==========

  Future<void> addPayment({
    required String loanId,
    required double amount,
    String? cardId,
    String? notes,
    DateTime? date,
    AppProvider? appProvider,
    bool depositToCard = false,
  }) async {
    final loanIndex = _loans.indexWhere((l) => l.id == loanId);
    if (loanIndex == -1) return;

    final loan = _loans[loanIndex];
    final paymentDate = date ?? DateTime.now();
    final paymentId = _uuid.v4();

    // Deduct from remaining balance
    double newRemaining = loan.remainingAmount - amount;
    if (newRemaining < 0) newRemaining = 0;

    // Flexible Installments Allocation (Partial, Advanced, Multiple)
    final updatedInstallments = List<Installment>.from(loan.installments);
    double amountLeft = amount;
    final affectedNumbers = <int>[];

    for (int i = 0; i < updatedInstallments.length; i++) {
      if (amountLeft <= 0) break;

      final inst = updatedInstallments[i];
      if (inst.status == 'paid') continue;

      final needed = inst.remainingAmount;
      affectedNumbers.add(inst.number);

      if (amountLeft >= needed) {
        updatedInstallments[i] = inst.copyWith(
          paidAmount: inst.amount,
          status: 'paid',
        );
        amountLeft -= needed;
      } else {
        updatedInstallments[i] = inst.copyWith(
          paidAmount: inst.paidAmount + amountLeft,
          status: 'partial',
        );
        amountLeft = 0.0;
      }
    }

    String newStatus = loan.status;
    if (newRemaining == 0) {
      newStatus = 'paid';
    } else if (paymentDate.isAfter(loan.dueDate)) {
      newStatus = 'overdue';
    } else {
      // Check if any installment remains overdue
      bool hasOverdue = updatedInstallments.any((inst) => inst.status == 'overdue');
      newStatus = hasOverdue ? 'overdue' : 'active';
    }

    final updatedLoan = loan.copyWith(
      remainingAmount: newRemaining,
      status: newStatus,
      installments: updatedInstallments,
    );

    // Save payment
    final payment = LoanPayment(
      id: paymentId,
      loanId: loanId,
      amount: amount,
      date: paymentDate,
      notes: notes,
      cardId: cardId,
      affectedInstallmentNumbers: affectedNumbers,
    );

    await _paymentBox.put(paymentId, payment);
    _payments.insert(0, payment);

    // Update loan
    await _loanBox.put(loanId, updatedLoan);
    _loans[loanIndex] = updatedLoan;

    await addActivity(loanId, "Cobro", "Cobro registrado por \$${amount.toStringAsFixed(2)} ${loan.currency}. Afectó cuotas: ${affectedNumbers.join(', ')}. Pendiente: \$${newRemaining.toStringAsFixed(2)}.");

    // Balance integration
    if (depositToCard && cardId != null && appProvider != null) {
      await appProvider.addTransaction(
        amount: amount,
        title: "Cobro Préstamo: ${loan.borrowerName}",
        categoryId: 'cat_other_income',
        currency: loan.currency,
        cardId: cardId,
        date: paymentDate,
      );
    }

    await _rescheduleLoanNotifications(updatedLoan);

    notifyListeners();
  }

  Future<void> deletePayment(String paymentId) async {
    final paymentIndex = _payments.indexWhere((p) => p.id == paymentId);
    if (paymentIndex == -1) return;

    final payment = _payments[paymentIndex];
    final loanIndex = _loans.indexWhere((l) => l.id == payment.loanId);

    if (loanIndex != -1) {
      final loan = _loans[loanIndex];
      final maxAllowed = calculateTotalWithInterest(loan.amount, loan.interestRate, loan.interestType, loan.durationValue);
      
      double newRemaining = loan.remainingAmount + payment.amount;
      if (newRemaining > maxAllowed) newRemaining = maxAllowed;

      // Revert installments
      final updatedInstallments = List<Installment>.from(loan.installments);
      double amountToRevert = payment.amount;

      // Reverse walk
      final affected = payment.affectedInstallmentNumbers ?? [];
      for (var num in affected.reversed) {
        final idx = updatedInstallments.indexWhere((inst) => inst.number == num);
        if (idx != -1) {
          final inst = updatedInstallments[idx];
          // Simple revert strategy: subtract the payment's portion
          double currentPaid = inst.paidAmount;
          double newPaid = currentPaid - amountToRevert;
          if (newPaid < 0) {
            amountToRevert -= currentPaid;
            newPaid = 0.0;
          } else {
            amountToRevert = 0.0;
          }

          String newInstStatus = 'pending';
          if (newPaid > 0) {
            newInstStatus = 'partial';
          } else if (DateTime.now().isAfter(inst.dueDate)) {
            newInstStatus = 'overdue';
          }

          updatedInstallments[idx] = inst.copyWith(
            paidAmount: newPaid,
            status: newInstStatus,
          );
        }
      }

      String newStatus = loan.status;
      if (newRemaining > 0) {
        newStatus = DateTime.now().isAfter(loan.dueDate) ? 'overdue' : 'active';
      } else {
        newStatus = 'paid';
      }

      final updatedLoan = loan.copyWith(
        remainingAmount: newRemaining,
        status: newStatus,
        installments: updatedInstallments,
      );

      await _loanBox.put(loan.id, updatedLoan);
      _loans[loanIndex] = updatedLoan;

      await addActivity(loan.id, "Eliminar Cobro", "Se anuló el cobro de \$${payment.amount.toStringAsFixed(2)} ${loan.currency}.");
      await _rescheduleLoanNotifications(updatedLoan);
    }

    await _paymentBox.delete(paymentId);
    _payments.removeAt(paymentIndex);

    notifyListeners();
  }

  // ========== AUTOMATIC MORA PENALTY CALCULATIONS ==========

  Future<void> applyMoraPenalties(AppProvider appProvider) async {
    final now = DateTime.now();
    bool updated = false;

    for (var i = 0; i < _loans.length; i++) {
      final l = _loans[i];
      if (l.status == 'paid' || l.status == 'written_off' || l.status == 'refinanced') continue;

      // Only evaluate if late fees are active
      if (l.lateFeeType == 'none' || l.lateFeeValue <= 0.0) continue;

      // Avoid compounding multiple checks on the exact same calendar day
      if (l.lastMoraAppliedDate != null &&
          l.lastMoraAppliedDate!.year == now.year &&
          l.lastMoraAppliedDate!.month == now.month &&
          l.lastMoraAppliedDate!.day == now.day) {
        continue;
      }

      var currentLoan = l;
      double moraAcumulada = 0.0;
      final updatedInstallments = List<Installment>.from(currentLoan.installments);
      bool installmentsUpdated = false;

      for (int k = 0; k < updatedInstallments.length; k++) {
        final inst = updatedInstallments[k];
        if (inst.status == 'paid') continue;

        if (now.isAfter(inst.dueDate)) {
          // It's overdue!
          final daysLate = now.difference(inst.dueDate).inDays;
          if (daysLate > 0) {
            // Apply late fee
            double fee = 0.0;
            if (currentLoan.lateFeeType == 'fixed') {
              // Apply fixed fee once
              if (inst.status != 'overdue') {
                fee = currentLoan.lateFeeValue;
              }
            } else if (currentLoan.lateFeeType == 'percent') {
              // Apply daily percentage
              fee = inst.remainingAmount * (currentLoan.lateFeeValue / 100) * daysLate;
              // But let's only apply the incremental amount for today
              double alreadyApplied = 0.0;
              if (currentLoan.lastMoraAppliedDate != null && currentLoan.lastMoraAppliedDate!.isAfter(inst.dueDate)) {
                final previouslyLateDays = currentLoan.lastMoraAppliedDate!.difference(inst.dueDate).inDays;
                alreadyApplied = inst.remainingAmount * (currentLoan.lateFeeValue / 100) * previouslyLateDays;
              }
              fee = max(0.0, fee - alreadyApplied);
            }

            if (fee > 0.0) {
              moraAcumulada += fee;
              updatedInstallments[k] = inst.copyWith(
                amount: inst.amount + fee,
                status: 'overdue',
              );
            } else {
              updatedInstallments[k] = inst.copyWith(status: 'overdue');
            }
            installmentsUpdated = true;
          }
        }
      }

      if (moraAcumulada > 0.0 || installmentsUpdated) {
        currentLoan = currentLoan.copyWith(
          remainingAmount: currentLoan.remainingAmount + moraAcumulada,
          lastMoraAppliedDate: now,
          status: 'overdue',
          installments: updatedInstallments,
        );

        await _loanBox.put(currentLoan.id, currentLoan);
        _loans[i] = currentLoan;
        updated = true;

        if (moraAcumulada > 0.0) {
          await addActivity(currentLoan.id, "Mora", "Recargo automático de mora aplicado: \$${moraAcumulada.toStringAsFixed(2)} ${currentLoan.currency} por cuotas vencidas.");
          
          if (currentLoan.isNotificationsEnabled) {
            await appProvider.addNotificationItem(
              title: "⚠️ Mora Aplicada: ${currentLoan.borrowerName}",
              body: "Se ha sumado \$${moraAcumulada.toStringAsFixed(2)} ${currentLoan.currency} de penalización por atraso.",
            );
          }
        }
      }
    }

    if (updated) {
      _fetchData();
      notifyListeners();
    }
  }

  Future<void> checkOverdueLoans(AppProvider appProvider) async {
    final now = DateTime.now();
    bool updated = false;

    for (var i = 0; i < _loans.length; i++) {
      final l = _loans[i];
      if (l.status == 'active' && now.isAfter(l.dueDate)) {
        final updatedLoan = l.copyWith(status: 'overdue');
        await _loanBox.put(l.id, updatedLoan);
        _loans[i] = updatedLoan;
        updated = true;

        await addActivity(l.id, "Vencido", "El plazo principal de amortización ha finalizado.");

        if (l.isNotificationsEnabled) {
          await appProvider.addNotificationItem(
            title: "⚠️ Préstamo Vencido: ${l.borrowerName}",
            body: "El préstamo de \$${l.amount.toStringAsFixed(2)} ${l.currency} venció el ${l.dueDate.day}/${l.dueDate.month}/${l.dueDate.year}.",
          );
        }
      }
    }

    if (updated) {
      _fetchData();
      notifyListeners();
    }
  }

  // ========== BACKUPS SYSTEM (EXPORT / IMPORT JSON) ==========

  String exportBackupData() {
    final data = {
      'borrowers': _borrowers.map((b) => {
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
      }).toList(),
      'loans': _loans.map((l) => {
        'id': l.id,
        'borrowerName': l.borrowerName,
        'borrowerId': l.borrowerId,
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
        'lateFeeType': l.lateFeeType,
        'lateFeeValue': l.lateFeeValue,
        'lastMoraAppliedDate': l.lastMoraAppliedDate?.toIso8601String(),
        'installments': l.installments.map((inst) => {
          'number': inst.number,
          'dueDate': inst.dueDate.toIso8601String(),
          'amount': inst.amount,
          'paidAmount': inst.paidAmount,
          'status': inst.status,
        }).toList(),
      }).toList(),
      'payments': _payments.map((p) => {
        'id': p.id,
        'loanId': p.loanId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        'notes': p.notes,
        'cardId': p.cardId,
        'affectedInstallmentNumbers': p.affectedInstallmentNumbers,
      }).toList(),
      'activities': _activities.map((a) => {
        'id': a.id,
        'loanId': a.loanId,
        'timestamp': a.timestamp.toIso8601String(),
        'action': a.action,
        'description': a.description,
      }).toList(),
    };
    return jsonEncode(data);
  }

  Future<bool> importBackupData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // 1. Clear existing boxes
      await _borrowerBox.clear();
      await _loanBox.clear();
      await _paymentBox.clear();
      await _activityBox.clear();

      // 2. Import Borrowers
      if (data.containsKey('borrowers')) {
        for (var b in data['borrowers']) {
          final borrower = Borrower(
            id: b['id'],
            name: b['name'],
            lastName: b['lastName'],
            phone: b['phone'],
            address: b['address'],
            writtenLocation: b['writtenLocation'],
            riskLevel: b['riskLevel'],
            localPhotoPath: b['localPhotoPath'],
            personalReference: b['personalReference'],
            notes: b['notes'],
            registrationDate: DateTime.parse(b['registrationDate']),
          );
          await _borrowerBox.put(borrower.id, borrower);
        }
      }

      // 3. Import Loans
      if (data.containsKey('loans')) {
        for (var l in data['loans']) {
          final List<Installment> insts = [];
          if (l.containsKey('installments')) {
            for (var inst in l['installments']) {
              insts.add(Installment(
                number: inst['number'],
                dueDate: DateTime.parse(inst['dueDate']),
                amount: (inst['amount'] as num).toDouble(),
                paidAmount: (inst['paidAmount'] as num).toDouble(),
                status: inst['status'],
              ));
            }
          }

          final loan = Loan(
            id: l['id'],
            borrowerName: l['borrowerName'],
            borrowerId: l['borrowerId'],
            amount: (l['amount'] as num).toDouble(),
            interestRate: (l['interestRate'] as num).toDouble(),
            interestType: l['interestType'],
            frequency: l['frequency'],
            durationValue: l['durationValue'],
            startDate: DateTime.parse(l['startDate']),
            dueDate: DateTime.parse(l['dueDate']),
            isNotificationsEnabled: l['isNotificationsEnabled'],
            notes: l['notes'],
            remainingAmount: (l['remainingAmount'] as num).toDouble(),
            status: l['status'],
            cardId: l['cardId'],
            currency: l['currency'],
            lateFeeType: l['lateFeeType'] ?? 'none',
            lateFeeValue: (l['lateFeeValue'] as num?)?.toDouble() ?? 0.0,
            lastMoraAppliedDate: l['lastMoraAppliedDate'] != null ? DateTime.parse(l['lastMoraAppliedDate']) : null,
            installments: insts,
          );
          await _loanBox.put(loan.id, loan);
        }
      }

      // 4. Import Payments
      if (data.containsKey('payments')) {
        for (var p in data['payments']) {
          final List<int> affected = [];
          if (p.containsKey('affectedInstallmentNumbers')) {
            affected.addAll(List<int>.from(p['affectedInstallmentNumbers']));
          }

          final payment = LoanPayment(
            id: p['id'],
            loanId: p['loanId'],
            amount: (p['amount'] as num).toDouble(),
            date: DateTime.parse(p['date']),
            notes: p['notes'],
            cardId: p['cardId'],
            affectedInstallmentNumbers: affected,
          );
          await _paymentBox.put(payment.id, payment);
        }
      }

      // 5. Import Activities
      if (data.containsKey('activities')) {
        for (var a in data['activities']) {
          final activity = LoanActivity(
            id: a['id'],
            loanId: a['loanId'],
            timestamp: DateTime.parse(a['timestamp']),
            action: a['action'],
            description: a['description'],
          );
          await _activityBox.put(activity.id, activity);
        }
      }

      _fetchData();
      for (var loan in _loans) {
        await _rescheduleLoanNotifications(loan);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Import Error: $e");
      return false;
    }
  }

  Future<void> _rescheduleLoanNotifications(Loan loan) async {
    for (int i = 1; i <= 100; i++) {
      await NotificationService().cancelInstallmentReminder(loan.id, i);
    }

    if (loan.isNotificationsEnabled && (loan.status == 'active' || loan.status == 'overdue')) {
      for (var inst in loan.installments) {
        if (inst.status != 'paid') {
          await NotificationService().scheduleInstallmentReminder(
            langCode: 'es',
            loanId: loan.id,
            installmentNumber: inst.number,
            borrowerName: loan.borrowerName,
            amount: inst.amount,
            currency: loan.currency,
            dueDate: inst.dueDate,
          );
        }
      }
    }
  }

  Future<void> _cancelAllLoanNotifications(String loanId) async {
    for (int i = 1; i <= 100; i++) {
      await NotificationService().cancelInstallmentReminder(loanId, i);
    }
  }
}
