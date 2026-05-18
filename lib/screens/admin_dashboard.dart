import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/debounce_service.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  final DebounceService _searchDebounce = DebounceService();
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
    _searchFocusNode.dispose();
    _searchDebounce.dispose();
    _dateController.dispose();
    _controlNumberController.dispose();
    _officeController.dispose();
    _particularController.dispose();
    _receivedByController.dispose();
    _forwardedToController.dispose();
    _commentController.dispose();
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

  String _normalizedDuplicateValue(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Future<bool> _documentAlreadyExists() async {
    final controlNumber = _controlNumberController.text.trim();
    final office = _normalizedDuplicateValue(_officeController.text);
    final particular = _normalizedDuplicateValue(_particularController.text);
    final selectedDate = _selectedDate;

    if (controlNumber.isNotEmpty) {
      final controlSnapshot = await _firestore
          .collection('documents')
          .where('controlNumber', isEqualTo: controlNumber)
          .limit(1)
          .get();

      if (controlSnapshot.docs.isNotEmpty) {
        return true;
      }
    }

    if (office.isEmpty || particular.isEmpty || selectedDate == null) {
      return false;
    }

    final dateSnapshot = await _firestore
        .collection('documents')
        .where('date', isEqualTo: Timestamp.fromDate(selectedDate))
        .limit(50)
        .get();

    return dateSnapshot.docs.any((doc) {
      final data = doc.data();
      final existingOffice = _normalizedDuplicateValue(
        (data['office'] ?? '').toString(),
      );
      final existingParticular = _normalizedDuplicateValue(
        (data['particular'] ?? '').toString(),
      );

      return existingOffice == office && existingParticular == particular;
    });
  }

  void _showDuplicateEntryWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'This document entry already exists. Please review the existing record before adding a duplicate.',
        ),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  void _onSearchChanged(String value) {
    final shouldRestoreFocus = _searchFocusNode.hasFocus;
    _searchDebounce.run(() {
      if (!mounted) {
        return;
      }
      if (_searchText == value) {
        return;
      }
      setState(() {
        _searchText = value;
      });
      if (shouldRestoreFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _searchFocusNode.requestFocus();
          }
        });
      }
    });
  }

  Future<bool> _addDocument() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedDate == null) {
      return false;
    }

    try {
      if (await _documentAlreadyExists()) {
        if (mounted) {
          _showDuplicateEntryWarning();
        }
        return false;
      }

      await _firestore.collection('documents').add({
        'date': Timestamp.fromDate(_selectedDate!),
        'controlNumber': _controlNumberController.text,
        'office': _officeController.text,
        'particular': _particularController.text,
        'receivedBy': _receivedByController.text,
        'forwardedTo': _forwardedToController.text,
        'comment': _commentController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      _generateControlNumber();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document added successfully!'),
            backgroundColor: _successColor,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
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

  Widget _buildDownloadCell({
    required String docId,
    required String fileUrl,
    required String fileName,
    required String emptyLabel,
    double width = 132,
    bool hasBeenDownloaded = false,
  }) {
    final hasFile = fileUrl.trim().isNotEmpty;
    final displayName = fileName.trim().isNotEmpty
        ? fileName.trim()
        : hasFile
        ? 'Download File'
        : emptyLabel;
    final downloadColor = hasBeenDownloaded ? Colors.blue.shade700 : null;

    if (!hasFile) {
      return _buildReadOnlyCell(emptyLabel, label: emptyLabel, width: width);
    }

    return SizedBox(
      width: width,
      child: TextButton.icon(
        onPressed: () => _downloadAttachment(docId, fileUrl, fileName),
        style: TextButton.styleFrom(
          foregroundColor: downloadColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          alignment: Alignment.centerLeft,
        ),
        icon: Icon(
          Icons.download_for_offline_outlined,
          size: 18,
          color: downloadColor,
        ),
        label: SizedBox(
          width: width - 44,
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: downloadColor, fontSize: 12),
          ),
        ),
      ),
    );
  }

  String _fileLocationFromData(Map<String, dynamic> data) {
    return (data['fileLocation'] ??
            data['fileLocationAfterRetention'] ??
            data['retentionFileLocation'] ??
            data['fileLocationAfterRetentionPeriod'] ??
            '')
        .toString();
  }

  bool _isConfidentialFromData(Map<String, dynamic> data) {
    return data['isConfidential'] == true ||
        data['confidential'] == true ||
        (data['access']?.toString().toLowerCase() == 'confidential');
  }

  String _statusFromData(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().trim();
    return status.isEmpty ? 'pending' : status.toLowerCase();
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
                            validator: (value) =>
                                value!.isEmpty ? 'Please select a date' : null,
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
                  validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _particularController,
                  decoration: _dialogInputDecoration('Particular/Description'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _receivedByController,
                        decoration: _dialogInputDecoration('Received By'),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
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
            onPressed: () async {
              final saved = await _addDocument();
              if (saved && context.mounted) {
                Navigator.pop(context);
              }
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
                  final allDocs = (snapshot.data?.docs ?? [])
                      .where((doc) {
                        final data = doc.data();
                        return !_isConfidentialFromData(data) &&
                            _statusFromData(data) == 'approved';
                      })
                      .toList();
                  final docs = allDocs.where((doc) {
                    if (query.isEmpty) return true;
                    final data = doc.data();
                    final searchableValues = [
                      _formatDate(_extractTimestamp(data)),
                      (data['rdsCode'] ?? '').toString(),
                      (data['controlNumber'] ?? '').toString(),
                      (data['office'] ?? '').toString(),
                      (data['particular'] ?? '').toString(),
                      (data['pdfFileName'] ?? '').toString(),
                      (data['receivedBy'] ?? '').toString(),
                      (data['forwardedTo'] ?? '').toString(),
                      (data['comment'] ?? '').toString(),
                      (data['actionTaken'] ?? '').toString(),
                      (data['fileLocation'] ??
                              data['fileLocationAfterRetention'] ??
                              data['retentionFileLocation'] ??
                              data['fileLocationAfterRetentionPeriod'] ??
                              '')
                          .toString(),
                      (data['adminDocumentFileName'] ?? '').toString(),
                      (data['remarks'] ?? '').toString(),
                      (data['scannedFileUrl'] ?? '').toString(),
                    ].map((value) => value.toLowerCase());
                    return searchableValues.any(
                      (value) => value.contains(query),
                    );
                  }).toList();

                  final panelHeight = math.max(
                    760.0,
                    viewportConstraints.maxHeight - 120,
                  );
                  final withAttachments = _countWithAttachments(allDocs);
                  final withoutActionTaken = _countWithoutActionTaken(allDocs);

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
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 1200;
                              final statsPanel = _buildStatsPanel(
                                totalDocuments: allDocs.length,
                                withAttachments: withAttachments,
                                withoutActionTaken: withoutActionTaken,
                              );

                              return isWide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 360,
                                          child: statsPanel,
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: SizedBox(
                                            height: panelHeight,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _buildToolbar(context),
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
                                        _buildToolbar(context),
                                        const SizedBox(height: 20),
                                        statsPanel,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          const bannerText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
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
                child: Image.asset(
                  'assets/images/company_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
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
                  const _BannerPill(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'GSO Admin',
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
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
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
              onChanged: _onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel({
    required int totalDocuments,
    required int withAttachments,
    required int withoutActionTaken,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Admin Overview',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _DashboardStatCard(
          title: 'Total Registry',
          value: '$totalDocuments',
          subtitle: 'All encoded documents',
          icon: Icons.inventory_2_outlined,
          highlightColor: _primaryColor,
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
        const SizedBox(height: 16),
        _DashboardStatCard(
          title: 'With Attachment',
          value: '$withAttachments',
          subtitle: 'PDF documents available',
          icon: Icons.attach_file_outlined,
          highlightColor: const Color(0xFF5A7D9A),
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
        const SizedBox(height: 16),
        _DashboardStatCard(
          title: 'Without Action Taken',
          value: '$withoutActionTaken',
          subtitle: 'Registry without action taken',
          icon: Icons.pending_actions_outlined,
          highlightColor: _successColor,
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
    int currentIndex = initialIndex;

    Widget infoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _effectiveBorder),
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
                  fontWeight: FontWeight.w800,
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

    Widget attachmentRow({
      required String docId,
      required String label,
      required String fileName,
      required String fileUrl,
      VoidCallback? uploadAction,
    }) {
      final hasFile = fileUrl.trim().isNotEmpty;
      final displayName = fileName.trim().isNotEmpty
          ? fileName.trim()
          : hasFile
          ? 'Download File'
          : 'No attachment';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 132,
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
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _softBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _effectiveBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasFile
                          ? Icons.download_for_offline_outlined
                          : Icons.insert_drive_file_outlined,
                      color: hasFile ? _primaryColor : _secondaryText,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasFile ? _primaryText : _secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (uploadAction != null)
                      IconButton(
                        onPressed: uploadAction,
                        icon: const Icon(Icons.upload_file_outlined),
                        color: _primaryColor,
                        tooltip: 'Upload',
                      ),
                    IconButton(
                      onPressed: hasFile
                          ? () => _downloadAttachment(docId, fileUrl, fileName)
                          : null,
                      icon: const Icon(Icons.download_outlined),
                      color: _primaryColor,
                      tooltip: 'Download',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentDoc = docs[currentIndex];
          final data = currentDoc.data();
          final controlNumber = (data['controlNumber'] ?? '').toString();

          return AlertDialog(
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
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'Control Number: ${controlNumber.trim().isEmpty ? '-' : controlNumber}',
                        style: TextStyle(color: _secondaryText, fontSize: 14),
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
              width: 920,
              height: 600,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 720;
                  final coreInfo = infoCard('Core Info', [
                    infoRow('Date Received', _formatDate(_extractTimestamp(data))),
                    infoRow('Control Number', controlNumber),
                    infoRow('Office', (data['office'] ?? '').toString()),
                    infoRow('Particular', (data['particular'] ?? '').toString()),
                    infoRow('RDS Code', (data['rdsCode'] ?? '').toString()),
                  ]);
                  final routing = infoCard('Routing & History', [
                    infoRow('Forwarded To', (data['forwardedTo'] ?? '').toString()),
                    infoRow('Received By', (data['receivedBy'] ?? '').toString()),
                    infoRow('Comment', (data['comment'] ?? '').toString()),
                    infoRow('Action Taken', (data['actionTaken'] ?? '').toString()),
                    infoRow('File Location', _fileLocationFromData(data)),
                    infoRow('Remarks', (data['remarks'] ?? '').toString()),
                  ]);
                  final attachments = infoCard('Attachments', [
                    attachmentRow(
                      docId: currentDoc.id,
                      label: 'Received Document',
                      fileName: (data['pdfFileName'] ?? '').toString(),
                      fileUrl: (data['scannedFileUrl'] ?? '').toString(),
                    ),
                    attachmentRow(
                      docId: currentDoc.id,
                      label: 'Document',
                      fileName: (data['adminDocumentFileName'] ?? '').toString(),
                      fileUrl: (data['adminDocumentUrl'] ?? '').toString(),
                      uploadAction: () => _uploadAdminDocument(currentDoc.id),
                    ),
                  ]);

                  return SingleChildScrollView(
                    child: isCompact
                        ? Column(children: [coreInfo, routing, attachments])
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(children: [coreInfo, attachments])),
                              const SizedBox(width: 16),
                              Expanded(child: routing),
                            ],
                          ),
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
                            ? () => setDialogState(() => currentIndex -= 1)
                            : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: currentIndex < docs.length - 1
                            ? () => setDialogState(() => currentIndex += 1)
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showCellDialog(
                          title: 'Action Taken',
                          value: (data['actionTaken'] ?? '').toString(),
                          docId: currentDoc.id,
                          field: 'actionTaken',
                          editable: true,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _successColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Action Taken'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showCellDialog(
                          title: 'Remarks',
                          value: (data['remarks'] ?? '').toString(),
                          docId: currentDoc.id,
                          field: 'remarks',
                          editable: true,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.black87,
                        ),
                        icon: const Icon(Icons.comment_outlined),
                        label: const Text('Remarks'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showCellDialog(
                          title: 'File Location',
                          value: _fileLocationFromData(data),
                          docId: currentDoc.id,
                          field: 'fileLocation',
                          editable: true,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A7D9A),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('File Location'),
                      ),
                    ],
                  ),
                ],
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final tableMinWidth = constraints.maxWidth > 1000
                          ? constraints.maxWidth
                          : 1000.0;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: tableMinWidth),
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
                                final isConfidential =
                                    _isConfidentialFromData(data);
                                final accessLabel = isConfidential
                                    ? 'Confidential'
                                    : 'Open';

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
                                      _buildReadOnlyCell(
                                        (data['controlNumber'] ?? '').toString(),
                                        label: 'Control Number',
                                        width: 140,
                                      ),
                                    ),
                                    DataCell(
                                      _buildReadOnlyCell(
                                        _formatDate(_extractTimestamp(data)),
                                        label: 'Date Received',
                                        width: 120,
                                      ),
                                    ),
                                    DataCell(
                                      _buildReadOnlyCell(
                                        (data['office'] ?? '').toString(),
                                        label: 'Office',
                                        width: 140,
                                      ),
                                    ),
                                    DataCell(
                                      _buildReadOnlyCell(
                                        (data['particular'] ?? '').toString(),
                                        label: 'Particular',
                                        width: 220,
                                      ),
                                    ),
                                    DataCell(
                                      _buildReadOnlyCell(
                                        (data['comment'] ?? '').toString(),
                                        label: 'Comment',
                                        width: 220,
                                      ),
                                    ),
                                    DataCell(
                                      _buildReadOnlyCell(
                                        accessLabel,
                                        label: 'Access',
                                        width: 110,
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 130,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _showViewMoreDialog(docs, index),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF5A7D9A),
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



