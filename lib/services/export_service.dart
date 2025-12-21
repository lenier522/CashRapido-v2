import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class ExportService {
  // --- Formatters ---
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _getTransactionType(InternalTransaction trans) {
    if (trans.title.toLowerCase().contains('transfer')) return 'Transferencia';
    return trans.amount > 0 ? 'Ingreso' : 'Gasto';
  }

  // --- Constants ---
  static const _primaryColor = PdfColors.deepPurple;

  static const _greyColor = PdfColors.grey600;

  // --- Main Methods ---

  Future<String> exportToExcel({
    required List<InternalTransaction> transactions,
    required List<Category> categories,
    required List<AccountCard> cards,
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

    // Global Stats by Currency
    final currencies = cards.map((c) => c.currency).toSet().toList();
    if (currencies.isEmpty) currencies.add('USD');

    for (var currency in currencies) {
      final currencyTrans = transactions.where((t) => t.currency == currency);
      final income = currencyTrans
          .where(
            (t) => t.amount > 0 && !t.title.toLowerCase().contains('transfer'),
          )
          .fold(0.0, (s, t) => s + t.amount);
      final expense = currencyTrans
          .where((t) => t.amount < 0)
          .fold(0.0, (s, t) => s + t.amount.abs());
      final balance = income - expense;

      dashboardSheet.getRangeByName('A$dashRow').setText('Moneda: $currency');
      dashboardSheet.getRangeByName('A$dashRow').cellStyle = subHeaderStyle;
      dashRow++;

      // Header row
      dashboardSheet.getRangeByName('A$dashRow').setText('Total Ingresos');
      dashboardSheet.getRangeByName('B$dashRow').setText('Total Gastos');
      dashboardSheet.getRangeByName('C$dashRow').setText('Balance Neto');
      dashboardSheet.getRangeByName('A$dashRow:C$dashRow').cellStyle =
          headerStyle;
      dashRow++;

      // Value row
      dashboardSheet.getRangeByName('A$dashRow').setNumber(income);
      dashboardSheet.getRangeByName('B$dashRow').setNumber(expense);
      dashboardSheet.getRangeByName('C$dashRow').setNumber(balance);
      dashRow += 3;
    }
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
      double cardIncome = cardTrans
          .where(
            (t) => t.amount > 0 && !t.title.toLowerCase().contains('transfer'),
          )
          .fold(0.0, (s, t) => s + t.amount);
      double cardExpense = cardTrans
          .where((t) => t.amount < 0)
          .fold(0.0, (s, t) => s + t.amount.abs());

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

              ...cards.map((c) => c.currency).toSet().map((currency) {
                final currencyTrans = transactions.where(
                  (t) => t.currency == currency,
                );
                final income = currencyTrans
                    .where(
                      (t) =>
                          t.amount > 0 &&
                          !t.title.toLowerCase().contains('transfer'),
                    )
                    .fold(0.0, (s, t) => s + t.amount);
                final expense = currencyTrans
                    .where((t) => t.amount < 0)
                    .fold(0.0, (s, t) => s + t.amount.abs());
                final balance = income - expense;

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
                        'Moneda: $currency',
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
                          _buildStatItem('Ingresos', income, PdfColors.green),
                          _buildStatItem('Gastos', expense, PdfColors.red),
                          _buildStatItem(
                            'Balance',
                            balance,
                            balance >= 0 ? PdfColors.black : PdfColors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
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
                    _buildCardSummary(card, cardTrans),
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
                          t.amount.toStringAsFixed(2),
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
  ) {
    final income = cardTrans
        .where((t) => t.amount > 0)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = cardTrans
        .where((t) => t.amount < 0)
        .fold(0.0, (s, t) => s + t.amount.abs());

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
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(filePath)]);
  }
}
