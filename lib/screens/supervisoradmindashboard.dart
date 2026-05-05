import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
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
  static const Color _primaryColor = Color(0xFF5A7D9A); // slate-blue
  static const Color _accentColor = Color(0xFFD4AF37); // gold
  static const Color _surfaceTint = Color(0xFFF4EFE8);
  static const Color _borderColor = Color(0xFFD8CEC0);
  static const Color _textMuted = Color(0xFF5F6B76);
  static const Color _successColor = Color(0xFF10B981); // emerald
  static const Color _warningColor = Color(0xFFD4AF37); // gold for pending
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

  int _calculateHoursAgo(Map<String, dynamic> data) {
    final timestamp = _extractTimestamp(data);
    if (timestamp == null) return 0;
    final now = DateTime.now();
    final diff = now.difference(timestamp.toDate());
    return diff.inHours;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _successColor; // emerald
      case 'rejected':
        return _dangerColor;
      case 'pending':
      default:
        return _warningColor; // gold
    }
  }

  String _statusLabel(String status) {
    if (status.trim().isEmpty) {
      return 'Pending';
    }

    final normalized = status.toLowerCase();
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String _accessLabelFromData(Map<String, dynamic> data) {
    final isConfidential = data['isConfidential'] == true ||
        data['confidential'] == true ||
        (data['access']?.toString().toLowerCase() == 'confidential');

    return isConfidential ? 'Confidential' : 'Open';
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

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _secondaryText),
      filled: true,
      fillColor: _softBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _effectiveBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _effectiveBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
    );
  }

  Future<void> _showEditDocumentDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final controlNumberController = TextEditingController(
      text: (data['controlNumber'] ?? '').toString(),
    );
    final officeController = TextEditingController(
      text: (data['office'] ?? '').toString(),
    );
    final particularController = TextEditingController(
      text: (data['particular'] ?? '').toString(),
    );
    final forwardedToController = TextEditingController(
      text: (data['forwardedTo'] ?? '').toString(),
    );
    final receivedByController = TextEditingController(
      text: (data['receivedBy'] ?? '').toString(),
    );
    final commentController = TextEditingController(
      text: (data['comment'] ?? '').toString(),
    );
    final actionTakenController = TextEditingController(
      text: (data['actionTaken'] ?? '').toString(),
    );
    final fileLocationController = TextEditingController(
      text: _fileLocationFromData(data),
    );
    final remarksController = TextEditingController(
      text: (data['remarks'] ?? '').toString(),
    );
    final filingCodeController = TextEditingController(
      text: (data['filingCode'] ?? '').toString(),
    );
    final retentionPeriodController = TextEditingController(
      text: _retentionPeriodFromData(data),
    );
    String? selectedReceivedDocFileName =
        (data['pdfFileName'] ?? '').toString().isEmpty
            ? null
            : (data['pdfFileName'] ?? '').toString();
    String? selectedAdminDocFileName =
        (data['adminDocumentFileName'] ?? '').toString().isEmpty
            ? null
            : (data['adminDocumentFileName'] ?? '').toString();
    String selectedStatus = _statusFromData(data);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Document',
            style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      final fieldWidth = isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: controlNumberController,
                              decoration: _dialogInputDecoration('Control Number'),
                              style: TextStyle(color: _primaryText),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: officeController,
                              decoration: _dialogInputDecoration('Office'),
                              style: TextStyle(color: _primaryText),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: particularController,
                    decoration: _dialogInputDecoration('Particular'),
                    maxLines: 2,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setDialogState(() {
                                selectedReceivedDocFileName = result.files.first.name;
                              });
                            }
                          },
                          icon: const Icon(Icons.attach_file, size: 16),
                          label: Text(selectedReceivedDocFileName ?? 'Attach'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _effectiveBorder),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (selectedReceivedDocFileName != null &&
                          selectedReceivedDocFileName!.isNotEmpty)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                selectedReceivedDocFileName = null;
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: _dangerColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setDialogState(() {
                                selectedAdminDocFileName = result.files.first.name;
                              });
                            }
                          },
                          icon: const Icon(Icons.attach_file, size: 16),
                          label: Text(selectedAdminDocFileName ?? 'Attach'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _effectiveBorder),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (selectedAdminDocFileName != null &&
                          selectedAdminDocFileName!.isNotEmpty)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                selectedAdminDocFileName = null;
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: _dangerColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      final fieldWidth = isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: forwardedToController,
                              decoration: _dialogInputDecoration('Forwarded To'),
                              style: TextStyle(color: _primaryText),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: receivedByController,
                              decoration: _dialogInputDecoration('Received By'),
                              style: TextStyle(color: _primaryText),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    decoration: _dialogInputDecoration('Comment'),
                    maxLines: 2,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: actionTakenController,
                    decoration: _dialogInputDecoration('Action Taken'),
                    maxLines: 2,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fileLocationController,
                    decoration: _dialogInputDecoration('File Location'),
                    maxLines: 2,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    decoration: _dialogInputDecoration('Remarks'),
                    maxLines: 2,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      final fieldWidth = isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: filingCodeController,
                              decoration: _dialogInputDecoration('Filing Code'),
                              style: TextStyle(color: _primaryText),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: retentionPeriodController,
                              decoration: _dialogInputDecoration(
                                'Retention Period',
                              ),
                              style: TextStyle(color: _primaryText),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: _dialogInputDecoration('Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    },
                    style: TextStyle(color: _primaryText),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('documents')
                    .doc(docId)
                    .update({
                      'controlNumber': controlNumberController.text.trim(),
                      'office': officeController.text.trim(),
                      'particular': particularController.text.trim(),
                      'forwardedTo': forwardedToController.text.trim(),
                      'receivedBy': receivedByController.text.trim(),
                      'comment': commentController.text.trim(),
                      'actionTaken': actionTakenController.text.trim(),
                      'fileLocation': fileLocationController.text.trim(),
                      'remarks': remarksController.text.trim(),
                      'filingCode': filingCodeController.text.trim(),
                      'retentionPeriod': retentionPeriodController.text.trim(),
                      'pdfFileName': selectedReceivedDocFileName ?? '',
                      'scannedFileUrl': selectedReceivedDocFileName ?? '',
                      'adminDocumentFileName': selectedAdminDocFileName ?? '',
                      'adminDocumentUrl': selectedAdminDocFileName ?? '',
                      'status': selectedStatus,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document updated successfully.'),
                      backgroundColor: _successColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
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
      child: InkWell(
        onTap: () {
          if (displayValue != '-' && displayValue.isNotEmpty) {
            _showCellContentDialog(displayValue);
          }
        },
        borderRadius: BorderRadius.circular(10),
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

  Future<void> _showCellContentDialog(String content) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardBackground,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Cell Content',
          style: TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 340),
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: TextStyle(
                color: _primaryText,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Close',
              style: TextStyle(color: _primaryText, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadFile(String url, String fileName) {
    if (url.trim().isEmpty) {
      return;
    }

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName.isNotEmpty ? fileName : 'attachment')
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  }

  Widget _buildDownloadRow(String label, String fileName, String fileUrl) {
    final hasFile = fileUrl.trim().isNotEmpty;
    final displayName = fileName.isNotEmpty
        ? fileName
        : (hasFile ? 'Download file' : '-');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: _secondaryText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: hasFile
                ? TextButton.icon(
                    onPressed: () => _downloadFile(fileUrl, fileName),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      displayName,
                      style: TextStyle(color: _primaryText),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryText,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                  )
                : Text(
                    displayName,
                    style: TextStyle(color: _primaryText, fontSize: 13),
                  ),
          ),
        ],
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
        final canScrollLeft =
            hasClients && _tableHorizontalController.offset > 0;
        final canScrollRight =
            hasClients && _tableHorizontalController.offset < maxExtent;

        void scrollBy(double delta) {
          if (!_tableHorizontalController.hasClients) {
            return;
          }

          final position = _tableHorizontalController.position;
          if (position.maxScrollExtent <= 0) {
            return;
          }

          final target = (position.pixels + delta).clamp(
            0.0,
            position.maxScrollExtent,
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
                onPressed: () => scrollBy(-520),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Scroll left',
                color: canScrollLeft ? _primaryColor : _secondaryText,
                splashRadius: 18,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => scrollBy(520),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Scroll right',
                color: canScrollRight ? _primaryColor : _secondaryText,
                splashRadius: 18,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsPanel({
    required int totalDocuments,
    required int pending,
    required int approved,
    required int rejected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Supervisor Overview',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _SupervisorStatCard(
          title: 'Total Documents',
          value: '$totalDocuments',
          subtitle: 'All matched records',
          icon: Icons.description_outlined,
          highlightColor: _primaryColor,
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
        const SizedBox(height: 16),
        _SupervisorStatCard(
          title: 'Pending',
          value: '$pending',
          subtitle: 'Awaiting supervisor action',
          icon: Icons.pending_actions_outlined,
          highlightColor: _warningColor,
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
        const SizedBox(height: 16),
        _SupervisorStatCard(
          title: 'Approved',
          value: '$approved',
          subtitle: 'Supervisor approved',
          icon: Icons.check_circle_outline,
          highlightColor: _successColor,
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
        const SizedBox(height: 16),
        _SupervisorStatCard(
          title: 'Rejected',
          value: '$rejected',
          subtitle: 'Supervisor rejected',
          icon: Icons.cancel_outlined,
          highlightColor: _dangerColor,
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
      ],
    );
  }

  Future<void> _showViewMoreDialog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int initialIndex,
  ) async {
    Widget infoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: TextStyle(
                  color: _secondaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.trim().isEmpty ? '-' : value,
                style: TextStyle(color: _primaryText, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    Widget infoCard(String title, List<Widget> children) {
      return Card(
        color: _cardBackground,
        elevation: Theme.of(context).brightness == Brightness.light ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: Theme.of(context).brightness == Brightness.dark
              ? BorderSide(color: _effectiveBorder, width: 1)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
    }

    Widget statusBadge(String status) {
      Color bgColor;
      IconData icon;
      switch (status.toLowerCase()) {
        case 'approved':
          bgColor = _successColor;
          icon = Icons.check_circle;
          break;
        case 'rejected':
          bgColor = _dangerColor;
          icon = Icons.cancel;
          break;
        default:
          bgColor = _warningColor;
          icon = Icons.hourglass_empty;
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bgColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: bgColor),
            const SizedBox(width: 6),
            Text(
              _statusLabel(status),
              style: TextStyle(
                color: bgColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    Widget routingTimeline(Map<String, dynamic> data) {
      final items = <Widget>[];
      final forwardedTo = (data['forwardedTo'] ?? '').toString().trim();
      final receivedBy = (data['receivedBy'] ?? '').toString().trim();

      if (forwardedTo.isNotEmpty) {
        items.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_forward, size: 16, color: _primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forwarded To: $forwardedTo',
                      style: TextStyle(color: _primaryText, fontSize: 14),
                    ),
                    if (receivedBy.isNotEmpty)
                      Text(
                        'Received By: $receivedBy',
                        style: TextStyle(color: _secondaryText, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Column(children: items);
    }

    Widget attachmentRow(String label, String fileName, String url) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                '$label:',
                style: TextStyle(
                  color: _secondaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: fileName.isEmpty || url.isEmpty
                  ? Text(
                      '-',
                      style: TextStyle(color: _secondaryText, fontSize: 14),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDark ? _cardBackground : _softBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _effectiveBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file, size: 20, color: _primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              style: TextStyle(color: _primaryText, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _downloadFile(url, fileName),
                            icon: Icon(Icons.download, color: _primaryColor),
                            tooltip: 'Download',
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    int currentIndex = initialIndex;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          StatefulBuilder(
        builder: (dialogContext, setState) {
          final currentDoc = docs[currentIndex];
          final data = currentDoc.data();
          final docId = currentDoc.id;
          final controlNumber = (data['controlNumber'] ?? '').toString();
          final status = _statusFromData(data);

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              backgroundColor: _pageBackground,
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document Details',
                          style: TextStyle(
                            color: _primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'Control Number: $controlNumber',
                          style: TextStyle(
                            color: _secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: Icon(Icons.close, color: _primaryText),
                  ),
                ],
              ),
              content: SizedBox(
                width: 900,
                height: 600,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 700;
                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: isCompact
                                ? Column(
                                    children: [
                                      infoCard(
                                        'Core Info',
                                        [
                                          infoRow('Date Received', _formatDate(_extractTimestamp(data))),
                                          infoRow('Office', (data['office'] ?? '').toString()),
                                          infoRow('Access', _accessLabelFromData(data)),
                                          const SizedBox(height: 8),
                                          statusBadge(status),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      infoCard(
                                        'Record Details',
                                        [
                                          infoRow('Filing Code', _filingCodeFromData(data)),
                                          infoRow('Retention Period', _retentionPeriodFromData(data)),
                                          infoRow('File Location', _fileLocationFromData(data)),
                                          infoRow('Disposition Date', _dispositionDateFromData(data)),
                                          infoRow('Action Taken', (data['actionTaken'] ?? '').toString()),
                                          infoRow('Remarks', (data['remarks'] ?? '').toString()),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      infoCard(
                                        'Attachments',
                                        [
                                          attachmentRow(
                                            'Received Document',
                                            (data['pdfFileName'] ?? '').toString().trim(),
                                            (data['scannedFileUrl'] ?? '').toString().trim(),
                                          ),
                                          attachmentRow(
                                            'Document',
                                            (data['adminDocumentFileName'] ?? '').toString().trim(),
                                            (data['adminDocumentUrl'] ?? '').toString().trim(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      infoCard(
                                        'Routing & History',
                                        [
                                          infoRow('Particular', (data['particular'] ?? '').toString()),
                                          infoRow('Comment', (data['comment'] ?? '').toString()),
                                          const SizedBox(height: 8),
                                          routingTimeline(data),
                                        ],
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            infoCard(
                                              'Core Info',
                                              [
                                                infoRow('Date Received', _formatDate(_extractTimestamp(data))),
                                                infoRow('Office', (data['office'] ?? '').toString()),
                                                infoRow('Access', _accessLabelFromData(data)),
                                                const SizedBox(height: 8),
                                                statusBadge(status),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            infoCard(
                                              'Record Details',
                                              [
                                                infoRow('Filing Code', _filingCodeFromData(data)),
                                                infoRow('Retention Period', _retentionPeriodFromData(data)),
                                                infoRow('File Location', _fileLocationFromData(data)),
                                                infoRow('Disposition Date', _dispositionDateFromData(data)),
                                                infoRow('Action Taken', (data['actionTaken'] ?? '').toString()),
                                                infoRow('Remarks', (data['remarks'] ?? '').toString()),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            infoCard(
                                              'Attachments',
                                              [
                                                attachmentRow(
                                                  'Received Document',
                                                  (data['pdfFileName'] ?? '').toString().trim(),
                                                  (data['scannedFileUrl'] ?? '').toString().trim(),
                                                ),
                                                attachmentRow(
                                                  'Document',
                                                  (data['adminDocumentFileName'] ?? '').toString().trim(),
                                                  (data['adminDocumentUrl'] ?? '').toString().trim(),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: infoCard(
                                          'Routing & History',
                                          [
                                            infoRow('Particular', (data['particular'] ?? '').toString()),
                                            infoRow('Comment', (data['comment'] ?? '').toString()),
                                            const SizedBox(height: 8),
                                            routingTimeline(data),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Text(
                                'View-only mode | Modified ${_calculateHoursAgo(data)} hours ago',
                                style: TextStyle(color: _secondaryText, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: currentIndex > 0
                              ? () {
                                  setState(() {
                                    currentIndex -= 1;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: currentIndex < docs.length - 1
                              ? () {
                                  setState(() {
                                    currentIndex += 1;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: status == 'approved'
                              ? null
                              : () => _confirmApprove(docId, controlNumber),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _successColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: const Size(80, 36),
                          ),
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: status == 'rejected'
                              ? null
                              : () => _confirmReject(docId, controlNumber),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _dangerColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: const Size(80, 36),
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showEditDocumentDialog(docId, data);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: const Size(80, 36),
                          ),
                          child: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => exportRoutingSlipPdf(data),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: const Size(100, 36),
                          ),
                          icon: const Icon(Icons.print),
                          label: const Text('Print Slip'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
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
                          value: 'all',
                          child: Text('All Registry'),
                        ),
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
                        'Registry Documents',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A simplified supervisor view with quick controls, document details, and status tracking.',
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
                        final tableMinWidth = constraints.maxWidth > 1000
                            ? constraints.maxWidth
                            : 1000.0;

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
                                showCheckboxColumn: false,
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
                                  DataColumn(label: Text('Control Number')),
                                  DataColumn(label: Text('Date Received')),
                                  DataColumn(label: Text('Office')),
                                  DataColumn(label: Text('Particular')),
                                  DataColumn(label: Text('Comment')),
                                  DataColumn(label: Text('Access')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: docs.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final doc = entry.value;
                                  final data = doc.data();
                                  final controlNumber =
                                      (data['controlNumber'] ?? '').toString();
                                  final receivedDocStatus =
                                      ((data['pdfFileName'] ?? '')
                                              .toString()
                                              .trim())
                                          .isNotEmpty
                                      ? (data['pdfFileName'] ?? '').toString()
                                      : ((data['scannedFileUrl'] ?? '')
                                                .toString()
                                                .trim())
                                            .isNotEmpty
                                      ? 'PDF attached'
                                      : '-';
                                              final fileStatus =
                                      ((data['adminDocumentFileName'] ?? '')
                                              .toString()
                                              .trim())
                                          .isNotEmpty
                                      ? (data['adminDocumentFileName'] ?? '')
                                            .toString()
                                      : ((data['adminDocumentUrl'] ?? '')
                                                .toString()
                                                .trim())
                                            .isNotEmpty
                                      ? 'File attached'
                                      : '-';
                                  final accessLabel = _accessLabelFromData(data);

                                  return DataRow(
                                    onSelectChanged: (_) {
                                      _showViewMoreDialog(docs, index);
                                    },
                                    color: WidgetStateProperty.all(
                                      index.isEven
                                          ? _softBackground.withOpacity(0.3)
                                          : null,
                                    ),
                                    cells: [
                                      DataCell(
                                        _buildValueCell(
                                          controlNumber,
                                          width: 140,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          _formatDate(_extractTimestamp(data)),
                                          width: 120,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          (data['office'] ?? '').toString(),
                                          width: 140,
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
                                          (data['comment'] ?? '').toString(),
                                          width: 220,
                                        ),
                                      ),
                                      DataCell(
                                        _buildValueCell(
                                          accessLabel,
                                          width: 110,
                                          textColor: accessLabel == 'Confidential'
                                              ? _dangerColor
                                              : _successColor,
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 130,
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _showViewMoreDialog(docs, index),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _primaryColor,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text(
                                              'View More',
                                              style: TextStyle(fontSize: 12),
                                            ),
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
                    return selectedStatus == 'all' || status == selectedStatus;
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
                  final panelHeight = math.max(
                    760.0,
                    viewportConstraints.maxHeight - 120,
                  );

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
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 1200;
                              return isWide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 360,
                                          child: _buildStatsPanel(
                                            totalDocuments: allDocs.length,
                                            pending: pendingDocs.length,
                                            approved: approvedDocs.length,
                                            rejected: rejectedDocs.length,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: SizedBox(
                                            height: panelHeight,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _buildToolbar(),
                                                const SizedBox(height: 20),
                                                Expanded(
                                                  child: _buildDataSection(
                                                    context,
                                                    docs,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildToolbar(),
                                        const SizedBox(height: 20),
                                        _buildStatsPanel(
                                          totalDocuments: allDocs.length,
                                          pending: pendingDocs.length,
                                          approved: approvedDocs.length,
                                          rejected: rejectedDocs.length,
                                        ),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          height: panelHeight,
                                          child: _buildDataSection(
                                            context,
                                            docs,
                                          ),
                                        ),
                                      ],
                                    );
                            },
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
    required this.totalDocuments,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color highlightColor;
  final bool darkMode;
  final int totalDocuments;

  @override
  Widget build(BuildContext context) {
    final progressValue = totalDocuments > 0
        ? (int.tryParse(value) ?? 0) / totalDocuments
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: darkMode
              ? [const Color(0xFF1A212B), const Color(0xFF2A3441)]
              : [Colors.white, const Color(0xFFF8F8F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: darkMode ? const Color(0xFF344252) : const Color(0xFFD8CEC0),
        ),
        boxShadow: [
          BoxShadow(
            color: highlightColor.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
          const BoxShadow(
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
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: highlightColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
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
