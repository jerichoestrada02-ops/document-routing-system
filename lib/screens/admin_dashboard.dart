import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const String _allowedAttachmentTypes = '.pdf,.doc,.docx,.xls,.xlsx';
  static const Color _primaryColor = Color(0xFF7B1E1E);
  static const Color _accentColor = Color(0xFFD6B25E);
  static const Color _surfaceTint = Color(0xFFF4EFE8);
  static const Color _borderColor = Color(0xFFD8CEC0);
  static const Color _textMuted = Color(0xFF5F6B76);
  static const Color _successColor = Color(0xFF2E6A4F);

  // search & theme
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // form controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _controlNumberController =
      TextEditingController();
  final TextEditingController _officeController = TextEditingController();
  final TextEditingController _particularController = TextEditingController();
  final TextEditingController _receivedByController = TextEditingController();
  final TextEditingController _forwardedToController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();

  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;

  bool _darkMode = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    _dateController.dispose();
    _controlNumberController.dispose();
    _officeController.dispose();
    _particularController.dispose();
    _receivedByController.dispose();
    _forwardedToController.dispose();
    _commentController.dispose();
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    super.dispose();
  }

  Future<void> _generateControlNumber() async {
    try {
      final snapshot = await _firestore
          .collection('documents')
          .orderBy('controlNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastControlNumber =
            snapshot.docs.first.data()['controlNumber'] as String;
        final nextNumber = int.parse(lastControlNumber) + 1;
        _controlNumberController.text = nextNumber.toString().padLeft(3, '0');
      } else {
        _controlNumberController.text = '001';
      }
    } catch (e) {
      _controlNumberController.text = '001';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(timestamp.toDate());
    }
    return timestamp.toString();
  }

  Timestamp? _extractTimestamp(Map<String, dynamic> data) {
    final dynamic timestamp = data['dateReceived'] ?? data['date'];
    if (timestamp is Timestamp) {
      return timestamp;
    }
    return null;
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

  String? _nullableString(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _addDocument() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final selectedTimestamp = _selectedDate == null
            ? null
            : Timestamp.fromDate(_selectedDate!);
        await _firestore.collection('documents').add({
          'date': selectedTimestamp,
          'dateReceived': selectedTimestamp,
          'controlNumber': _nullableString(_controlNumberController.text),
          'office': _nullableString(_officeController.text),
          'particular': _nullableString(_particularController.text),
          'receivedBy': _nullableString(_receivedByController.text),
          'forwardedTo': _nullableString(_forwardedToController.text),
          'comment': _nullableString(_commentController.text),
          'isConfidential': false,
          'status': 'pending',
          'submittedBy': 'Admin',
          'submittedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        _clearForm();
        _generateControlNumber();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Document submitted successfully and is pending supervisor approval.',
              ),
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
  }

  void _clearForm() {
    _selectedDate = null;
    _dateController.clear();
    _officeController.clear();
    _particularController.clear();
    _receivedByController.clear();
    _forwardedToController.clear();
    _commentController.clear();
  }

  Future<void> _updateDocument(
    String docId,
    String field,
    String newValue,
  ) async {
    try {
      dynamic valueToUpdate = newValue;
      if (field == 'date' || field == 'dateReceived') {
        valueToUpdate = Timestamp.fromDate(DateTime.parse(newValue));
      }

      await _firestore.collection('documents').doc(docId).update({
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
      await _firestore.collection('documents').doc(docId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Document deleted!'),
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

  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _darkMode = !_darkMode;
    });
  }

  Future<void> _downloadAttachment(
    String docId,
    String fileUrl,
    String fileName,
  ) async {
    if (fileUrl.trim().isEmpty) {
      return;
    }

    try {
      await _firestore.collection('documents').doc(docId).update({
        'hasBeenDownloaded': true,
        'lastDownloadedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Keep download available even if tracking update fails.
    }

    final sanitizedFileName = fileName.trim().isNotEmpty
        ? fileName.trim()
        : 'document';

    final anchor = html.AnchorElement(href: fileUrl)
      ..setAttribute('download', sanitizedFileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _uploadAdminDocument(String docId) async {
    final uploadInput = html.FileUploadInputElement()
      ..accept = _allowedAttachmentTypes;
    uploadInput.click();

    await uploadInput.onChange.first;
    final file = uploadInput.files?.first;
    if (file == null) {
      return;
    }

    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;

    try {
      await _firestore.collection('documents').doc(docId).update({
        'adminDocumentUrl': reader.result?.toString() ?? '',
        'adminDocumentFileName': file.name,
        'adminDocumentUpdatedAt': FieldValue.serverTimestamp(),
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

  Future<Map<String, String>?> _pickRegistryAttachment() async {
    final uploadInput = html.FileUploadInputElement()
      ..accept = _allowedAttachmentTypes;
    uploadInput.click();

    await uploadInput.onChange.first;
    final file = uploadInput.files?.first;
    if (file == null) {
      return null;
    }

    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;

    return {
      'url': reader.result?.toString() ?? '',
      'name': file.name,
    };
  }

  Future<void> _showCellDialog({
    required String title,
    required String value,
    String? docId,
    String? field,
    bool editable = false,
  }) async {
    final controller = TextEditingController(text: value);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _isDark
            ? const Color(0xFF161E27)
            : const Color(0xFFFBF9F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 520,
          child: editable
              ? TextField(
                  controller: controller,
                  maxLines: 10,
                  minLines: 6,
                  decoration: _dialogInputDecoration(title),
                  style: TextStyle(color: _primaryText),
                )
              : SingleChildScrollView(
                  child: SelectableText(
                    value.trim().isEmpty ? 'No content available.' : value,
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close', style: TextStyle(color: _primaryColor)),
          ),
          if (editable && docId != null && field != null)
            ElevatedButton(
              onPressed: () async {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty || trimmed == value.trim()) {
                  Navigator.pop(dialogContext);
                  return;
                }

                await _updateDocument(docId, field, trimmed);
                if (mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.black87,
              ),
              child: const Text('Save'),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableCell(
    String docId,
    String field,
    String value, {
    double width = 110,
    String? label,
  }) {
    return _buildCellCard(
      value,
      width: width,
      onTap: () => _showCellDialog(
        title: label ?? field,
        value: value,
        docId: docId,
        field: field,
        editable: true,
      ),
      showEditIcon: true,
    );
  }

  Widget _buildReadOnlyCell(
    String value, {
    required String label,
    double width = 96,
  }) {
    return _buildCellCard(
      value,
      width: width,
      onTap: () => _showCellDialog(title: label, value: value),
    );
  }

  Widget _buildCellCard(
    String value, {
    required double width,
    required VoidCallback onTap,
    bool showEditIcon = false,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _softBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _effectiveBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayValue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  showEditIcon ? Icons.open_in_full : Icons.visibility_outlined,
                  size: 14,
                  color: _secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showUpdateRegistryDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final actionTakenController = TextEditingController(
      text: (data['actionTaken'] ?? '').toString(),
    );
    final fileLocationController = TextEditingController(
      text: _fileLocationFromData(data),
    );
    final remarksController = TextEditingController(
      text: (data['remarks'] ?? '').toString(),
    );
    String scannedFileUrl = (data['scannedFileUrl'] ?? '').toString();
    String pdfFileName = (data['pdfFileName'] ?? '').toString();
    String adminDocumentUrl = (data['adminDocumentUrl'] ?? '').toString();
    String adminDocumentFileName =
        (data['adminDocumentFileName'] ?? '').toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark
              ? const Color(0xFF161E27)
              : const Color(0xFFFBF9F5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Update Registry',
            style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: actionTakenController,
                    decoration: _dialogInputDecoration('Action Taken'),
                    maxLines: 3,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fileLocationController,
                    decoration: _dialogInputDecoration('File Location'),
                    maxLines: 3,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    decoration: _dialogInputDecoration('Remarks'),
                    maxLines: 3,
                    style: TextStyle(color: _primaryText),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final attachment =
                                await _pickRegistryAttachment();
                            if (attachment == null) return;
                            setDialogState(() {
                              scannedFileUrl = attachment['url'] ?? '';
                              pdfFileName = attachment['name'] ?? '';
                            });
                          },
                          icon: const Icon(Icons.attach_file_outlined),
                          label: Text(
                            pdfFileName.trim().isEmpty
                                ? 'Add Received Attachment'
                                : pdfFileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final attachment =
                                await _pickRegistryAttachment();
                            if (attachment == null) return;
                            setDialogState(() {
                              adminDocumentUrl = attachment['url'] ?? '';
                              adminDocumentFileName =
                                  attachment['name'] ?? '';
                            });
                          },
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(
                            adminDocumentFileName.trim().isEmpty
                                ? 'Add Document'
                                : adminDocumentFileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
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
                await _firestore.collection('documents').doc(docId).update({
                  'actionTaken': actionTakenController.text.trim(),
                  'fileLocation': fileLocationController.text.trim(),
                  'remarks': remarksController.text.trim(),
                  'scannedFileUrl': scannedFileUrl,
                  'pdfFileName': pdfFileName,
                  'adminDocumentUrl': adminDocumentUrl,
                  'adminDocumentFileName': adminDocumentFileName,
                  'registryUpdatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Registry updated successfully.'),
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
              label: const Text('Update Registry'),
            ),
          ],
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

  InputDecoration _dialogInputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFill,
      labelStyle: TextStyle(color: _secondaryText),
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

  void _showAddDocumentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark
            ? const Color(0xFF161E27)
            : const Color(0xFFFBF9F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surfaceTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.note_add_outlined, color: _primaryColor),
            ),
            const SizedBox(width: 12),
            Text(
              'Add New Document',
              style: TextStyle(
                color: _primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _dateController,
                            decoration: _dialogInputDecoration(
                              'Date',
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _controlNumberController,
                        decoration: _dialogInputDecoration('Control #'),
                        readOnly: true,
                        style: TextStyle(
                          color: _primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _officeController,
                  decoration: _dialogInputDecoration('Office'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _particularController,
                  decoration: _dialogInputDecoration('Particular/Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _receivedByController,
                        decoration: _dialogInputDecoration('Received By'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _forwardedToController,
                        decoration: _dialogInputDecoration('Forwarded To'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentController,
                  decoration: _dialogInputDecoration('Comment'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addDocument();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.black87,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete Document',
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete this document?',
          style: TextStyle(color: _secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteDocument(docId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
                stream: _firestore
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
                        ),
                      ),
                    );
                  }

                  final query = _searchText.trim().toLowerCase();
                  final allDocs = (snapshot.data?.docs ?? []).where((doc) {
                    final data = doc.data();
                    final status = (data['status'] ?? 'approved')
                        .toString()
                        .trim()
                        .toLowerCase();
                    final isConfidential =
                        data['isConfidential'] == true ||
                        data['confidential'] == true;
                    return status == 'approved' && !isConfidential;
                  }).toList();
                  final docs = allDocs.where((doc) {
                    if (query.isEmpty) return true;
                    final data = doc.data();
                    final searchableValues = [
                      _formatDate(_extractTimestamp(data)),
                      _filingCodeFromData(data),
                      _retentionPeriodFromData(data),
                      _dispositionDateFromData(data),
                      (data['controlNumber'] ?? '').toString(),
                      (data['office'] ?? '').toString(),
                      (data['particular'] ?? '').toString(),
                      (data['pdfFileName'] ?? '').toString(),
                      (data['receivedBy'] ?? '').toString(),
                      (data['forwardedTo'] ?? '').toString(),
                      (data['comment'] ?? '').toString(),
                      (data['actionTaken'] ?? '').toString(),
                      _fileLocationFromData(data),
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
                                  value: '${_countWithoutActionTaken(allDocs)}',
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

  Widget _buildTopBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [_primaryColor, Color(0xFF5D1717)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x221E1E1E),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Monitor routed records, update action taken, and maintain incoming document details in one place.',
                  style: TextStyle(
                    color: Color(0xFFF8EEDA),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _BannerPill(
                icon: Icons.admin_panel_settings_outlined,
                label: 'GSO Admin',
              ),
              _BannerPill(
                icon: Icons.monitor_heart_outlined,
                label: _isDark ? 'Dark Mode' : 'Light Mode',
              ),
              IconButton(
                onPressed: _toggleTheme,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  foregroundColor: const Color(0xFFF8EEDA),
                ),
                icon: Icon(
                  _isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                tooltip: 'Toggle theme',
              ),
              IconButton(
                onPressed: _logout,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  foregroundColor: const Color(0xFFF8EEDA),
                ),
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
              ),
            ],
          ),
        ],
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
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Search by date, office, control no., person, or action',
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
        ],
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
                        'Document Action Registry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Review incoming records and update action taken directly from the table.',
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
                  child: const Text(
                    'Admin View',
                    style: TextStyle(
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
                      child: Text(
                        'No matching records found.',
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Scrollbar(
                      controller: _tableVerticalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: SingleChildScrollView(
                        controller: _tableVerticalController,
                        child: SingleChildScrollView(
                          controller: _tableHorizontalController,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 2200),
                              child: DataTable(
                                dataRowMinHeight: 64,
                                dataRowMaxHeight: 72,
                                columnSpacing: 18,
                                horizontalMargin: 16,
                                headingRowHeight: 52,
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
                                  DataColumn(label: Text('Filing Code')),
                                  DataColumn(label: Text('Retention Period')),
                                  DataColumn(label: Text('File Location')),
                                  DataColumn(label: Text('Disposition Date')),
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
                                        _buildReadOnlyCell(
                                          _formatDate(_extractTimestamp(data)),
                                          label: 'Date Received',
                                          width: 126,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          _filingCodeFromData(data),
                                          label: 'Filing Code',
                                          width: 150,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          _retentionPeriodFromData(data),
                                          label: 'Retention Period',
                                          width: 150,
                                        ),
                                      ),
                                      DataCell(
                                        _buildEditableCell(
                                          doc.id,
                                          'fileLocation',
                                          _fileLocationFromData(data),
                                          label: 'File Location',
                                          width: 172,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          _dispositionDateFromData(data),
                                          label: 'Disposition Date',
                                          width: 148,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          (data['controlNumber'] ?? '')
                                              .toString(),
                                          label: 'Control Number',
                                          width: 118,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          (data['office'] ?? '').toString(),
                                          label: 'Office',
                                          width: 144,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          (data['particular'] ?? '').toString(),
                                          label: 'Particular',
                                          width: 196,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          ((data['pdfFileName'] ?? '')
                                                      .toString()
                                                      .trim())
                                                  .isNotEmpty
                                              ? (data['pdfFileName'] ?? '')
                                                    .toString()
                                              : (data['scannedFileUrl'] ?? '')
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty
                                              ? 'PDF attached'
                                              : 'No attachment',
                                          label: 'Received Document',
                                          width: 156,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          (data['forwardedTo'] ?? '').toString(),
                                          label: 'Forwarded To',
                                          width: 138,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          (data['receivedBy'] ?? '').toString(),
                                          label: 'Received By',
                                          width: 144,
                                        ),
                                      ),
                                      DataCell(
                                        _buildReadOnlyCell(
                                          (data['comment'] ?? '').toString(),
                                          label: 'Comment',
                                          width: 164,
                                        ),
                                      ),
                                      DataCell(
                                        _buildEditableCell(
                                          doc.id,
                                          'actionTaken',
                                          (data['actionTaken'] ?? '')
                                              .toString(),
                                          label: 'Action Taken',
                                          width: 164,
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 156,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 0,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    32,
                                                  ),
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                onPressed: () =>
                                                    _uploadAdminDocument(doc.id),
                                                icon: const Icon(
                                                  Icons.upload_file_outlined,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  ((data['adminDocumentFileName'] ??
                                                                  '')
                                                              .toString()
                                                              .trim())
                                                          .isNotEmpty
                                                      ? (data['adminDocumentFileName'] ??
                                                                '')
                                                            .toString()
                                                      : 'Upload Attachment',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              if ((data['adminDocumentUrl'] ??
                                                      '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 0,
                                                        ),
                                                    minimumSize: const Size(
                                                      0,
                                                      30,
                                                    ),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  onPressed: () =>
                                                      _downloadAttachment(
                                                        doc.id,
                                                        (data['adminDocumentUrl'] ??
                                                                '')
                                                            .toString(),
                                                        (data['adminDocumentFileName'] ??
                                                                '')
                                                            .toString(),
                                                      ),
                                                  child: const Text(
                                                    'Download',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        _buildEditableCell(
                                          doc.id,
                                          'remarks',
                                          (data['remarks'] ?? '').toString(),
                                          label: 'Remarks',
                                          width: 164,
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 74,
                                          child: Center(
                                            child: IconButton(
                                              onPressed: () =>
                                                  _showUpdateRegistryDialog(
                                                doc.id,
                                                data,
                                              ),
                                              icon: const Icon(
                                                Icons.edit_note_outlined,
                                              ),
                                              iconSize: 22,
                                              splashRadius: 20,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              tooltip: 'Update registry',
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
                      ),
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
