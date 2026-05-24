import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import '../models/transaction_model.dart';
import '../models/party_model.dart';
import '../utils/time_utils.dart';

class PdfService {
  static Future<Uint8List> generateReceiptPdf({
    required TransactionModel transaction,
    required String amountStr,
    required String badgeText,
  }) async {
    final pdf = pw.Document();
    
    final logoData = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    
    final fontRegular = await PdfGoogleFonts.montserratRegular();
    final fontBold = await PdfGoogleFonts.montserratBold();
    
    final brandTeal = PdfColor.fromHex('#01565B');
    final brandGold = PdfColor.fromHex('#735C0F');
    final lightBeige = PdfColor.fromHex('#FAF6EE');
    
    final dateStr = DateFormat('dd MMM yyyy').format(transaction.date);
    final timeStr = DateFormat('hh:mm a').format(transaction.date);
    final receiptNo = 'SK-${transaction.date.millisecondsSinceEpoch.toString().substring(7)}';
    final isCredit = transaction.type == TransactionType.receipt || transaction.type == TransactionType.metalIn;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Centered Branding Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Image(logoImage, width: 50, height: 50),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'SWASTIK JEWELS',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 24,
                        color: brandGold,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Luxury Jewellery & Bullion Merchant',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: brandTeal,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'TRANSACTION RECEIPT',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // Metadata Grid
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildMetaField(fontRegular, fontBold, 'Receipt No:', receiptNo),
                      _buildMetaField(fontRegular, fontBold, 'Date:', '$dateStr  $timeStr'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildMetaField(fontRegular, fontBold, 'Customer Name:', transaction.partyName, isRightAligned: true),
                      if (transaction.partyPhone.isNotEmpty)
                        _buildMetaField(fontRegular, fontBold, 'Phone Number:', transaction.partyPhone, isRightAligned: true),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 32),

              // Transaction Details Table-like block
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    // Table Header
                    pw.Container(
                      color: lightBeige,
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text('Description', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandTeal)),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('Category / Type', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandTeal)),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('Transaction Type', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandTeal)),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text('Total Amount', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandTeal)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Divider(height: 1, thickness: 1, color: PdfColors.grey300),
                    // Table Row
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              badgeText.isNotEmpty ? badgeText : 'Jewellery Transaction',
                              style: pw.TextStyle(font: fontRegular, fontSize: 11),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              transaction.metalType.isEmpty ? 'Money' : transaction.metalType.toUpperCase(),
                              style: pw.TextStyle(font: fontRegular, fontSize: 11),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              isCredit ? 'CREDIT / IN' : 'DEBIT / OUT',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                color: isCredit ? PdfColors.green800 : PdfColors.red800,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                amountStr,
                                style: pw.TextStyle(font: fontBold, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              if (transaction.notes.isNotEmpty) ...[
                pw.Text('Notes:', style: pw.TextStyle(font: fontBold, fontSize: 11, color: brandTeal)),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: lightBeige,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey200),
                  ),
                  child: pw.Text(
                    transaction.notes,
                    style: pw.TextStyle(font: fontRegular, fontSize: 10, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.SizedBox(height: 32),
              ],

              pw.Spacer(),

              // Footer Block
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(font: fontBold, fontSize: 12, color: brandTeal),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'This is a computer generated receipt and does not require a physical signature.',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateStatementPdf({
    required List<TransactionModel> transactions,
    required String title,
    required String subtitle,
    String? totalBalance,
  }) async {
    final pdf = pw.Document();
    
    final logoData = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    
    final fontRegular = await PdfGoogleFonts.montserratRegular();
    final fontBold = await PdfGoogleFonts.montserratBold();
    
    final brandTeal = PdfColor.fromHex('#01565B');
    final brandGold = PdfColor.fromHex('#735C0F');
    final lightBeige = PdfColor.fromHex('#FAF6EE');

    const itemsPerPage = 15;
    final pagesCount = transactions.isEmpty ? 1 : (transactions.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < pagesCount; pageIndex++) {
      final startIdx = pageIndex * itemsPerPage;
      final endIdx = (startIdx + itemsPerPage < transactions.length) 
          ? startIdx + itemsPerPage 
          : transactions.length;
      final pageTxns = transactions.isEmpty ? <TransactionModel>[] : transactions.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (pageIndex == 0) ...[
                  // Header
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.Image(logoImage, width: 45, height: 45),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'SWASTIK JEWELS',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 22,
                                color: brandGold,
                                letterSpacing: 2,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              title.toUpperCase(),
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            subtitle,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: brandTeal,
                            ),
                          ),
                          if (totalBalance != null)
                            pw.Text(
                              'Outstanding: $totalBalance',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: PdfColors.red800,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 16),
                ] else ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'SWASTIK JEWELS - STATEMENT (Contd.)',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: brandGold),
                      ),
                      pw.Text(
                        'Page ${pageIndex + 1} of $pagesCount',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  pw.SizedBox(height: 12),
                ],

                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.5),
                    1: pw.FlexColumnWidth(3),
                    2: pw.FlexColumnWidth(2.5),
                    3: pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightBeige),
                      children: [
                        _buildTableHeaderCell(fontBold, 'Date', brandTeal),
                        _buildTableHeaderCell(fontBold, 'Customer / Mode', brandTeal),
                        _buildTableHeaderCell(fontBold, 'Type', brandTeal),
                        _buildTableHeaderCell(fontBold, 'Amount', brandTeal, alignRight: true),
                      ],
                    ),
                    ...pageTxns.map((txn) {
                      final isCr = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;
                      final String categoryUnit = txn.metalType == 'gold' 
                          ? 'g' 
                          : (txn.metalType == 'diamond' ? 'ct' : '');
                          
                      final amt = txn.metalType.isEmpty 
                          ? '₹${NumberFormat.decimalPattern('en_IN').format(txn.cashAmount)}'
                          : '${txn.metalWeight} $categoryUnit';
                      
                      final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(txn.date);

                      return pw.TableRow(
                        children: [
                          _buildTableCell(fontRegular, formattedDate),
                          _buildTableCell(fontRegular, txn.partyName.isEmpty ? 'General' : txn.partyName),
                          _buildTableCell(fontBold, txn.typeLabel, color: isCr ? PdfColors.green800 : PdfColors.red800),
                          _buildTableCell(
                            fontBold, 
                            '${isCr ? "+" : "-"}$amt', 
                            color: isCr ? PdfColors.green800 : PdfColors.red800,
                            alignRight: true,
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.Spacer(),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(TimeUtils.now)}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                    ),
                    pw.Text(
                      'Page ${pageIndex + 1} of $pagesCount',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static Future<Uint8List> generateCustomerLedgerPdf({
    required PartyModel party,
    required List<TransactionModel> transactions,
  }) async {
    final pdf = pw.Document();
    
    final logoData = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    
    final fontRegular = await PdfGoogleFonts.montserratRegular();
    final fontBold = await PdfGoogleFonts.montserratBold();
    
    final brandTeal = PdfColor.fromHex('#01565B');
    final brandGold = PdfColor.fromHex('#735C0F');
    final lightBeige = PdfColor.fromHex('#FAF6EE');

    const itemsPerPage = 12;
    final pagesCount = transactions.isEmpty ? 1 : (transactions.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < pagesCount; pageIndex++) {
      final startIdx = pageIndex * itemsPerPage;
      final endIdx = (startIdx + itemsPerPage < transactions.length) 
          ? startIdx + itemsPerPage 
          : transactions.length;
      final pageTxns = transactions.isEmpty ? <TransactionModel>[] : transactions.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (pageIndex == 0) ...[
                  // Header
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.Image(logoImage, width: 40, height: 40),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'SWASTIK JEWELS',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 22,
                                color: brandGold,
                                letterSpacing: 2,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'CUSTOMER STATEMENT / LEDGER',
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          'DATE: ${DateFormat('dd MMM yyyy').format(TimeUtils.now)}',
                          style: pw.TextStyle(font: fontBold, fontSize: 10, color: brandTeal),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 12),

                  // Customer Profile Block
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: lightBeige,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildProfileRow(fontRegular, fontBold, 'Customer Name:', party.name),
                              if (party.phone.isNotEmpty)
                                _buildProfileRow(fontRegular, fontBold, 'Phone Number:', party.phone),
                              if (party.address.isNotEmpty)
                                _buildProfileRow(fontRegular, fontBold, 'Address:', party.address),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Outstanding Balances:',
                                style: pw.TextStyle(font: fontBold, fontSize: 10, color: brandGold),
                              ),
                              pw.SizedBox(height: 4),
                              _buildBalanceRow(
                                fontRegular,
                                fontBold,
                                'Cash Balance:',
                                '₹ ${NumberFormat.decimalPattern('en_IN').format(party.cashBalance.abs())} (${party.cashBalance >= 0 ? "Dr / Receive" : "Cr / Give"})',
                              ),
                              if (party.goldBalanceGrams != 0)
                                _buildBalanceRow(
                                  fontRegular,
                                  fontBold,
                                  'Gold Balance:',
                                  '${party.goldBalanceGrams.abs().toStringAsFixed(3)} g (${party.goldBalanceGrams >= 0 ? "Dr / Receive" : "Cr / Give"})',
                                ),
                              if (party.diamondBalanceCarats != 0)
                                _buildBalanceRow(
                                  fontRegular,
                                  fontBold,
                                  'Diamond Balance:',
                                  '${party.diamondBalanceCarats.abs().toStringAsFixed(3)} ct (${party.diamondBalanceCarats >= 0 ? "Dr / Receive" : "Cr / Give"})',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),
                ] else ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'LEDGER STATEMENT: ${party.name} (Contd.)',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: brandGold),
                      ),
                      pw.Text(
                        'Page ${pageIndex + 1} of $pagesCount',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  pw.SizedBox(height: 12),
                ],

                // Transactions List
                if (transactions.isNotEmpty) ...[
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2),
                      1: pw.FlexColumnWidth(3),
                      2: pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: lightBeige),
                        children: [
                          _buildTableHeaderCell(fontBold, 'Date', brandTeal),
                          _buildTableHeaderCell(fontBold, 'Type / Mode', brandTeal),
                          _buildTableHeaderCell(fontBold, 'Amount', brandTeal, alignRight: true),
                        ],
                      ),
                      ...pageTxns.map((txn) {
                        final isCr = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;
                        String amt = '';
                        if (txn.metalType.isEmpty) {
                          amt = '₹${NumberFormat.decimalPattern('en_IN').format(txn.cashAmount)}';
                        } else {
                          amt = '${txn.metalWeight} ${txn.metalType == 'gold' ? 'g' : 'ct'}';
                        }
                        String typeMode = txn.typeLabel;
                        if (txn.metalType.isEmpty) {
                          typeMode += ' (${txn.paymentMode.name.toUpperCase()})';
                        } else {
                          typeMode += ' (${txn.metalType.toUpperCase()})';
                        }
                        
                        final formattedDate = DateFormat('dd MMM yyyy').format(txn.date);

                        return pw.TableRow(
                          children: [
                            _buildTableCell(fontRegular, formattedDate),
                            _buildTableCell(fontRegular, typeMode),
                            _buildTableCell(
                              fontBold,
                              '${isCr ? '+' : '-'}$amt',
                              color: isCr ? PdfColors.green800 : PdfColors.red800,
                              alignRight: true,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ] else ...[
                  pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 40),
                      child: pw.Text(
                        'No transactions recorded for this customer.',
                        style: pw.TextStyle(font: fontRegular, fontSize: 11, color: PdfColors.grey600),
                      ),
                    ),
                  ),
                ],

                pw.Spacer(),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Swastik Jewels Customer Portal',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                    ),
                    pw.Text(
                      'Page ${pageIndex + 1} of $pagesCount',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildMetaField(
    pw.Font fontRegular,
    pw.Font fontBold,
    String label,
    String value, {
    bool isRightAligned = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (isRightAligned) ...[
            pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
            pw.SizedBox(width: 4),
            pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
          ] else ...[
            pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(width: 4),
            pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildProfileRow(pw.Font fontRegular, pw.Font fontBold, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBalanceRow(pw.Font fontRegular, pw.Font fontBold, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(pw.Font font, String text, PdfColor color, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, color: color)),
      ),
    );
  }

  static pw.Widget _buildTableCell(pw.Font font, String text, {PdfColor color = PdfColors.black, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, color: color)),
      ),
    );
  }

  static Future<bool> printPdf(Uint8List bytes) async {
    try {
      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'swastik_document',
      );
    } catch (e) {
      print("Error printing PDF: $e");
      return false;
    }
  }

  static Future<bool> savePdfToDownloads(Uint8List bytes, String filename) async {
    try {
      final cleanFilename = filename.replaceAll(RegExp(r'[^\w\-_]'), '_');
      
      final String? path = await FileSaver.instance.saveAs(
        name: cleanFilename,
        bytes: bytes,
        fileExtension: "pdf",
        mimeType: MimeType.pdf,
      );
      return path != null && path.isNotEmpty;
    } catch (e) {
      print("Error saving PDF to Downloads: $e");
      return false;
    }
  }
}
