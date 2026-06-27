import 'dart:convert';
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../models/sale.dart';
import '../models/loan.dart';
import '../models/closing.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class ExportService {
  // --- Formatters ---
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatCurrency(double amount) {
    return amount.toFormattedString(2);
  }

  String _getTransactionType(InternalTransaction trans) {
    if (trans.title.toLowerCase().contains('transfer')) return 'Transferencia';
    return trans.amount > 0 ? 'Ingreso' : 'Gasto';
  }

  double _convertCurrency(
    double amount,
    String fromCurrency,
    String toCurrency,
    Map<String, double> rates,
    String mainCurrency,
  ) {
    if (fromCurrency == toCurrency) return amount;

    double amountInMain = amount;
    if (fromCurrency != mainCurrency) {
      final rateToMain = rates[fromCurrency];
      if (rateToMain != null && rateToMain > 0) {
        amountInMain = amount * rateToMain;
      }
    }

    if (toCurrency != mainCurrency) {
      final rateFromMain = rates[toCurrency];
      if (rateFromMain != null && rateFromMain > 0) {
        return amountInMain / rateFromMain;
      }
    }

    return amountInMain;
  }

  // --- Constants ---
  static const _primaryColor = PdfColors.deepPurple;

  static const _greyColor = PdfColors.grey600;

  // --- Main Methods ---

  Future<String> exportToExcel({
    required List<InternalTransaction> transactions,
    required List<Category> categories,
    required List<AccountCard> cards,
    required Map<String, double> exchangeRates,
    required String mainCurrency,
    List<dynamic> businesses = const [],
    List<dynamic> products = const [],
    List<dynamic> sales = const [],
    List<dynamic> businessExpenses = const [],
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();

    // Define Styles
    final xlsio.Style headerStyle = workbook.styles.add('HeaderStyle');
    headerStyle.fontName = 'Calibri';
    headerStyle.bold = true;
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.backColor = '#4527A0'; // Deep Purple
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    final xlsio.Style subHeaderStyle = workbook.styles.add('SubHeaderStyle');
    subHeaderStyle.fontName = 'Calibri';
    subHeaderStyle.bold = true;
    subHeaderStyle.fontColor = '#4527A0';
    subHeaderStyle.hAlign = xlsio.HAlignType.left;

    // -----------------------------------------------------
    // Sheet 1: Dashboard (Resumen Global)
    // -----------------------------------------------------
    final xlsio.Worksheet dashboardSheet = workbook.worksheets[0];
    dashboardSheet.name = 'Dashboard';

    int dashRow = 1;
    dashboardSheet
        .getRangeByName('A$dashRow')
        .setText('Resumen Financiero Global');
    dashboardSheet.getRangeByName('A$dashRow').cellStyle.bold = true;
    dashboardSheet.getRangeByName('A$dashRow').cellStyle.fontSize = 16;
    dashboardSheet.getRangeByName('A$dashRow').cellStyle.fontColor = '#4527A0';
    dashRow += 2;

    // Global Stats Consolidated in Main Currency
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var t in transactions) {
      if (!t.title.toLowerCase().contains('transfer')) {
        final amtMain = _convertCurrency(
          t.amount,
          t.currency,
          mainCurrency,
          exchangeRates,
          mainCurrency,
        );
        if (amtMain > 0) {
          totalIncome += amtMain;
        } else {
          totalExpense += amtMain.abs();
        }
      }
    }
    final totalBalance = totalIncome - totalExpense;

    dashboardSheet
        .getRangeByName('A$dashRow')
        .setText('Resumen Consolidado (en $mainCurrency)');
    dashboardSheet.getRangeByName('A$dashRow').cellStyle = subHeaderStyle;
    dashRow++;

    dashboardSheet
        .getRangeByName('A$dashRow')
        .setText('Total Ingresos ($mainCurrency)');
    dashboardSheet
        .getRangeByName('B$dashRow')
        .setText('Total Gastos ($mainCurrency)');
    dashboardSheet
        .getRangeByName('C$dashRow')
        .setText('Balance Neto ($mainCurrency)');
    dashboardSheet.getRangeByName('A$dashRow:C$dashRow').cellStyle =
        headerStyle;
    dashRow++;

    dashboardSheet.getRangeByName('A$dashRow').setNumber(totalIncome);
    dashboardSheet.getRangeByName('B$dashRow').setNumber(totalExpense);
    dashboardSheet.getRangeByName('C$dashRow').setNumber(totalBalance);
    dashRow += 3;
    dashboardSheet.autoFitColumn(1);
    dashboardSheet.autoFitColumn(2);
    dashboardSheet.autoFitColumn(3);

    // -----------------------------------------------------
    // Sheet 2: Cards List
    // -----------------------------------------------------
    final xlsio.Worksheet cardsSheet = workbook.worksheets.add();
    cardsSheet.name = 'Mis Tarjetas';

    final cardHeaders = [
      'Banco',
      'Tarjeta',
      'Moneda',
      'Balance Actual',
      'Vencimiento',
      'Estado',
    ];
    for (int i = 0; i < cardHeaders.length; i++) {
      cardsSheet.getRangeByIndex(1, i + 1).setText(cardHeaders[i]);
    }
    cardsSheet.getRangeByName('A1:F1').cellStyle = headerStyle;

    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final r = i + 2;
      cardsSheet.getRangeByIndex(r, 1).setText(card.bankName ?? 'N/A');
      cardsSheet.getRangeByIndex(r, 2).setText(card.name);
      cardsSheet.getRangeByIndex(r, 3).setText(card.currency);
      cardsSheet.getRangeByIndex(r, 4).setNumber(card.balance);
      cardsSheet.getRangeByIndex(r, 5).setText(card.expiryDate);
      cardsSheet
          .getRangeByIndex(r, 6)
          .setText(card.isLocked ? 'Bloqueada' : 'Activa');
    }
    cardsSheet.autoFitColumn(1);
    cardsSheet.autoFitColumn(2);
    cardsSheet.autoFitColumn(3);
    cardsSheet.autoFitColumn(4);
    cardsSheet.autoFitColumn(5);
    cardsSheet.autoFitColumn(6);

    // -----------------------------------------------------
    // Sheets 3...N: Per Card Details
    // -----------------------------------------------------
    for (var card in cards) {
      // Sheet names must be unique and limited length.
      // Use "Bank - Last4". Sanitize.
      String safeName =
          '${card.bankName ?? "Card"} ${card.cardNumber.length >= 4 ? card.cardNumber.substring(card.cardNumber.length - 4) : card.cardNumber}';
      safeName = safeName.replaceAll(
        RegExp(r'[\[\]\*\?\/\\\:]'),
        '',
      ); // Remove invalid chars
      if (safeName.length > 30) safeName = safeName.substring(0, 30);

      // Ensure unique name if multiple cards have same name (unlikely but possible)
      int suffix = 1;
      String originalName = safeName;
      while (workbook.worksheets.innerList.any((s) => s.name == safeName)) {
        safeName = '$originalName ($suffix)';
        suffix++;
      }

      final xlsio.Worksheet sheet = workbook.worksheets.add();
      sheet.name = safeName;

      // Card Header Info
      sheet.getRangeByName('A1').setText('Detalles de Tarjeta: ${card.name}');
      sheet.getRangeByName('A1').cellStyle.bold = true;
      sheet.getRangeByName('A1').cellStyle.fontSize = 14;

      sheet.getRangeByName('A2').setText('Banco: ${card.bankName ?? "N/A"}');
      sheet.getRangeByName('B2').setText('Número: ${card.cardNumber}');
      sheet.getRangeByName('C2').setText('Moneda: ${card.currency}');

      // Card specific transactions
      final cardTrans = transactions.where((t) => t.cardId == card.id).toList();

      // Card Statistics
      double cardIncome = 0.0;
      double cardExpense = 0.0;
      for (var t in cardTrans) {
        if (!t.title.toLowerCase().contains('transfer')) {
          final amtConverted = _convertCurrency(
            t.amount,
            t.currency,
            card.currency,
            exchangeRates,
            mainCurrency,
          );
          if (amtConverted > 0) {
            cardIncome += amtConverted;
          } else {
            cardExpense += amtConverted.abs();
          }
        }
      }

      sheet.getRangeByName('A4').setText('Ingresos Totales');
      sheet.getRangeByName('B4').setText('Gastos Totales');
      sheet.getRangeByName('A4:B4').cellStyle = headerStyle;

      sheet.getRangeByName('A5').setNumber(cardIncome);
      sheet.getRangeByName('B5').setNumber(cardExpense);

      // Card History Table
      int row = 8;
      final headers = [
        'Fecha',
        'Categoría',
        'Descripción',
        'Monto (${card.currency})',
        'Tipo',
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(row, i + 1).setText(headers[i]);
      }
      sheet.getRangeByIndex(row, 1, row, headers.length).cellStyle =
          headerStyle;
      row++;

      for (var trans in cardTrans) {
        final cat = categories.firstWhere(
          (c) => c.id == trans.categoryId,
          orElse: () =>
              Category(id: '', name: '---', iconCode: 0, colorValue: 0),
        );

        sheet.getRangeByIndex(row, 1).setText(_formatDate(trans.date));
        sheet.getRangeByIndex(row, 2).setText(cat.name);
        sheet.getRangeByIndex(row, 3).setText(trans.title);
        sheet.getRangeByIndex(row, 4).setNumber(trans.amount);
        sheet.getRangeByIndex(row, 5).setText(_getTransactionType(trans));
        row++;
      }
      sheet.autoFitColumn(1);
      sheet.autoFitColumn(2);
      sheet.autoFitColumn(3);
      sheet.autoFitColumn(4);
    }

    // -----------------------------------------------------
    // Last Sheet: Master Transaction List
    // -----------------------------------------------------
    final xlsio.Worksheet masterSheet = workbook.worksheets.add();
    masterSheet.name = 'Todas las Transacciones';

    final masterHeaders = [
      'Fecha',
      'Tarjeta',
      'Categoría',
      'Moneda',
      'Monto',
      'Tipo',
      'Descripción',
    ];
    for (int i = 0; i < masterHeaders.length; i++) {
      masterSheet.getRangeByIndex(1, i + 1).setText(masterHeaders[i]);
    }
    masterSheet.getRangeByName('A1:G1').cellStyle = headerStyle;

    int mRow = 2;
    for (var trans in transactions) {
      final cat = categories.firstWhere(
        (c) => c.id == trans.categoryId,
        orElse: () => Category(id: '', name: '---', iconCode: 0, colorValue: 0),
      );
      final card = cards.firstWhere(
        (c) => c.id == trans.cardId,
        orElse: () => AccountCard(
          id: '',
          name: '?',
          balance: 0,
          currency: '?',
          cardNumber: '?',
          expiryDate: '',
          colorValue: 0,
        ),
      );

      masterSheet.getRangeByIndex(mRow, 1).setText(_formatDate(trans.date));
      masterSheet
          .getRangeByIndex(mRow, 2)
          .setText('${card.bankName} ${card.cardNumber}');
      masterSheet.getRangeByIndex(mRow, 3).setText(cat.name);
      masterSheet.getRangeByIndex(mRow, 4).setText(trans.currency);
      masterSheet.getRangeByIndex(mRow, 5).setNumber(trans.amount);
      masterSheet.getRangeByIndex(mRow, 6).setText(_getTransactionType(trans));
      masterSheet.getRangeByIndex(mRow, 7).setText(trans.title);
      mRow++;
    }
    masterSheet.autoFitColumn(1);
    masterSheet.autoFitColumn(2);
    masterSheet.autoFitColumn(3);
    masterSheet.autoFitColumn(4);
    masterSheet.autoFitColumn(5);
    masterSheet.autoFitColumn(7);

    // -----------------------------------------------------
    // Business Module Sheet
    // -----------------------------------------------------
    if (businesses.isNotEmpty || sales.isNotEmpty) {
      final xlsio.Worksheet bizSheet = workbook.worksheets.add();
      bizSheet.name = 'Módulo de Negocio';

      bizSheet.getRangeByName('A1').setText('Reporte de Negocios');
      bizSheet.getRangeByName('A1:G1').cellStyle = headerStyle;
      bizSheet.getRangeByName('A1:G1').merge();

      int bRow = 3;
      bizSheet.getRangeByName('A$bRow').setText('Ventas Registradas');
      bizSheet.getRangeByName('A$bRow').cellStyle = subHeaderStyle;
      bRow++;

      final saleHeaders = [
        'Fecha',
        'Negocio',
        'Cliente',
        'Método',
        'Estado',
        'Descuento',
        'Total',
      ];
      for (int i = 0; i < saleHeaders.length; i++) {
        bizSheet.getRangeByIndex(bRow, i + 1).setText(saleHeaders[i]);
      }
      bizSheet.getRangeByIndex(bRow, 1, bRow, saleHeaders.length).cellStyle =
          headerStyle;
      bRow++;

      for (var saleRaw in sales) {
        if (saleRaw is Sale) {
          final biz = businesses.firstWhere(
            (b) => b.id == saleRaw.businessId,
            orElse: () => null,
          );

          bizSheet.getRangeByIndex(bRow, 1).setText(_formatDate(saleRaw.date));
          bizSheet.getRangeByIndex(bRow, 2).setText(biz?.name ?? 'Desconocido');
          bizSheet
              .getRangeByIndex(bRow, 3)
              .setText(saleRaw.clientName ?? 'Mostrador');
          bizSheet.getRangeByIndex(bRow, 4).setText(saleRaw.paymentMethod);
          bizSheet
              .getRangeByIndex(bRow, 5)
              .setText(saleRaw.status == 'pending' ? 'Fiado' : 'Pagado');
          bizSheet.getRangeByIndex(bRow, 6).setNumber(saleRaw.discount);
          bizSheet.getRangeByIndex(bRow, 7).setNumber(saleRaw.total);
          bRow++;
        }
      }

      bizSheet.autoFitColumn(1);
      bizSheet.autoFitColumn(2);
      bizSheet.autoFitColumn(3);
      bizSheet.autoFitColumn(7);
    }

    // Save
    final directory = await _getExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${directory.path}/CashRapido_Reporte_$timestamp.xlsx';

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future<String> exportToPDF({
    required List<InternalTransaction> transactions,
    required List<Category> categories,
    required List<AccountCard> cards,
    required Map<String, double> exchangeRates,
    required String mainCurrency,
    List<dynamic> businesses = const [],
    List<dynamic> products = const [],
    List<dynamic> sales = const [],
    List<dynamic> businessExpenses = const [],
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // --- Cover Page ---
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 100,
                width: 100,
                decoration: const pw.BoxDecoration(
                  color: _primaryColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(20)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'CR',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 40,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'CashRapido',
                style: pw.TextStyle(
                  fontSize: 40,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Reporte Financiero Personal',
                style: const pw.TextStyle(fontSize: 18, color: _greyColor),
              ),
              pw.SizedBox(height: 40),
              pw.Divider(color: _primaryColor, thickness: 2),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generado el ${_formatDate(now)}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total de Tarjetas: ${cards.length}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                'Total Transacciones: ${transactions.length}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          );
        },
      ),
    );

    // --- Global Summary Page ---
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageHeader('Resumen Ejecutivo'),
              pw.SizedBox(height: 20),

              pw.Builder(
                builder: (context) {
                  double totalIncome = 0.0;
                  double totalExpense = 0.0;
                  for (var t in transactions) {
                    if (!t.title.toLowerCase().contains('transfer')) {
                      final amtMain = _convertCurrency(
                        t.amount,
                        t.currency,
                        mainCurrency,
                        exchangeRates,
                        mainCurrency,
                      );
                      if (amtMain > 0) {
                        totalIncome += amtMain;
                      } else {
                        totalExpense += amtMain.abs();
                      }
                    }
                  }
                  final totalBalance = totalIncome - totalExpense;

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 15),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Resumen Consolidado ($mainCurrency)',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem(
                              'Ingresos',
                              totalIncome,
                              PdfColors.green,
                            ),
                            _buildStatItem(
                              'Gastos',
                              totalExpense,
                              PdfColors.red,
                            ),
                            _buildStatItem(
                              'Balance',
                              totalBalance,
                              totalBalance >= 0
                                  ? PdfColors.black
                                  : PdfColors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    // --- Per Card Details ---
    for (var card in cards) {
      final cardTrans = transactions.where((t) => t.cardId == card.id).toList();
      if (cardTrans.isEmpty && card.balance == 0) {
        continue;
      }

      // Break transactions into pages if needed (basic chunking)
      // For improved layout, we will just use a multi-page table capability if available or simple chunks
      const int itemsPerPage = 15;
      final chunks = <List<InternalTransaction>>[];
      if (cardTrans.isEmpty) {
        chunks.add([]);
      } else {
        for (int i = 0; i < cardTrans.length; i += itemsPerPage) {
          chunks.add(
            cardTrans.sublist(
              i,
              (i + itemsPerPage > cardTrans.length)
                  ? cardTrans.length
                  : i + itemsPerPage,
            ),
          );
        }
      }

      for (int i = 0; i < chunks.length; i++) {
        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (i == 0) ...[
                    // Visual Card Header (Only on first page of this card)
                    _buildVisualCard(card),
                    pw.SizedBox(height: 20),
                    _buildCardSummary(
                      card,
                      cardTrans,
                      exchangeRates,
                      mainCurrency,
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Historial de Transacciones',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],

                  if (chunks[i].isNotEmpty)
                    pw.TableHelper.fromTextArray(
                      headers: ['Fecha', 'Categoría', 'Descripción', 'Monto'],
                      data: chunks[i].map((t) {
                        final cat = categories.firstWhere(
                          (c) => c.id == t.categoryId,
                          orElse: () => Category(
                            id: '',
                            name: '-',
                            iconCode: 0,
                            colorValue: 0,
                          ),
                        );
                        return [
                          _formatDate(t.date),
                          cat.name,
                          t.title,
                          t.amount.toFormattedString(2),
                        ];
                      }).toList(),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      headerDecoration: const pw.BoxDecoration(
                        color: _primaryColor,
                      ),
                      rowDecoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.grey300),
                        ),
                      ),
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.centerLeft,
                        2: pw.Alignment.centerLeft,
                        3: pw.Alignment.centerRight,
                      },
                    ),

                  pw.Spacer(),
                  pw.Text(
                    'Página de tarjeta ${card.bankName} - Part ${i + 1}',
                    style: const pw.TextStyle(fontSize: 10, color: _greyColor),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    // --- Business Summary Page ---
    if (businesses.isNotEmpty || sales.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          build: (context) {
            double totalSales = 0.0;
            double pendingDebts = 0.0;

            for (var s in sales) {
              if (s is Sale) {
                if (s.status == 'pending') {
                  pendingDebts += s.total;
                } else {
                  totalSales += s.total;
                }
              }
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPageHeader('Módulo de Negocio'),
                pw.SizedBox(height: 20),

                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Resumen de Negocios',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'Negocios',
                            businesses.length.toDouble(),
                            PdfColors.black,
                          ),
                          _buildStatItem(
                            'Ventas Pagadas',
                            totalSales,
                            PdfColors.green,
                          ),
                          _buildStatItem(
                            'Cuentas por Cobrar',
                            pendingDebts,
                            PdfColors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Últimas Ventas',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                if (sales.isNotEmpty)
                  pw.TableHelper.fromTextArray(
                    headers: ['Fecha', 'Cliente', 'Estado', 'Total'],
                    data: sales.take(15).map((s) {
                      if (s is Sale) {
                        return [
                          _formatDate(s.date),
                          s.clientName ?? 'Mostrador',
                          s.status == 'pending' ? 'Fiado' : 'Pagado',
                          s.total.toFormattedString(2),
                        ];
                      }
                      return [];
                    }).toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: _primaryColor,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    // Save
    final directory = await _getExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${directory.path}/CashRapido_Reporte_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  // --- PDF Helpers ---

  pw.Widget _buildPageHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.Divider(color: _primaryColor, thickness: 2),
      ],
    );
  }

  pw.Widget _buildStatItem(String label, double amount, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: _greyColor),
        ),
        pw.Text(
          _formatCurrency(amount),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildVisualCard(AccountCard card) {
    // Attempt to parse color
    final color = PdfColor.fromInt(card.colorValue);

    return pw.Container(
      height: 120,
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                card.bankName ?? 'Bank',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                card.currency,
                style: pw.TextStyle(color: PdfColors.white, fontSize: 18),
              ),
            ],
          ),
          pw.Text(
            '**** **** **** ${card.cardNumber.length >= 4 ? card.cardNumber.substring(card.cardNumber.length - 4) : card.cardNumber}',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              letterSpacing: 2,
            ),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                card.name,
                style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
              ),
              pw.Text(
                'Exp: ${card.expiryDate}',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCardSummary(
    AccountCard card,
    List<InternalTransaction> cardTrans,
    Map<String, double> exchangeRates,
    String mainCurrency,
  ) {
    double income = 0.0;
    double expense = 0.0;
    for (var t in cardTrans) {
      if (!t.title.toLowerCase().contains('transfer')) {
        final amt = _convertCurrency(
          t.amount,
          t.currency,
          card.currency,
          exchangeRates,
          mainCurrency,
        );
        if (amt > 0) {
          income += amt;
        } else {
          expense += amt.abs();
        }
      }
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Balance Actual', card.balance, _primaryColor),
        _buildStatItem('Ingresos (Histórico)', income, PdfColors.green),
        _buildStatItem('Gastos (Histórico)', expense, PdfColors.red),
      ],
    );
  }

  // --- Directory Helper ---
  Future<Directory> _getExportDirectory() async {
    // Try to get external storage (Documents) on Android if possible, else DocumentDirectory
    if (Platform.isAndroid) {
      // Direct path approach for standard folders often requires management policies or scoped storage APIs.
      // However, modern Android usually allows writing to AppExternalStorage and then sharing.
      // We will try to find a public directory if the plugin supports it, else standard.
      // getExternalStorageDirectory() gives Android/data/package... which is somewhat hidden but accessible.
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return extDir;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> shareFile(String filePath) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
  }

  Future<String> exportLoansToCSV(List<Loan> loans) async {
    final StringBuffer csvBuffer = StringBuffer();
    // Headers
    csvBuffer.writeln(
      "ID,Deudor,Monto,Interes(%),Tipo Interes,Frecuencia,Cuotas,Inicio,Vencimiento,Restante,Estado,Moneda,Notas",
    );

    for (var l in loans) {
      final id = l.id;
      final debtor = l.borrowerName.replaceAll('"', '""');
      final amount = l.amount.toStringAsFixed(2);
      final rate = l.interestRate.toStringAsFixed(2);
      final type = l.interestType;
      final freq = l.frequency;
      final term = l.durationValue;
      final start =
          "${l.startDate.day}/${l.startDate.month}/${l.startDate.year}";
      final due = "${l.dueDate.day}/${l.dueDate.month}/${l.dueDate.year}";
      final remaining = l.remainingAmount.toStringAsFixed(2);
      final status = l.status;
      final currency = l.currency;
      final notes = (l.notes ?? '').replaceAll('"', '""').replaceAll('\n', ' ');

      csvBuffer.writeln(
        '"$id","$debtor",$amount,$rate,"$type","$freq",$term,"$start","$due",$remaining,"$status","$currency","$notes"',
      );
    }

    final directory = await _getExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${directory.path}/CashRapido_Prestamos_$timestamp.csv';

    final file = File(filePath);
    await file.writeAsString(csvBuffer.toString());
    return filePath;
  }

  Future<String> exportLoansToExcel(List<Loan> loans) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Prestamos';

    final xlsio.Style headerStyle = workbook.styles.add('HeaderStyleLoan');
    headerStyle.fontName = 'Calibri';
    headerStyle.bold = true;
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.backColor = '#00796B'; // Teal
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    final headers = [
      'Deudor',
      'Capital',
      'Interes (%)',
      'Tipo Interes',
      'Frecuencia',
      'Cuotas',
      'Fecha Inicio',
      'Fecha Vencimiento',
      'Saldo Restante',
      'Estado',
      'Moneda',
      'Notas',
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }
    sheet.getRangeByIndex(1, 1, 1, headers.length).cellStyle = headerStyle;

    for (int i = 0; i < loans.length; i++) {
      final l = loans[i];
      final r = i + 2;
      sheet.getRangeByIndex(r, 1).setText(l.borrowerName);
      sheet.getRangeByIndex(r, 2).setNumber(l.amount);
      sheet.getRangeByIndex(r, 3).setNumber(l.interestRate);
      sheet.getRangeByIndex(r, 4).setText(l.interestType);
      sheet.getRangeByIndex(r, 5).setText(l.frequency);
      sheet.getRangeByIndex(r, 6).setNumber(l.durationValue.toDouble());
      sheet
          .getRangeByIndex(r, 7)
          .setText(
            "${l.startDate.day}/${l.startDate.month}/${l.startDate.year}",
          );
      sheet
          .getRangeByIndex(r, 8)
          .setText("${l.dueDate.day}/${l.dueDate.month}/${l.dueDate.year}");
      sheet.getRangeByIndex(r, 9).setNumber(l.remainingAmount);
      sheet.getRangeByIndex(r, 10).setText(l.status);
      sheet.getRangeByIndex(r, 11).setText(l.currency);
      sheet.getRangeByIndex(r, 12).setText(l.notes ?? '');
    }

    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    final directory = await _getExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${directory.path}/CashRapido_Prestamos_$timestamp.xlsx';

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  // ====================================================
  // BUSINESS CLOSING EXPORTS
  // ====================================================

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensual';
      case 'yearly':
        return 'Anual';
      default:
        return period;
    }
  }

  String _shortDate(DateTime date) => DateFormat('dd/MM/yyyy HH:mm').format(date);
  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);

  List<Map<String, dynamic>> _parseSellerStats(String jsonData) {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      return data.entries.map((e) {
        final stats = e.value as Map<String, dynamic>;
        return {
          'name': e.key,
          'count': (stats['count'] as num?)?.toInt() ?? 0,
          'total': (stats['total'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  pw.Widget _buildKpiBox(
    String label,
    double value,
    PdfColor color, {
    bool isSuffix = false,
    bool isInt = false,
    String? labelOnly,
  }) {
    final displayValue =
        labelOnly ??
        (isInt
            ? value.toInt().toString()
            : isSuffix
            ? '${value.toStringAsFixed(1)}%'
            : _formatCurrency(value));
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            displayValue,
            style: pw.TextStyle(
              fontSize: labelOnly != null ? 9 : 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBarChart(double income, double expenses) {
    final maxVal = income > expenses ? income : expenses;
    if (maxVal == 0) {
      return pw.Text(
        'Sin datos para graficar.',
        style: const pw.TextStyle(color: _greyColor),
      );
    }
    final incomeRatio = income / maxVal;
    final expenseRatio = expenses / maxVal;
    final profitRatio = (income - expenses).abs() / maxVal;
    const barH = 24.0;
    const maxW = 340.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _barRow(
            'Ingresos',
            incomeRatio,
            maxW,
            barH,
            PdfColors.green600,
            _formatCurrency(income),
          ),
          pw.SizedBox(height: 6),
          _barRow(
            'Gastos',
            expenseRatio,
            maxW,
            barH,
            PdfColors.red600,
            _formatCurrency(expenses),
          ),
          pw.SizedBox(height: 6),
          _barRow(
            'Utilidad',
            profitRatio,
            maxW,
            barH,
            income >= expenses ? PdfColors.blue600 : PdfColors.red800,
            _formatCurrency(income - expenses),
          ),
        ],
      ),
    );
  }

  pw.Widget _barRow(
    String label,
    double ratio,
    double maxW,
    double h,
    PdfColor color,
    String valueText,
  ) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 60,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Container(
          height: h,
          width: (maxW * ratio).clamp(4.0, maxW),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          valueText,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildColorTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    const colors = [
      PdfColors.purple50,
      PdfColors.indigo50,
      PdfColors.blue50,
      PdfColors.teal50,
      PdfColors.green50,
      PdfColors.lime50,
      PdfColors.yellow50,
      PdfColors.orange50,
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _primaryColor),
      cellDecoration: (index, data, rowNum) =>
          pw.BoxDecoration(color: colors[rowNum % colors.length]),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  pw.Widget _buildSellerStatsSection(Closing closing, String mainCurrency) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(closing.sellerStatsJson) as Map<String, dynamic>;
    } catch (_) {}
    if (data.isEmpty) return pw.SizedBox.shrink();

    final rows = data.entries.map((e) {
      final stats = e.value as Map<String, dynamic>;
      final total = (stats['total'] as num?)?.toDouble() ?? 0.0;
      final count = (stats['count'] as num?)?.toInt() ?? 0;
      return [e.key, '$count', _formatCurrency(total)];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 14),
        pw.Text(
          'Ventas por Vendedor',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo700,
          ),
        ),
        pw.SizedBox(height: 6),
        _buildColorTable(
          headers: ['Vendedor', 'Ventas (#)', 'Total ($mainCurrency)'],
          rows: rows,
        ),
      ],
    );
  }

  /// Exports a single Closing to a beautiful PDF with charts
  Future<String> exportBusinessClosingToPDF({
    required Closing closing,
    required String businessName,
    required String mainCurrency,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final soldList = (jsonDecode(closing.soldProductsJson) as List)
        .cast<Map<String, dynamic>>();
    final addedList = (jsonDecode(closing.addedProductsJson) as List)
        .cast<Map<String, dynamic>>();
    final paymentMethods = (jsonDecode(closing.paymentMethodsJson) as Map)
        .cast<String, dynamic>();
    final expenseCategories = (jsonDecode(closing.expenseCategoriesJson) as Map)
        .cast<String, dynamic>();

    final periodLabel = _getPeriodLabel(closing.period);

    // ---- Cover Page ----
    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              height: 90,
              width: 90,
              decoration: const pw.BoxDecoration(
                color: _primaryColor,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(18)),
              ),
              child: pw.Center(
                child: pw.Text(
                  'CR',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 38,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'CashRapido',
              style: pw.TextStyle(
                fontSize: 34,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Reporte de Cierre $periodLabel',
              style: const pw.TextStyle(fontSize: 16, color: _greyColor),
            ),
            pw.SizedBox(height: 32),
            pw.Divider(color: _primaryColor, thickness: 2),
            pw.SizedBox(height: 16),
            pw.Text(
              'Negocio: $businessName',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Período: ${_shortDate(closing.startDate)} → ${_shortDate(closing.endDate)}',
              style: const pw.TextStyle(fontSize: 13),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Generado el ${_formatDate(now)}',
              style: const pw.TextStyle(fontSize: 11, color: _greyColor),
            ),
          ],
        ),
      ),
    );

    // ---- Financial Summary Page ----
    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('Resumen Financiero del Cierre'),
            pw.SizedBox(height: 16),
            // KPI Row 1
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildKpiBox(
                    'Ingresos ($mainCurrency)',
                    closing.income,
                    PdfColors.green700,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    'Gastos ($mainCurrency)',
                    closing.expenses,
                    PdfColors.red700,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    'Utilidad ($mainCurrency)',
                    closing.profit,
                    closing.profit >= 0 ? PdfColors.blue800 : PdfColors.red700,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    'ROI',
                    closing.roi,
                    PdfColors.purple700,
                    isSuffix: true,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            // KPI Row 2
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildKpiBox(
                    'N° Ventas',
                    closing.salesCount.toDouble(),
                    PdfColors.teal700,
                    isInt: true,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    'N° Gastos',
                    closing.expensesCount.toDouble(),
                    PdfColors.orange700,
                    isInt: true,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    'Descuentos ($mainCurrency)',
                    closing.totalDiscounts,
                    PdfColors.brown700,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    'Más Vendido',
                    0,
                    PdfColors.indigo700,
                    labelOnly: closing.bestSellerName.isNotEmpty
                        ? '${closing.bestSellerName}\n×${closing.bestSellerQty}'
                        : 'N/A',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            // Bar Chart
            pw.Text(
              'Ingresos vs Gastos vs Utilidad',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildBarChart(closing.income, closing.expenses),
            pw.SizedBox(height: 20),
            // Payment methods
            if (paymentMethods.isNotEmpty) ...[
              pw.Text(
                'Métodos de Pago',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.SizedBox(height: 6),
              _buildColorTable(
                headers: ['Método', 'Total ($mainCurrency)', '% del Ingreso'],
                rows: paymentMethods.entries.map((e) {
                  final val = (e.value as num).toDouble();
                  final pct = closing.income > 0
                      ? val / closing.income * 100
                      : 0.0;
                  return [
                    e.key,
                    _formatCurrency(val),
                    '${pct.toStringAsFixed(1)}%',
                  ];
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );

    // ---- Products & Expenses Detail Page ----
    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildPageHeader('Detalle de Productos y Gastos'),
            pw.SizedBox(height: 12),
            if (soldList.isNotEmpty) ...[
              pw.Text(
                'Productos Vendidos',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
              pw.SizedBox(height: 6),
              _buildColorTable(
                headers: ['Producto', 'Cantidad', 'Ingresos ($mainCurrency)'],
                rows: soldList
                    .take(20)
                    .map(
                      (item) => [
                        item['name']?.toString() ?? '',
                        _formatQty((item['qty'] as num?)?.toDouble() ?? 0),
                        _formatCurrency(
                          (item['revenue'] as num?)?.toDouble() ?? 0,
                        ),
                      ],
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 14),
            ],
            if (addedList.isNotEmpty) ...[
              pw.Text(
                'Nuevos Productos Añadidos',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 6),
              _buildColorTable(
                headers: ['Producto', 'Cant. Comprada', 'Costo/Unidad'],
                rows: addedList
                    .map(
                      (item) => [
                        item['name']?.toString() ?? '',
                        _formatQty((item['qty'] as num?)?.toDouble() ?? 0),
                        _formatCurrency(
                          (item['cost'] as num?)?.toDouble() ?? 0,
                        ),
                      ],
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 14),
            ],
            if (expenseCategories.isNotEmpty) ...[
              pw.Text(
                'Gastos por Categoría',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700,
                ),
              ),
              pw.SizedBox(height: 6),
              _buildColorTable(
                headers: ['Categoría', 'Total ($mainCurrency)', '% del Gasto'],
                rows: expenseCategories.entries.map((e) {
                  final val = (e.value as num).toDouble();
                  final pct = closing.expenses > 0
                      ? val / closing.expenses * 100
                      : 0.0;
                  return [
                    e.key,
                    _formatCurrency(val),
                    '${pct.toStringAsFixed(1)}%',
                  ];
                }).toList(),
              ),
            ],
            // Seller stats
            _buildSellerStatsSection(closing, mainCurrency),
          ],
        ),
      ),
    );

    final directory = await _getExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(now);
    final safe = businessName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final filePath = '${directory.path}/Cierre_${safe}_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  /// Exports a single Closing to a multi-sheet Excel workbook
  Future<String> exportBusinessClosingToExcel({
    required Closing closing,
    required String businessName,
    required String mainCurrency,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final now = DateTime.now();

    final soldList = (jsonDecode(closing.soldProductsJson) as List)
        .cast<Map<String, dynamic>>();
    final addedList = (jsonDecode(closing.addedProductsJson) as List)
        .cast<Map<String, dynamic>>();
    final paymentMethods = (jsonDecode(closing.paymentMethodsJson) as Map)
        .cast<String, dynamic>();
    final expenseCategories = (jsonDecode(closing.expenseCategoriesJson) as Map)
        .cast<String, dynamic>();

    // Styles
    final xlsio.Style hStyle = workbook.styles.add('ClH');
    hStyle.fontName = 'Calibri';
    hStyle.bold = true;
    hStyle.fontColor = '#FFFFFF';
    hStyle.backColor = '#4527A0';
    hStyle.hAlign = xlsio.HAlignType.center;

    final xlsio.Style greenH = workbook.styles.add('ClGH');
    greenH.fontName = 'Calibri';
    greenH.bold = true;
    greenH.fontColor = '#FFFFFF';
    greenH.backColor = '#2E7D32';
    greenH.hAlign = xlsio.HAlignType.center;

    final xlsio.Style redH = workbook.styles.add('ClRH');
    redH.fontName = 'Calibri';
    redH.bold = true;
    redH.fontColor = '#FFFFFF';
    redH.backColor = '#C62828';
    redH.hAlign = xlsio.HAlignType.center;

    // ---- Sheet 1: Resumen ----
    final xlsio.Worksheet summary = workbook.worksheets[0];
    summary.name = 'Resumen';

    summary
        .getRangeByName('A1')
        .setText(
          'CIERRE ${_getPeriodLabel(closing.period).toUpperCase()} - $businessName',
        );
    summary.getRangeByName('A1').cellStyle.bold = true;
    summary.getRangeByName('A1').cellStyle.fontSize = 14;
    summary.getRangeByName('A1').cellStyle.fontColor = '#4527A0';
    summary.getRangeByName('A1:D1').merge();

    summary
        .getRangeByName('A2')
        .setText(
          'Período: ${_shortDate(closing.startDate)} → ${_shortDate(closing.endDate)}',
        );
    summary.getRangeByName('A3').setText('Generado: ${_formatDate(now)}');

    int sRow = 5;
    summary.getRangeByIndex(sRow, 1).setText('Indicador');
    summary.getRangeByIndex(sRow, 2).setText('Valor');
    summary.getRangeByIndex(sRow, 1, sRow, 2).cellStyle = hStyle;
    sRow++;

    void addKpi(String label, dynamic value) {
      summary.getRangeByIndex(sRow, 1).setText(label);
      if (value is double) {
        summary.getRangeByIndex(sRow, 2).setNumber(value);
      } else {
        summary.getRangeByIndex(sRow, 2).setText(value.toString());
      }
      sRow++;
    }

    addKpi('Ingresos ($mainCurrency)', closing.income);
    addKpi('Gastos ($mainCurrency)', closing.expenses);
    addKpi('Utilidad Neta ($mainCurrency)', closing.profit);
    addKpi('ROI (%)', closing.roi);
    addKpi('Número de Ventas', closing.salesCount.toDouble());
    addKpi('Gastos Registrados', closing.expensesCount.toDouble());
    addKpi('Descuentos ($mainCurrency)', closing.totalDiscounts);
    addKpi('Mejor Vendedor', closing.bestSellerName);
    addKpi('Cant. Mejor Vendedor', closing.bestSellerQty.toDouble());

    summary.autoFitColumn(1);
    summary.autoFitColumn(2);

    // ---- Sheet 2: Productos Vendidos ----
    if (soldList.isNotEmpty) {
      final xlsio.Worksheet sh = workbook.worksheets.add();
      sh.name = 'Prod. Vendidos';
      final hdrs = ['Producto', 'Cantidad', 'Ingresos ($mainCurrency)'];
      for (int i = 0; i < hdrs.length; i++)
        sh.getRangeByIndex(1, i + 1).setText(hdrs[i]);
      sh.getRangeByIndex(1, 1, 1, hdrs.length).cellStyle = hStyle;
      for (int i = 0; i < soldList.length; i++) {
        final item = soldList[i];
        final r = i + 2;
        sh.getRangeByIndex(r, 1).setText(item['name']?.toString() ?? '');
        sh
            .getRangeByIndex(r, 2)
            .setNumber((item['qty'] as num?)?.toDouble() ?? 0);
        sh
            .getRangeByIndex(r, 3)
            .setNumber((item['revenue'] as num?)?.toDouble() ?? 0);
      }
      for (int i = 1; i <= hdrs.length; i++) sh.autoFitColumn(i);
    }

    // ---- Sheet 3: Nuevos Productos ----
    if (addedList.isNotEmpty) {
      final xlsio.Worksheet sh = workbook.worksheets.add();
      sh.name = 'Nuevos Productos';
      final hdrs = ['Producto', 'Cantidad Comprada', 'Costo/Unidad'];
      for (int i = 0; i < hdrs.length; i++)
        sh.getRangeByIndex(1, i + 1).setText(hdrs[i]);
      sh.getRangeByIndex(1, 1, 1, hdrs.length).cellStyle = greenH;
      for (int i = 0; i < addedList.length; i++) {
        final item = addedList[i];
        final r = i + 2;
        sh.getRangeByIndex(r, 1).setText(item['name']?.toString() ?? '');
        sh
            .getRangeByIndex(r, 2)
            .setNumber((item['qty'] as num?)?.toDouble() ?? 0);
        sh
            .getRangeByIndex(r, 3)
            .setNumber((item['cost'] as num?)?.toDouble() ?? 0);
      }
      for (int i = 1; i <= hdrs.length; i++) sh.autoFitColumn(i);
    }

    // ---- Sheet 4: Métodos de Pago ----
    if (paymentMethods.isNotEmpty) {
      final xlsio.Worksheet sh = workbook.worksheets.add();
      sh.name = 'Métodos de Pago';
      final hdrs = ['Método', 'Total ($mainCurrency)', '% del Ingreso'];
      for (int i = 0; i < hdrs.length; i++)
        sh.getRangeByIndex(1, i + 1).setText(hdrs[i]);
      sh.getRangeByIndex(1, 1, 1, hdrs.length).cellStyle = hStyle;
      int pmRow = 2;
      for (final e in paymentMethods.entries) {
        final val = (e.value as num).toDouble();
        final pct = closing.income > 0 ? val / closing.income * 100 : 0.0;
        sh.getRangeByIndex(pmRow, 1).setText(e.key);
        sh.getRangeByIndex(pmRow, 2).setNumber(val);
        sh.getRangeByIndex(pmRow, 3).setNumber(pct);
        pmRow++;
      }
      for (int i = 1; i <= hdrs.length; i++) sh.autoFitColumn(i);
    }

    // ---- Sheet 5: Gastos por Categoría ----
    if (expenseCategories.isNotEmpty) {
      final xlsio.Worksheet sh = workbook.worksheets.add();
      sh.name = 'Gastos Categoría';
      final hdrs = ['Categoría', 'Total ($mainCurrency)', '% del Gasto'];
      for (int i = 0; i < hdrs.length; i++)
        sh.getRangeByIndex(1, i + 1).setText(hdrs[i]);
      sh.getRangeByIndex(1, 1, 1, hdrs.length).cellStyle = redH;
      int ecRow = 2;
      for (final e in expenseCategories.entries) {
        final val = (e.value as num).toDouble();
        final pct = closing.expenses > 0 ? val / closing.expenses * 100 : 0.0;
        sh.getRangeByIndex(ecRow, 1).setText(e.key);
        sh.getRangeByIndex(ecRow, 2).setNumber(val);
        sh.getRangeByIndex(ecRow, 3).setNumber(pct);
        ecRow++;
      }
      for (int i = 1; i <= hdrs.length; i++) sh.autoFitColumn(i);
    }

    // ---- Sheet 6: Ventas por Vendedor ----
    final sellerData = _parseSellerStats(closing.sellerStatsJson);
    if (sellerData.isNotEmpty) {
      final xlsio.Worksheet sh = workbook.worksheets.add();
      sh.name = 'Ventas Vendedor';
      final hdrs = ['Vendedor', 'Ventas (#)', 'Total ($mainCurrency)'];
      for (int i = 0; i < hdrs.length; i++)
        sh.getRangeByIndex(1, i + 1).setText(hdrs[i]);
      sh.getRangeByIndex(1, 1, 1, hdrs.length).cellStyle = hStyle;
      int sRow = 2;
      for (final row in sellerData) {
        sh.getRangeByIndex(sRow, 1).setText(row['name'] as String);
        sh.getRangeByIndex(sRow, 2).setNumber((row['count'] as int).toDouble());
        sh.getRangeByIndex(sRow, 3).setNumber(row['total'] as double);
        sRow++;
      }
      for (int i = 1; i <= hdrs.length; i++) sh.autoFitColumn(i);
    }

    final directory = await _getExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(now);
    final safe = businessName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final filePath = '${directory.path}/Cierre_${safe}_$timestamp.xlsx';

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }
}
