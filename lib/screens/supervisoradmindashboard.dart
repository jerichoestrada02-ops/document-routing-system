import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SupervisorAdminDashboard extends StatefulWidget {
  const SupervisorAdminDashboard({super.key});

  @override
  State<SupervisorAdminDashboard> createState() =>
      _SupervisorAdminDashboardState();
}

class _SupervisorAdminDashboardState extends State<SupervisorAdminDashboard> {
  static const Color _primaryColor = Color(0xFF7B1E1E);
  static const Color _accentColor = Color(0xFFD6B25E);
  static const Color _surfaceTint = Color(0xFFF4EFE8);
  static const Color _borderColor = Color(0xFFD8CEC0);
  static const Color _textMuted = Color(0xFF5F6B76);
  static const Color _successColor = Color(0xFF2E6A4F);
  static const Color _warningColor = Color(0xFFC67A12);
  static const Color _dangerColor = Color(0xFFB42318);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();

  String _searchText = '';
  String _selectedRegistryStatus = 'pending';
  bool _darkMode = false;

  bool get _isDark => _darkMode;
  Color get _pageBackground =>
      _isDark ? const Color(0xFF11161D) : const Color(0xFFF5F3EF);
  Color get _cardBackground => _isDark ? const Color(0xFF1A212B) : Colors.white;
  Color get _softBackground =>
      _isDark ? const Color(0xFF222B36) : const Color(0xFFF8F6F2);
  Color get _tableHeaderBackground =>
      _isDark ? const Color(0xFF24303D) : const Color(0xFFF4EFE8);
  Color get _primaryText =>
      _isDark ? const Color(0xFFF4F7FA) : const Color(0xFF1F2933);
  Color get _secondaryText => _isDark ? const Color(0xFFA9B4C0) : _textMuted;
  Color get _effectiveBorder =>
      _isDark ? const Color(0xFF344252) : _borderColor;

  @override
  void dispose() {
    _searchController.dispose();
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    super.dispose();
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/');
  }

  void _toggleTheme() {
    setState(() {
      _darkMode = !_darkMode;
    });
  }

  String _routingSlipValue(Map<String, dynamic> data, String field) {
    return (data[field] ?? '').toString().trim();
  }

