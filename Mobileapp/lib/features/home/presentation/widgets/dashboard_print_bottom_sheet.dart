import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/models/transaction_model.dart';
import 'package:swastik_mobile_app/core/services/pdf_service.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

class DashboardPrintBottomSheet extends StatefulWidget {
  final List<TransactionModel> initialTransactions;
  final String title;
  final String subtitle;
  final String? totalBalance;

  const DashboardPrintBottomSheet({
    super.key,
    required this.initialTransactions,
    required this.title,
    required this.subtitle,
    this.totalBalance,
  });

  @override
  State<DashboardPrintBottomSheet> createState() => _DashboardPrintBottomSheetState();
}

class _DashboardPrintBottomSheetState extends State<DashboardPrintBottomSheet> {
  String _typeFilter = 'All'; // 'All', 'IN', 'OUT'
  String _dateFilter = 'All Time'; // 'All Time', 'Today', 'This Week', 'This Month'
  
  bool isPrinting = false;
  bool isSaved = false;

  List<TransactionModel> get filteredTxns {
    var filtered = widget.initialTransactions.where((t) {
      final isCredit = t.type == TransactionType.receipt || t.type == TransactionType.metalIn;
      final isDebit = t.type == TransactionType.payment || t.type == TransactionType.metalOut;

      if (_typeFilter == 'IN') return isCredit;
      if (_typeFilter == 'OUT') return isDebit;
      return true;
    }).toList();

    final now = TimeUtils.now;
    filtered = filtered.where((t) {
      if (_dateFilter == 'Today') {
        return t.date.year == now.year && t.date.month == now.month && t.date.day == now.day;
      } else if (_dateFilter == 'This Week') {
        final weekAgo = now.subtract(const Duration(days: 7));
        return t.date.isAfter(weekAgo);
      } else if (_dateFilter == 'This Month') {
        return t.date.year == now.year && t.date.month == now.month;
      }
      return true;
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final txns = filteredTxns;
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6EE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Export Statement',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A3E1F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (isPrinting)
              Container(
                height: 150,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF01565B)),
                    const SizedBox(height: 20),
                    Text(
                      'Preparing document...',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5E543F),
                      ),
                    ),
                  ],
                ),
              )
            else if (isSaved)
              Container(
                height: 150,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF01565B), size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Statement Saved!',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF01565B),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Filters
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction Type',
                          style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5DEC9).withOpacity(0.6)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _typeFilter,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF735C0F)),
                              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF5E543F)),
                              items: <String>['All', 'IN', 'OUT'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value == 'All' ? 'All Types' : 'Only $value'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _typeFilter = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date Range',
                          style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5DEC9).withOpacity(0.6)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _dateFilter,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF735C0F)),
                              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF5E543F)),
                              items: <String>['All Time', 'Today', 'This Week', 'This Month'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _dateFilter = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Text(
                '${txns.length} entries selected for print.',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        setState(() => isPrinting = true);
                        try {
                          final pdfBytes = await PdfService.generateStatementPdf(
                            transactions: txns,
                            title: widget.title,
                            subtitle: null,
                            periodText: widget.subtitle.toUpperCase(),
                            totalBalance: widget.totalBalance,
                          );
                          await PdfService.printPdf(pdfBytes);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing: $e')));
                            setState(() => isPrinting = false);
                          }
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF01565B)),
                      label: Text(
                        'Print A4',
                        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF01565B)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF01565B), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => isPrinting = true);
                        try {
                          final pdfBytes = await PdfService.generateStatementPdf(
                            transactions: txns,
                            title: widget.title,
                            subtitle: null,
                            periodText: widget.subtitle.toUpperCase(),
                            totalBalance: widget.totalBalance,
                          );
                          final success = await PdfService.savePdfToDownloads(
                            pdfBytes,
                            'Statement_${DateTime.now().millisecondsSinceEpoch}',
                          );
                          setState(() {
                            isPrinting = false;
                            isSaved = success;
                          });
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
                            setState(() => isPrinting = false);
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                      label: Text(
                        'Save PDF',
                        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01565B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showDashboardPrintBottomSheet(BuildContext context, {
  required List<TransactionModel> transactions,
  required String title,
  required String subtitle,
  String? totalBalance,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DashboardPrintBottomSheet(
        initialTransactions: transactions,
        title: title,
        subtitle: subtitle,
        totalBalance: totalBalance,
      );
    },
  );
}
