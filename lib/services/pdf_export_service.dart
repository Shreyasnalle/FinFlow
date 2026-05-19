import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';

class PdfExportService {
  static String _safeCurrencyFormat(FinanceProvider provider, double amount) {
    String formatted = provider.currencyFormat.format(amount);
    return formatted
      .replaceAll('₹', 'Rs. ')
      .replaceAll('€', 'EUR ')
      .replaceAll('£', 'GBP ')
      .replaceAll('¥', 'JPY ');
  }

  static Future<void> exportFinanceReport(FinanceProvider provider) async {
    final pdf = pw.Document();

    final transactions = provider.transactions.take(100).toList();
    double totalCredits = 0;
    double totalDebits = 0;
    
    for (var t in transactions) {
      if (t.isIncome) {
        totalCredits += t.amount;
      } else {
        totalDebits += t.amount;
      }
    }

    double openingBalance = provider.currentBalance - totalCredits + totalDebits;

    DateTime? startDate;
    DateTime? endDate;
    if (transactions.isNotEmpty) {
      // Transactions are stored newest first
      endDate = transactions.first.date;
      startDate = transactions.last.date;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            // Bank Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FINFLOW', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                    pw.SizedBox(height: 4),
                   
                    pw.Text('patilharshavardhan554@gmail.com', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.teal800, width: 1.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('STATEMENT OF ACCOUNT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                      pw.SizedBox(height: 8),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                )
              ],
            ),
            
            // Customer Info Box
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 24),
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Account Holder:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(provider.userName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Phone: ${provider.userMobile}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Statement Period:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        startDate != null 
                            ? '${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate!)}' 
                            : 'N/A', 
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Account Summary Box
            pw.Text('ACCOUNT SUMMARY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.teal, width: 2),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _summaryBox('Opening Balance', _safeCurrencyFormat(provider, openingBalance)),
                  _summaryBox('Total Credits', _safeCurrencyFormat(provider, totalCredits), color: PdfColors.green700),
                  _summaryBox('Total Debits', _safeCurrencyFormat(provider, totalDebits), color: PdfColors.red700),
                  _summaryBox('Closing Balance', _safeCurrencyFormat(provider, provider.currentBalance), isBold: true),
                ],
              ),
            ),

            pw.SizedBox(height: 32),
            pw.Text('TRANSACTION DETAILS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
            pw.SizedBox(height: 8),

            if (transactions.isEmpty)
              pw.Text('No transactions found for this period.', style: const pw.TextStyle(color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.teal800, width: 1.5),
                ),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                },
                data: <List<String>>[
                  <String>['Date', 'Particulars / Ref', 'Category', 'Amount'],
                  ...transactions.map((t) => [
                    DateFormat('dd MMM yyyy').format(t.date),
                    t.note,
                    t.category,
                    '${t.isIncome ? '+' : '-'}${_safeCurrencyFormat(provider, t.amount)}',
                  ])
                ],
              ),
              
            pw.SizedBox(height: 40),
            pw.Center(
               child: pw.Text('*** END OF STATEMENT ***', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'FinFlow_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _summaryBox(String title, String value, {PdfColor? color, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: pw.Column(
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 6),
          pw.Text(
            value, 
            style: pw.TextStyle(
              fontSize: 14, 
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