  String _safePdfFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'document' : sanitized;
  }

  Future<void> exportRoutingSlipPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final dateReceived = _formatDate(_extractTimestamp(data));
    final controlNumber = _routingSlipValue(data, 'controlNumber');
    final office = _routingSlipValue(data, 'office');
    final particular = _routingSlipValue(data, 'particular');
    final comment = _routingSlipValue(data, 'comment');
    final receivedBy = _routingSlipValue(data, 'receivedBy');

    pw.Widget labeledLine(String label, String value) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 5),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 0.6, color: PdfColors.black),
                ),
              ),
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ),
        ],
      );
    }

    pw.Widget checkbox(String label) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          children: [
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.8, color: PdfColors.black),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.2, color: PdfColors.black),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'GENERAL SERVICES OFFICE',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'City Government',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'ROUTING SLIP',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: labeledLine('Communication No:', controlNumber),
                    ),
                    pw.SizedBox(width: 18),
                    pw.Expanded(child: labeledLine('Date:', dateReceived)),
                  ],
                ),
                pw.SizedBox(height: 9),
                labeledLine('From:', office),
                pw.SizedBox(height: 8),
                labeledLine('Subject:', particular),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          checkbox('For Information'),
                          checkbox('Prepare reply'),
                          checkbox('Note and file'),
                          checkbox('For investigation & report'),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 22),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          checkbox('For verification'),
                          checkbox('For appropriate action'),
                          checkbox('Signature'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Comment',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 56,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.8, color: PdfColors.black),
                  ),
                  child: pw.Text(
                    comment,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Spacer(),
                pw.Row(
                  children: [
                    pw.Expanded(child: labeledLine('Received By:', receivedBy)),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'EUGENE D. BUYUCAN',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'City General Services Officer',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'routing_slip_${_safePdfFileName(controlNumber)}.pdf';
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Timestamp? _extractTimestamp(Map<String, dynamic> data) {
    final dynamic timestamp = data['dateReceived'] ?? data['date'];
    if (timestamp is Timestamp) {
      return timestamp;
    }
    return null;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) {
      return '';
    }
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('yyyy-MM-dd').format(timestamp);
    }
    return timestamp.toString();
  }

  int? _retentionYears(String retentionPeriod) {
    final normalized = retentionPeriod.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'permanent') {
      return null;
    }

    return int.tryParse(normalized.split(' ').first);
  }

  DateTime _addYears(DateTime date, int years) {
    final targetYear = date.year + years;
    final lastDayOfTargetMonth = DateTime(targetYear, date.month + 1, 0).day;
    final adjustedDay = date.day <= lastDayOfTargetMonth
        ? date.day
        : lastDayOfTargetMonth;

    return DateTime(targetYear, date.month, adjustedDay);
  }

  DateTime? _calculateDispositionDate(
    DateTime? dateReceived,
    String retentionPeriod,
  ) {
    if (dateReceived == null) {
      return null;
    }

    final years = _retentionYears(retentionPeriod);
    if (years == null) {
      return null;
    }

    return _addYears(dateReceived, years);
  }

  String _retentionPeriodFromData(Map<String, dynamic> data) {
    return (data['retentionPeriod'] ?? data['rdsSub'] ?? '').toString();
  }

  String _filingCodeFromData(Map<String, dynamic> data) {
    final filingCode = (data['filingCode'] ?? '').toString().trim();
    if (filingCode.isNotEmpty) {
      return filingCode;
    }

    final legacyMain = (data['rdsMain'] ?? '').toString().trim();
    if (legacyMain.isNotEmpty) {
      return legacyMain;
    }

    final legacyCode = (data['rdsCode'] ?? '').toString().trim();
    if (!legacyCode.contains(' - ')) {
      return legacyCode;
    }

    return legacyCode.split(' - ').first.trim();
  }

  String _dispositionDateFromData(Map<String, dynamic> data) {
    final storedDisposition = data['dispositionDate'];
    if (storedDisposition is Timestamp) {
      return _formatDate(storedDisposition);
    }
    if (storedDisposition is DateTime) {
      return _formatDate(storedDisposition);
    }
    if (storedDisposition is String && storedDisposition.trim().isNotEmpty) {
      return storedDisposition;
    }

    final retentionPeriod = _retentionPeriodFromData(data);
    if (retentionPeriod.trim().toLowerCase() == 'permanent') {
      return 'Permanent';
    }

    final dateReceived = _extractTimestamp(data)?.toDate();
    final dispositionDate = _calculateDispositionDate(
      dateReceived,
      retentionPeriod,
    );

    return dispositionDate == null ? '' : _formatDate(dispositionDate);
  }

  String _fileLocationFromData(Map<String, dynamic> data) {
    return (data['fileLocation'] ??
            data['fileLocationAfterRetention'] ??
            data['retentionFileLocation'] ??
            data['fileLocationAfterRetentionPeriod'] ??
            '')
        .toString();
  }

  String _statusFromData(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().trim();
    return status.isEmpty ? 'pending' : status.toLowerCase();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _successColor;
      case 'rejected':
        return _dangerColor;
      case 'pending':
      default:
        return _warningColor;
    }
  }

  String _statusLabel(String status) {
    if (status.trim().isEmpty) {
      return 'Pending';
    }

    final normalized = status.toLowerCase();
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String get _selectedRegistryStatusLabel =>
      _statusLabel(_selectedRegistryStatus);

  Future<void> _approveDocument(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .update({
            'status': 'approved',
            'approvedBy': 'Supervisor Admin',
            'approvedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document approved successfully.'),
            backgroundColor: _successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving document: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _rejectDocument(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .update({'status': 'rejected', 'remarks': 'Rejected by Supervisor'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document rejected successfully.'),
            backgroundColor: _dangerColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting document: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _confirmApprove(String docId, String controlNumber) async {
    final shouldApprove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Approve Document',
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Approve document $controlNumber for supervisor review completion?',
          style: TextStyle(color: _primaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _successColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (shouldApprove == true) {
      await _approveDocument(docId);
    }
  }

  Future<void> _confirmReject(String docId, String controlNumber) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reject Document',
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Reject document $controlNumber? The remarks field will be updated to "Rejected by Supervisor".',
          style: TextStyle(color: _primaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      await _rejectDocument(docId);
    }
  }

  Widget _buildValueCell(
    String value, {
    required double width,
    Color? textColor,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value;

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _softBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _effectiveBorder),
        ),
        child: Text(
          displayValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor ?? _primaryText,
            fontSize: 12,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHorizontalScrollControl() {
    return AnimatedBuilder(
      animation: _tableHorizontalController,
      builder: (context, _) {
        final hasClients = _tableHorizontalController.hasClients;
        final maxExtent = hasClients
            ? _tableHorizontalController.position.maxScrollExtent
            : 0.0;
        final canScroll = maxExtent > 0;
        final canScrollLeft =
            hasClients && _tableHorizontalController.offset > 0;
        final canScrollRight =
            hasClients && _tableHorizontalController.offset < maxExtent;

        void scrollBy(double delta) {
          if (!canScroll) {
            return;
          }

          final target = (_tableHorizontalController.offset + delta).clamp(
            0.0,
            maxExtent,
          );
          _tableHorizontalController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _softBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _effectiveBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: canScrollLeft ? () => scrollBy(-520) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Scroll left',
                color: _primaryColor,
                splashRadius: 18,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: canScrollRight ? () => scrollBy(520) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Scroll right',
                color: _primaryColor,
                splashRadius: 18,
              ),
            ],
          ),
        );
      },
    );
  }

  int _countWithAttachments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final file = (doc.data()['scannedFileUrl'] ?? '').toString().trim();
      return file.isNotEmpty;
    }).length;
  }

  int _countAwaitingAction(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final action = (doc.data()['actionTaken'] ?? '').toString().trim();
      return action.isEmpty;
    }).length;
  }

  Widget _buildTopBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, Color(0xFF5D1717)],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          const bannerText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Supervisor Admin Approval Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Review pending registry entries, approve routing records, and keep the document workflow moving in real time.',
                style: TextStyle(
                  color: Color(0xFFF8EEDA),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          );

          return Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: const Icon(
                  Icons.approval_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              SizedBox(width: compact ? 0 : 20, height: compact ? 16 : 0),
              if (compact) bannerText else const Expanded(child: bannerText),
              SizedBox(width: compact ? 0 : 16, height: compact ? 20 : 0),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _toggleTheme,
                    icon: Icon(
                      _isDark ? Icons.light_mode_outlined : Icons.dark_mode,
                    ),
                    label: Text(_isDark ? 'Light Mode' : 'Dark Mode'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.28)),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const _SupervisorBannerPill(
                    icon: Icons.verified_user_outlined,
                    label: 'Supervisor Review',
                  ),
                  _SupervisorBannerPill(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                  ),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.28)),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _effectiveBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 960;

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 430,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search ${_selectedRegistryStatusLabel.toLowerCase()} records by date, control no., office, person, or remarks',
                    prefixIcon: const Icon(Icons.search, color: _primaryColor),
                    filled: true,
                    fillColor: _softBackground,
                    hintStyle: TextStyle(color: _secondaryText),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  style: TextStyle(color: _primaryText),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _softBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _effectiveBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_alt_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedRegistryStatus,
                      underline: const SizedBox.shrink(),
                      iconEnabledColor: _primaryColor,
                      dropdownColor: _cardBackground,
                      style: TextStyle(
                        color: _primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending Registry'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved Registry'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected Registry'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedRegistryStatus = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDataSection(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _effectiveBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Approval Registry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supervisor decisions update Firestore instantly and remove completed rows from this queue.',
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF24303D) : _surfaceTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${docs.length} ${_selectedRegistryStatusLabel.toLowerCase()}',
                    style: const TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _effectiveBorder),
          Expanded(
            child: docs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.task_alt_outlined,
                            size: 56,
                            color: _secondaryText,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No ${_selectedRegistryStatusLabel.toLowerCase()} documents found.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _primaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Use the registry status dropdown to switch views.',
                            style: TextStyle(color: _secondaryText),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _tableVerticalController,
                    thumbVisibility: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tableMinWidth = constraints.maxWidth > 2500
                            ? constraints.maxWidth
                            : 2500.0;

                        return SingleChildScrollView(
                          controller: _tableVerticalController,
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            controller: _tableHorizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: tableMinWidth,
                              ),
                              child: DataTable(
                                columnSpacing: 18,
                                horizontalMargin: 16,
                                dataRowMinHeight: 72,
                                dataRowMaxHeight: 90,
                                headingRowHeight: 58,
                                dividerThickness: 0.6,
                                headingTextStyle: TextStyle(
                                  color: _primaryText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                headingRowColor: WidgetStateProperty.all(
                                  _tableHeaderBackground,
                                ),
                                border: TableBorder(
                                  horizontalInside: BorderSide(
                                    color: _effectiveBorder,
                                  ),
                                ),
                                columns: const [
                                  DataColumn(label: Text('Date Received')),
                                  DataColumn(label: Text('Filing Code')),
                                  DataColumn(label: Text('Retention Period')),
                                  DataColumn(label: Text('File Location')),
                                  DataColumn(label: Text('Disposition Date')),
                                  DataColumn(label: Text('Control Number')),
                                  DataColumn(label: Text('Office')),
                                  DataColumn(label: Text('Particular')),
                                  DataColumn(label: Text('Forwarded To')),
                                  DataColumn(label: Text('Received By')),
                                  DataColumn(label: Text('Comment')),
                                  DataColumn(label: Text('Action Taken')),
                                  DataColumn(label: Text('Remarks')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: docs.map((doc) {
                                  final data = doc.data();
                                  final status = _statusFromData(data);
                                  final controlNumber =
                                      (data['controlNumber'] ?? '').toString();

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        _buildValueCell(
                                          _formatDate(_extractTimestamp(data)),
                                          width: 132,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          _filingCodeFromData(data),
                                          width: 152,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          _retentionPeriodFromData(data),
                                          width: 150,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          _fileLocationFromData(data),
                                          width: 172,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          _dispositionDateFromData(data),
                                          width: 148,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          controlNumber,
                                          width: 124,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['office'] ?? '').toString(),
                                          width: 156,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['particular'] ?? '').toString(),
                                          width: 220,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['forwardedTo'] ?? '')
                                              .toString(),
                                          width: 142,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['receivedBy'] ?? '').toString(),
                                          width: 156,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['comment'] ?? '').toString(),
                                          width: 172,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['actionTaken'] ?? '')
                                              .toString(),
                                          width: 172,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['remarks'] ?? '').toString(),
                                          width: 172,
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 110,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: _buildStatusBadge(status),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 132,
                                          child: Row(
                                            children: [
                                              Tooltip(
                                                message: 'Approve document',
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    onTap: status == 'approved'
                                                        ? null
                                                        : () => _confirmApprove(
                                                            doc.id,
                                                            controlNumber,
                                                          ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _successColor
                                                            .withOpacity(
                                                              _isDark
                                                                  ? 0.24
                                                                  : 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: _successColor
                                                              .withOpacity(
                                                                0.35,
                                                              ),
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.check,
                                                        color: _successColor,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Tooltip(
                                                message: 'Reject document',
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    onTap: status == 'rejected'
                                                        ? null
                                                        : () => _confirmReject(
                                                            doc.id,
                                                            controlNumber,
                                                          ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _dangerColor
                                                            .withOpacity(
                                                              _isDark
                                                                  ? 0.24
                                                                  : 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: _dangerColor
                                                              .withOpacity(
                                                                0.35,
                                                              ),
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: _dangerColor,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Tooltip(
                                                message: 'Print routing slip',
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    onTap: () =>
                                                        exportRoutingSlipPdf(
                                                          data,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _primaryColor
                                                            .withOpacity(
                                                              _isDark
                                                                  ? 0.24
                                                                  : 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: _primaryColor
                                                              .withOpacity(
                                                                0.35,
                                                              ),
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.print_outlined,
                                                        color: _primaryColor,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildHorizontalScrollControl(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewportConstraints) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('documents')
                    .orderBy('controlNumber')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading documents: ${snapshot.error}',
                          style: TextStyle(color: _primaryText),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final query = _searchText.trim().toLowerCase();
                  final selectedStatus = _selectedRegistryStatus;
                  final allStatusDocs = snapshot.data?.docs ?? [];
                  final pendingDocs = allStatusDocs
                      .where((doc) => _statusFromData(doc.data()) == 'pending')
                      .toList();
                  final approvedDocs = allStatusDocs
                      .where((doc) => _statusFromData(doc.data()) == 'approved')
                      .toList();
                  final rejectedDocs = allStatusDocs
                      .where((doc) => _statusFromData(doc.data()) == 'rejected')
                      .toList();
                  final allDocs = (snapshot.data?.docs ?? []).where((doc) {
                    final status = _statusFromData(doc.data());
                    return status == selectedStatus;
                  }).toList();
                  final docs = allDocs.where((doc) {
                    if (query.isEmpty) {
                      return true;
                    }

                    final data = doc.data();
                    final searchableValues = [
                      _formatDate(_extractTimestamp(data)),
                      _filingCodeFromData(data),
                      _retentionPeriodFromData(data),
                      _dispositionDateFromData(data),
                      (data['controlNumber'] ?? '').toString(),
                      (data['office'] ?? '').toString(),
                      (data['particular'] ?? '').toString(),
                      (data['forwardedTo'] ?? '').toString(),
                      (data['receivedBy'] ?? '').toString(),
                      (data['comment'] ?? '').toString(),
                      (data['actionTaken'] ?? '').toString(),
                      _fileLocationFromData(data),
                      (data['remarks'] ?? '').toString(),
                      _statusFromData(data),
                    ].map((value) => value.toLowerCase());

                    return searchableValues.any(
                      (value) => value.contains(query),
                    );
                  }).toList();

                  final contentWidth = viewportConstraints.maxWidth - 48;
                  final statCardWidth = contentWidth >= 1360
                      ? (contentWidth - 16 * 2) / 3
                      : contentWidth >= 920
                      ? (contentWidth - 16) / 2
                      : contentWidth;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewportConstraints.maxHeight - 48,
                      ),
                      child: Column(
                        children: [
                          _buildTopBanner(),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: statCardWidth,
                                child: _SupervisorStatCard(
                                  title: 'Pending Queue',
                                  value: '${pendingDocs.length}',
                                  subtitle: 'Documents waiting for approval',
                                  icon: Icons.pending_actions_outlined,
                                  highlightColor: _warningColor,
                                  darkMode: _isDark,
                                ),
                              ),
                              SizedBox(
                                width: statCardWidth,
                                child: _SupervisorStatCard(
                                  title: 'Approved',
                                  value: '${approvedDocs.length}',
                                  subtitle: 'Records approved by supervisor',
                                  icon: Icons.check_circle_outline,
                                  highlightColor: const Color(0xFF295C88),
                                  darkMode: _isDark,
                                ),
                              ),
                              SizedBox(
                                width: statCardWidth,
                                child: _SupervisorStatCard(
                                  title: 'Rejected',
                                  value: '${rejectedDocs.length}',
                                  subtitle: 'Records rejected by supervisor',
                                  icon: Icons.cancel_outlined,
                                  highlightColor: _dangerColor,
                                  darkMode: _isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildToolbar(),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 560,
                            child: _buildDataSection(context, docs),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

class _SupervisorStatCard extends StatelessWidget {
  const _SupervisorStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.highlightColor,
    required this.darkMode,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color highlightColor;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF1A212B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: darkMode ? const Color(0xFF344252) : const Color(0xFFD8CEC0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: highlightColor),
              ),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: highlightColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: darkMode
                  ? const Color(0xFFF4F7FA)
                  : const Color(0xFF1F2933),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: darkMode
                  ? const Color(0xFFF4F7FA)
                  : const Color(0xFF1F2933),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: darkMode
                  ? const Color(0xFFA9B4C0)
                  : const Color(0xFF5F6B76),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupervisorBannerPill extends StatelessWidget {
  const _SupervisorBannerPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFF8EEDA)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
