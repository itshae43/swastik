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
              pw.Divider(thickness: 1, color: PdfColors.black),
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
                  border: pw.Border.all(color: PdfColors.black, width: 1.0),
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
                    pw.Divider(height: 1, thickness: 1, color: PdfColors.black),
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
                              transaction.metalType.isEmpty 
                                  ? 'Money' 
                                  : (transaction.metalType == 'gold' && transaction.metalPurity.isNotEmpty)
                                      ? '${transaction.metalType.toUpperCase()} (${transaction.metalPurity})'
                                      : transaction.metalType.toUpperCase(),
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
                                color: PdfColors.black,
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 12),

                // Customer Profile Block
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBeige,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.black, width: 1.0),
                  ),
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
                pw.SizedBox(height: 16),
              ],
            );
          } else {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'LEDGER STATEMENT: ${party.name} (Contd.)',
                      style: pw.TextStyle(font: fontBold, fontSize: 10, color: brandGold),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1.0, color: PdfColors.black),
                pw.SizedBox(height: 12),
              ],
            );
          }
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Swastik Jewels Customer Portal',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            if (transactions.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(2.5),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBeige),
                    repeat: true,
                    children: [
                      _buildTableHeaderCell(fontBold, 'Date', brandTeal),
                      _buildTableHeaderCell(fontBold, 'Mode', brandTeal),
                      _buildTableHeaderCell(fontBold, 'In/Out', brandTeal),
                      _buildTableHeaderCell(fontBold, 'Amount', brandTeal, alignRight: true),
                    ],
                  ),
                  ...transactions.map((txn) {
                    final isCr = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;
                    
                    String amt = '';
                    String mode = '';
                    
                    if (txn.metalType.isEmpty) {
                      amt = '₹${NumberFormat.decimalPattern('en_IN').format(txn.cashAmount)}';
                      mode = txn.paymentMode.name.toUpperCase();
                      if (mode == 'ONLINE') mode = 'UPI/RTGS';
                    } else {
                      amt = '${txn.metalWeight} ${txn.metalType == 'gold' ? 'g' : 'ct'}';
                      mode = txn.metalType.toUpperCase();
                      if (txn.metalType == 'gold' && txn.metalPurity.isNotEmpty) {
                        mode += ' (${txn.metalPurity})';
                      }
                    }
                    
                    final String inOut = isCr ? 'IN' : 'OUT';
                    final formattedDate = DateFormat('dd MMM yyyy').format(txn.date);

                    return pw.TableRow(
                      children: [
                        _buildTableCell(fontBold, formattedDate),
                        _buildTableWidgetCell(
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(mode, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
                              if (txn.notes.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(txn.notes, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
                              ],
                            ],
                          ),
                        ),
                        _buildTableCell(fontBold, inOut),
                        _buildTableCell(
                          fontBold,
                          '${isCr ? '+' : '-'}$amt',
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
          ];
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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
                            title.toUpperCase(),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            subtitle,
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                          if (totalBalance != null) ...[
                            pw.SizedBox(height: 8),
                            pw.Text(
                              totalBalance,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                color: brandTeal,
                              ),
                            ),
                          ],
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
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 12),
              ],
            );
          } else {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '$title (Contd.)',
                      style: pw.TextStyle(font: fontBold, fontSize: 10, color: brandGold),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1.0, color: PdfColors.black),
                pw.SizedBox(height: 12),
              ],
            );
          }
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Swastik Jewels',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            if (transactions.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(3.5),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBeige),
                    repeat: true,
                    children: [
                      _buildTableHeaderCell(fontBold, 'Date', brandTeal),
                      _buildTableHeaderCell(fontBold, 'Customer', brandTeal),
                      _buildTableHeaderCell(fontBold, 'Mode', brandTeal),
                      _buildTableHeaderCell(fontBold, 'In/Out', brandTeal),
                      _buildTableHeaderCell(fontBold, 'Amount', brandTeal, alignRight: true),
                    ],
                  ),
                  ...transactions.map((txn) {
                    final isCr = txn.type == TransactionType.receipt || txn.type == TransactionType.metalIn;

                    String amt = '';
                    String mode = '';

                    if (txn.metalType.isEmpty) {
                      amt = '₹${NumberFormat.decimalPattern('en_IN').format(txn.cashAmount)}';
                      mode = txn.paymentMode.name.toUpperCase();
                      if (mode == 'ONLINE') mode = 'UPI/RTGS';
                    } else {
                      amt = '${txn.metalWeight} ${txn.metalType == 'gold' ? 'g' : 'ct'}';
                      mode = txn.metalType.toUpperCase();
                      if (txn.metalType == 'gold' && txn.metalPurity.isNotEmpty) {
                        mode += ' (${txn.metalPurity})';
                      }
                    }

                    final String inOut = isCr ? 'IN' : 'OUT';
                    final formattedDate = DateFormat('dd MMM yyyy').format(txn.date);

                    return pw.TableRow(
                      children: [
                        _buildTableCell(fontBold, formattedDate),
                        _buildTableWidgetCell(
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(txn.partyName, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
                              if (txn.notes.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(txn.notes, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700)),
                              ],
                            ],
                          ),
                        ),
                        _buildTableCell(fontBold, mode),
                        _buildTableCell(fontBold, inOut),
                        _buildTableCell(
                          fontBold,
                          '${isCr ? '+' : '-'}$amt',
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
                    'No transactions found for this period.',
                    style: pw.TextStyle(font: fontRegular, fontSize: 11, color: PdfColors.grey600),
                  ),
                ),
              ),
            ],
          ];
        },
      ),
    );

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
            width: 100,
            child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
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
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11, color: color)),
      ),
    );
  }

  static pw.Widget _buildTableCell(pw.Font font, String text, {PdfColor color = PdfColors.black, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10, color: color)),
      ),
    );
  }

  static pw.Widget _buildTableWidgetCell(pw.Widget child, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: child,
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
      final nameWithExt = cleanFilename.endsWith('.pdf') ? cleanFilename : '$cleanFilename.pdf';
      
      // Using Printing.sharePdf to avoid the Android FileSaver 0KB lifecycle bug
      // This will open the native share/save sheet where users can save to device or send directly
      await Printing.sharePdf(
        bytes: bytes,
        filename: nameWithExt,
      );
      return true;
    } catch (e) {
      print("Error saving/sharing PDF: $e");
      return false;
    }
  }
}
