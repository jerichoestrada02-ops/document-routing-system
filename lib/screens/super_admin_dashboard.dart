import 'dart:convert';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  static const List<String> _forwardedToOptions = [
    'Admin',
    'Procurement',
    'Solid Waste',
    'Asset',
    'Records',
  ];

  static const Color _primaryColor = Color(0xFF7B1E1E);
  static const Color _accentColor = Color(0xFFD6B25E);
  static const Color _surfaceTint = Color(0xFFF4EFE8);
  static const Color _borderColor = Color(0xFFD8CEC0);
  static const Color _textMuted = Color(0xFF5F6B76);
  static const Color _successColor = Color(0xFF2E6A4F);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateReceivedController = TextEditingController();
  final TextEditingController _rdsCodeController = TextEditingController();
  final TextEditingController _controlNumberController =
      TextEditingController();
  final TextEditingController _officeController = TextEditingController();
  final TextEditingController _particularController = TextEditingController();
  final TextEditingController _pdfNameController = TextEditingController();
  final TextEditingController _receivedByController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _actionTakenController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();

  final _formKey = GlobalKey<FormState>();

  String _searchText = '';
  String _exportFilter = 'Week';
  String? _selectedForwardedTo;
  String _selectedPdfDataUrl = '';
  DateTime? _selectedDateReceived;
  DateTimeRange _selectedExportRange = DateTimeRange(
    start: DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    ),
    end: DateTime.now().add(
      Duration(days: DateTime.daysPerWeek - DateTime.now().weekday),
    ),
  );
  bool _darkMode = false;

  bool get _isDark => _darkMode;
  Color get _pageBackground =>
      _isDark ? const Color(0xFF11161D) : const Color(0xFFF5F3EF);
  Color get _cardBackground => _isDark ? const Color(0xFF1A212B) : Colors.white;
  Color get _softBackground =>
      _isDark ? const Color(0xFF222B36) : const Color(0xFFF8F6F2);
  Color get _tableHeaderBackground =>
      _isDark ? const Color(0xFF24303D) : const Color(0xFFF4EFE8);
  Color get _fieldFill => _isDark ? const Color(0xFF202A35) : Colors.white;
  Color get _primaryText =>
      _isDark ? const Color(0xFFF4F7FA) : const Color(0xFF1F2933);
  Color get _secondaryText => _isDark ? const Color(0xFFA9B4C0) : _textMuted;
  Color get _effectiveBorder =>
      _isDark ? const Color(0xFF344252) : _borderColor;

  @override
  void initState() {
    super.initState();
    _generateControlNumber();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateReceivedController.dispose();
    _rdsCodeController.dispose();
    _controlNumberController.dispose();
    _officeController.dispose();
    _particularController.dispose();
    _pdfNameController.dispose();
    _receivedByController.dispose();
    _commentController.dispose();
    _actionTakenController.dispose();
    _remarksController.dispose();
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    super.dispose();
  }

  Future<void> _generateControlNumber() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('documents')
          .orderBy('controlNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastControlNumber =
            (snapshot.docs.first.data()['controlNumber'] ?? '').toString();
        final digitsOnly = RegExp(r'\d+')
            .allMatches(lastControlNumber)
            .fold(
              '',
              (previousValue, element) => previousValue + element.group(0)!,
            );
        final nextNumber = (int.tryParse(digitsOnly) ?? 0) + 1;
        _controlNumberController.text = nextNumber.toString().padLeft(4, '0');
      } else {
        _controlNumberController.text = '0001';
      }
    } catch (_) {
      _controlNumberController.text = '0001';
    }
  }

  Timestamp? _extractTimestamp(Map<String, dynamic> data) {
    final dynamic timestamp = data['dateReceived'] ?? data['date'];
    if (timestamp is Timestamp) {
      return timestamp;
    }
    return null;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('yyyy-MM-dd').format(timestamp);
    }
    return timestamp.toString();
  }

  Future<void> _addDocument() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedDateReceived == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('documents').add({
        'dateReceived': Timestamp.fromDate(_selectedDateReceived!),
        'rdsCode': _rdsCodeController.text.trim(),
        'controlNumber': _controlNumberController.text.trim(),
        'office': _officeController.text.trim(),
        'particular': _particularController.text.trim(),
        'scannedFileUrl': _selectedPdfDataUrl,
        'pdfFileName': _pdfNameController.text.trim(),
        'forwardedTo': _selectedForwardedTo ?? '',
        'receivedBy': _receivedByController.text.trim(),
        'comment': _commentController.text.trim(),
        'actionTaken': _actionTakenController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'adminDocumentUrl': '',
        'adminDocumentFileName': '',
        'hasBeenDownloaded': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      await _generateControlNumber();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document added successfully.'),
            backgroundColor: _successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _clearForm() {
    setState(() {
      _selectedDateReceived = null;
      _selectedForwardedTo = null;
    });
    _dateReceivedController.clear();
    _rdsCodeController.clear();
    _officeController.clear();
    _particularController.clear();
    _pdfNameController.clear();
    _receivedByController.clear();
    _commentController.clear();
    _actionTakenController.clear();
    _remarksController.clear();
    _selectedPdfDataUrl = '';
  }

  Future<void> _updateDocument(
    String docId,
    String field,
    String newValue,
  ) async {
    try {
      dynamic valueToUpdate = newValue.trim();

      if (field == 'dateReceived') {
        valueToUpdate = Timestamp.fromDate(DateTime.parse(newValue));
      }

      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .update({
            field: valueToUpdate,
            if (field == 'dateReceived') 'date': valueToUpdate,
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted.'),
            backgroundColor: _successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/');
  }

  void _toggleTheme() {
    setState(() {
      _darkMode = !_darkMode;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateReceived ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDateReceived = picked;
        _dateReceivedController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  DateTimeRange _rangeForFilter(String filter, DateTime anchorDate) {
    if (filter == 'Week') {
      final start = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
      ).subtract(Duration(days: anchorDate.weekday - 1));
      return DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    }

    if (filter == 'Month') {
      final start = DateTime(anchorDate.year, anchorDate.month);
      final end = DateTime(anchorDate.year, anchorDate.month + 1, 0);
      return DateTimeRange(start: start, end: end);
    }

    if (filter == 'Year') {
      return DateTimeRange(
        start: DateTime(anchorDate.year, 1, 1),
        end: DateTime(anchorDate.year, 12, 31),
      );
    }

    return _selectedExportRange;
  }

  void _setExportFilter(String value) {
    setState(() {
      _exportFilter = value;
      if (value != 'Custom Range') {
        _selectedExportRange = _rangeForFilter(
          value,
          _selectedExportRange.start,
        );
      }
    });
  }

  Future<void> _pickExportRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedExportRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedExportRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        );
        _exportFilter = 'Custom Range';
      });
    }
  }

  Future<void> _exportCSV(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final List<List<String>> csvData = [
      [
        'Date Received',
        'RDS Code',
        'Control Number',
        'Office',
        'Particular',
        'Received Document',
        'Forwarded To',
        'Received By',
        'Comment',
        'Action Taken',
        'Remarks',
        'Scanned File URL',
      ],
    ];

    final activeRange = _exportFilter == 'Custom Range'
        ? _selectedExportRange
        : _rangeForFilter(_exportFilter, _selectedExportRange.start);

    for (final doc in docs) {
      final data = doc.data();
      final timestamp = _extractTimestamp(data);
      if (timestamp == null) {
        continue;
      }

      final date = timestamp.toDate();
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final include =
          !normalizedDate.isBefore(activeRange.start) &&
          !normalizedDate.isAfter(activeRange.end);

      if (include) {
        csvData.add([
          DateFormat('yyyy-MM-dd').format(date),
          (data['rdsCode'] ?? '').toString(),
          (data['controlNumber'] ?? '').toString(),
          (data['office'] ?? '').toString(),
          (data['particular'] ?? '').toString(),
          (data['pdfFileName'] ?? '').toString(),
          (data['forwardedTo'] ?? '').toString(),
          (data['receivedBy'] ?? '').toString(),
          (data['comment'] ?? '').toString(),
          (data['actionTaken'] ?? '').toString(),
          (data['adminDocumentFileName'] ?? '').toString(),
          (data['remarks'] ?? '').toString(),
          (data['scannedFileUrl'] ?? '').toString(),
        ]);
      }
    }

    final csv = const ListToCsvConverter().convert(csvData);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'documents_export_${_exportFilter.toLowerCase()}.csv',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _buildExportDateLabel() {
    final activeRange = _exportFilter == 'Custom Range'
        ? _selectedExportRange
        : _rangeForFilter(_exportFilter, _selectedExportRange.start);
    return '${DateFormat('MMM d, yyyy').format(activeRange.start)} - ${DateFormat('MMM d, yyyy').format(activeRange.end)}';
  }

  Widget _buildEditableCell(
    String docId,
    String field,
    String value, {
    double width = 160,
  }) {
    final controller = TextEditingController(text: value);

    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: _fieldFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _effectiveBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
        style: TextStyle(
          color: _primaryText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        onSubmitted: (newValue) {
          final trimmed = newValue.trim();
          if (trimmed != value.trim() && trimmed.isNotEmpty) {
            _updateDocument(docId, field, trimmed);
          }
        },
      ),
    );
  }

  Future<void> _pickPdf(void Function(void Function()) setDialogState) async {
    final uploadInput = html.FileUploadInputElement()..accept = '.pdf';
    uploadInput.click();

    await uploadInput.onChange.first;
    final file = uploadInput.files?.first;
    if (file == null) {
      return;
    }

    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;

    setDialogState(() {
      _selectedPdfDataUrl = reader.result?.toString() ?? '';
      _pdfNameController.text = file.name;
    });
  }

  void _openPdf(String pdfUrl) {
    if (pdfUrl.trim().isEmpty) {
      return;
    }

    html.window.open(pdfUrl, '_blank');
  }

  Future<void> _downloadPdf(
    String docId,
    String pdfUrl,
    String fileName,
  ) async {
    if (pdfUrl.trim().isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('documents').doc(docId).update({
        'hasBeenDownloaded': true,
        'lastDownloadedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Keep download available even if tracking update fails.
    }

    final sanitizedFileName = fileName.trim().isNotEmpty
        ? fileName.trim()
        : 'document.pdf';

    final anchor = html.AnchorElement(href: pdfUrl)
      ..setAttribute('download', sanitizedFileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  }

  InputDecoration _dialogInputDecoration(
    String label, {
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFill,
      labelStyle: TextStyle(color: _secondaryText),
      hintStyle: TextStyle(color: _secondaryText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _effectiveBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _effectiveBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
    );
  }

  void _showAddDocumentDialog() {
    _clearForm();
    _generateControlNumber();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark
              ? const Color(0xFF161E27)
              : const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surfaceTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.note_add_outlined,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Incoming Document',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Capture official routing details before endorsement.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 760,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              await _pickDate(dialogContext);
                              setDialogState(() {});
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _dateReceivedController,
                                decoration: _dialogInputDecoration(
                                  'Date Received',
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a date';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _rdsCodeController,
                            decoration: _dialogInputDecoration('RDS Code'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controlNumberController,
                            decoration: _dialogInputDecoration(
                              'Control Number',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _officeController,
                            decoration: _dialogInputDecoration('Office'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _particularController,
                      decoration: _dialogInputDecoration('Particular'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pdfNameController,
                            readOnly: true,
                            decoration: _dialogInputDecoration(
                              'PDF Attachment',
                              hintText: 'No PDF selected',
                              suffixIcon: IconButton(
                                onPressed: () async {
                                  await _pickPdf(setDialogState);
                                },
                                icon: const Icon(Icons.upload_file_outlined),
                                tooltip: 'Upload PDF',
                              ),
                            ),
                          ),
                        ),
                        if (_selectedPdfDataUrl.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _openPdf(_selectedPdfDataUrl),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Preview'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryColor,
                              side: const BorderSide(color: _borderColor),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedForwardedTo,
                            decoration: _dialogInputDecoration('Forwarded To'),
                            items: _forwardedToOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option,
                                    child: Text(option),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedForwardedTo = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _receivedByController,
                            decoration: _dialogInputDecoration('Received By'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _commentController,
                      decoration: _dialogInputDecoration('Comment'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _actionTakenController,
                      decoration: _dialogInputDecoration('Action Taken'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _remarksController,
                      decoration: _dialogInputDecoration('Remarks'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            TextButton(
              onPressed: () {
                _clearForm();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await _addDocument();
                if (mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Document'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to delete this document record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteDocument(docId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  int _countThisMonth(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    return docs.where((doc) {
      final timestamp = _extractTimestamp(doc.data());
      if (timestamp == null) {
        return false;
      }
      final date = timestamp.toDate();
      return date.year == now.year && date.month == now.month;
    }).length;
  }

  int _countWithAttachments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final file = (doc.data()['scannedFileUrl'] ?? '').toString().trim();
      return file.isNotEmpty;
    }).length;
  }

  int _countWithoutActionTaken(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final action = (doc.data()['actionTaken'] ?? '').toString().trim();
      return action.isEmpty;
    }).length;
  }

  Widget _buildTopBanner(BuildContext context) {
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
                child: Image.asset(
                  'assets/images/company_logo.png',
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.account_balance, color: Colors.white),
                ),
              ),
              SizedBox(width: compact ? 0 : 20, height: compact ? 16 : 0),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Super Admin Document Control Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Monitor incoming records, validate routing details, and maintain a clean official registry for the General Services Office.',
                      style: TextStyle(
                        color: Color(0xFFF8EEDA),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
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
                  const _BannerPill(
                    icon: Icons.verified_user_outlined,
                    label: 'Authorized Oversight',
                  ),
                  _BannerPill(
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

  Widget _buildToolbar(BuildContext context) {
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
                width: compact ? constraints.maxWidth : 360,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search by date, office, control no., person, or remarks',
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
                child: DropdownButton<String>(
                  value: _exportFilter,
                  underline: const SizedBox.shrink(),
                  iconEnabledColor: _primaryColor,
                  dropdownColor: _cardBackground,
                  style: TextStyle(color: _primaryText),
                  items: ['Week', 'Month', 'Year', 'Custom Range']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    _setExportFilter(value!);
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickExportRange(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _effectiveBorder),
                  backgroundColor: _softBackground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_buildExportDateLabel()),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('documents')
                      .orderBy('controlNumber')
                      .get();
                  await _exportCSV(snapshot.docs);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export CSV'),
              ),
              ElevatedButton.icon(
                onPressed: _showAddDocumentDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Document'),
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
                        'Official Document Registry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryText,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Direct inline updates are available for document maintenance and routing control.',
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
                    '${docs.length} records',
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
                            Icons.folder_open_outlined,
                            size: 56,
                            color: _secondaryText,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No matching records found.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _primaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try refining the search or add a new document entry.',
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
                    child: SingleChildScrollView(
                      controller: _tableVerticalController,
                      padding: const EdgeInsets.all(16),
                      child: Scrollbar(
                        controller: _tableHorizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _tableHorizontalController,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1640),
                            child: DataTable(
                              columnSpacing: 16,
                              dataRowMinHeight: 74,
                              dataRowMaxHeight: 90,
                              headingRowHeight: 58,
                              dividerThickness: 0.6,
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
                                DataColumn(label: Text('RDS Code')),
                                DataColumn(label: Text('Control Number')),
                                DataColumn(label: Text('Office')),
                                DataColumn(label: Text('Particular')),
                                DataColumn(label: Text('Received Document')),
                                DataColumn(label: Text('Forwarded To')),
                                DataColumn(label: Text('Received By')),
                                DataColumn(label: Text('Comment')),
                                DataColumn(label: Text('Action Taken')),
                                DataColumn(label: Text('Document')),
                                DataColumn(label: Text('Remarks')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: docs.map((doc) {
                                final data = doc.data();
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'dateReceived',
                                        _formatDate(_extractTimestamp(data)),
                                        width: 140,
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'rdsCode',
                                        (data['rdsCode'] ?? '').toString(),
                                        width: 120,
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'controlNumber',
                                        (data['controlNumber'] ?? '')
                                            .toString(),
                                        width: 120,
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'office',
                                        (data['office'] ?? '').toString(),
                                        width: 150,
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'particular',
                                        (data['particular'] ?? '').toString(),
                                        width: 220,
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Builder(
                                          builder: (context) {
                                            final hasBeenDownloaded =
                                                data['hasBeenDownloaded'] ==
                                                true;
                                            final downloadLabelColor =
                                                hasBeenDownloaded
                                                ? Colors.blue.shade700
                                                : null;

                                            return (data['scannedFileUrl'] ??
                                                        '')
                                                    .toString()
                                                    .trim()
                                                    .isEmpty
                                                ? Text(
                                                    'No attachment',
                                                    style: TextStyle(
                                                      color: _secondaryText,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  )
                                                : TextButton.icon(
                                                    onPressed: () async =>
                                                        _downloadPdf(
                                                      doc.id,
                                                      (data['scannedFileUrl'] ??
                                                              '')
                                                          .toString(),
                                                      (data['pdfFileName'] ?? '')
                                                          .toString(),
                                                    ),
                                                    style:
                                                        TextButton.styleFrom(
                                                      foregroundColor:
                                                          downloadLabelColor,
                                                    ),
                                                    icon: Icon(
                                                      Icons
                                                          .download_for_offline_outlined,
                                                      size: 18,
                                                      color:
                                                          downloadLabelColor,
                                                    ),
                                                    label: SizedBox(
                                                      width: 120,
                                                      child: Text(
                                                        ((data['pdfFileName'] ??
                                                                        '')
                                                                    .toString()
                                                                    .trim())
                                                                .isNotEmpty
                                                            ? (data['pdfFileName'] ??
                                                                      '')
                                                                  .toString()
                                                            : 'Download PDF',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color:
                                                              downloadLabelColor,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                          },
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'forwardedTo',
                                        (data['forwardedTo'] ?? '').toString(),
                                        width: 140,
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'receivedBy',
                                        (data['receivedBy'] ?? '').toString(),
                                        width: 150,
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'comment',
                                        (data['comment'] ?? '').toString(),
                                        width: 180,
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'actionTaken',
                                        (data['actionTaken'] ?? '').toString(),
                                        width: 180,
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child:
                                            (data['adminDocumentUrl'] ?? '')
                                                .toString()
                                                .trim()
                                                .isEmpty
                                            ? Text(
                                                'No attachment',
                                                style: TextStyle(
                                                  color: _secondaryText,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              )
                                            : TextButton.icon(
                                                onPressed: () => _downloadPdf(
                                                  doc.id,
                                                  (data['adminDocumentUrl'] ??
                                                          '')
                                                      .toString(),
                                                  (data['adminDocumentFileName'] ??
                                                          '')
                                                      .toString(),
                                                ),
                                                icon: const Icon(
                                                  Icons
                                                      .download_for_offline_outlined,
                                                  size: 18,
                                                ),
                                                label: SizedBox(
                                                  width: 120,
                                                  child: Text(
                                                    ((data['adminDocumentFileName'] ??
                                                                    '')
                                                                .toString()
                                                                .trim())
                                                            .isNotEmpty
                                                        ? (data['adminDocumentFileName'] ??
                                                                  '')
                                                              .toString()
                                                        : 'Download File',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      _buildEditableCell(
                                        doc.id,
                                        'remarks',
                                        (data['remarks'] ?? '').toString(),
                                        width: 180,
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        onPressed: () =>
                                            _showDeleteDialog(doc.id),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete document',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                        ),
                      ),
                    );
                  }

                  final query = _searchText.trim().toLowerCase();
                  final allDocs = snapshot.data?.docs ?? [];
                  final docs = allDocs.where((doc) {
                    if (query.isEmpty) {
                      return true;
                    }

                    final data = doc.data();
                    final searchableValues = [
                      _formatDate(_extractTimestamp(data)),
                      (data['rdsCode'] ?? '').toString(),
                      (data['controlNumber'] ?? '').toString(),
                      (data['office'] ?? '').toString(),
                      (data['particular'] ?? '').toString(),
                      (data['pdfFileName'] ?? '').toString(),
                      (data['forwardedTo'] ?? '').toString(),
                      (data['receivedBy'] ?? '').toString(),
                      (data['comment'] ?? '').toString(),
                      (data['actionTaken'] ?? '').toString(),
                      (data['adminDocumentFileName'] ?? '').toString(),
                      (data['remarks'] ?? '').toString(),
                      (data['scannedFileUrl'] ?? '').toString(),
                    ].map((value) => value.toLowerCase());

                    return searchableValues.any(
                      (value) => value.contains(query),
                    );
                  }).toList();

                  final contentWidth = viewportConstraints.maxWidth - 48;
                  final statCardWidth = contentWidth >= 1360
                      ? (contentWidth - 16 * 3) / 4
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
                          _buildTopBanner(context),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: statCardWidth,
                                child: _DashboardStatCard(
                                  title: 'Total Registry',
                                  value: '${allDocs.length}',
                                  subtitle: 'All encoded documents',
                                  icon: Icons.inventory_2_outlined,
                                  highlightColor: _primaryColor,
                                  darkMode: _isDark,
                                ),
                              ),
                              SizedBox(
                                width: statCardWidth,
                                child: _DashboardStatCard(
                                  title: 'With Attachment',
                                  value: '${_countWithAttachments(allDocs)}',
                                  subtitle: 'PDF documents available',
                                  icon: Icons.attach_file_outlined,
                                  highlightColor: const Color(0xFF295C88),
                                  darkMode: _isDark,
                                ),
                              ),
                              SizedBox(
                                width: statCardWidth,
                                child: _DashboardStatCard(
                                  title: 'Action Taken',
                                  value:
                                      '${_countWithoutActionTaken(allDocs)}',
                                  subtitle: 'Registry without action taken',
                                  icon: Icons.pending_actions_outlined,
                                  highlightColor: _successColor,
                                  darkMode: _isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildToolbar(context),
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

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
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

class _BannerPill extends StatelessWidget {
  const _BannerPill({required this.icon, required this.label});

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
