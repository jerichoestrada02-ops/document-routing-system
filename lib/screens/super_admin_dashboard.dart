import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/debounce_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  static const String _allowedAttachmentTypes = '.pdf,.doc,.docx,.xls,.xlsx';
  static const List<String> _forwardedToOptions = [
    'Admin',
    'Procurement',
    'Solid Waste',
    'Asset',
    'Records',
  ];
  static final List<String> _retentionPeriodOptions = [
    ...List<String>.generate(
      20,
      (index) => '${index + 1} year${index == 0 ? '' : 's'}',
    ),
    'Permanent',
  ];

  static const Color _primaryColor = Color(0xFF7B1E1E);
  static const Color _accentColor = Color(0xFFD6B25E);
  static const Color _surfaceTint = Color(0xFFF4EFE8);
  static const Color _borderColor = Color(0xFFD8CEC0);
  static const Color _textMuted = Color(0xFF5F6B76);
  static const Color _successColor = Color(0xFF2E6A4F);
  static const Color _warningColor = Color(0xFFC67A12);
  static const Color _dangerColor = Color(0xFFB42318);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final DebounceService _searchDebounce = DebounceService();
  final TextEditingController _dateReceivedController = TextEditingController();
  final TextEditingController _filingCodeController = TextEditingController();
  final TextEditingController _controlNumberController =
      TextEditingController();
  final TextEditingController _officeController = TextEditingController();
  final TextEditingController _particularController = TextEditingController();
  final TextEditingController _pdfNameController = TextEditingController();
  final TextEditingController _receivedByController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _actionTakenController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _fileLocationAfterRetentionController =
      TextEditingController();
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();

  final _formKey = GlobalKey<FormState>();

  String _searchText = '';
  String _exportFilter = 'All';
  String? _selectedForwardedTo;
  String? _selectedFilingCode;
  String? _selectedFilingSubCategory;
  String? _selectedRetentionPeriod;
  String _selectedPdfDataUrl = '';
  List<String> _filingCodeOptions = [];
  DateTime? _selectedDateReceived;
  bool _isConfidential = false;
  DateTimeRange _selectedExportRange = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
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
    _searchFocusNode.dispose();
    _searchDebounce.dispose();
    _dateReceivedController.dispose();
    _filingCodeController.dispose();
    _controlNumberController.dispose();
    _officeController.dispose();
    _particularController.dispose();
    _pdfNameController.dispose();
    _receivedByController.dispose();
    _commentController.dispose();
    _actionTakenController.dispose();
    _remarksController.dispose();
    _fileLocationAfterRetentionController.dispose();
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

  String _filingSubCategoryFromData(Map<String, dynamic> data) {
    final subCategory = (data['filingSubCategory'] ?? data['subCategory'] ?? '')
        .toString()
        .trim();
    if (subCategory.isNotEmpty) {
      return subCategory;
    }

    final legacyCode = (data['rdsCode'] ?? '').toString().trim();
    if (!legacyCode.contains(' - ')) {
      return '';
    }

    return legacyCode.split(' - ').skip(1).join(' - ').trim();
  }

  String _filingCodeWithSubCategory(
    Map<String, dynamic> data, {
    String separator = ' - ',
  }) {
    final filingCode = _filingCodeFromData(data);
    final subCategory = _filingSubCategoryFromData(data);
    return [
      filingCode,
      subCategory,
    ].where((value) => value.trim().isNotEmpty).join(separator);
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

  bool _isConfidentialFromData(Map<String, dynamic> data) {
    return data['isConfidential'] == true || data['confidential'] == true;
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

  String? _nullableString(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizedDuplicateValue(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Future<bool> _documentAlreadyExists() async {
    final controlNumber = _controlNumberController.text.trim();
    final office = _normalizedDuplicateValue(_officeController.text);
    final particular = _normalizedDuplicateValue(_particularController.text);
    final selectedDate = _selectedDateReceived;

    if (controlNumber.isNotEmpty) {
      final controlSnapshot = await FirebaseFirestore.instance
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

    final receivedDateSnapshot = await FirebaseFirestore.instance
        .collection('documents')
        .where('dateReceived', isEqualTo: Timestamp.fromDate(selectedDate))
        .limit(50)
        .get();
    final legacyDateSnapshot = await FirebaseFirestore.instance
        .collection('documents')
        .where('date', isEqualTo: Timestamp.fromDate(selectedDate))
        .limit(50)
        .get();
    final candidateDocs = [
      ...receivedDateSnapshot.docs,
      ...legacyDateSnapshot.docs,
    ];

    return candidateDocs.any((doc) {
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return false;
    }

    final filingCode = _selectedFilingCode?.trim() ?? '';
    final filingSubCategory = _selectedFilingSubCategory?.trim() ?? '';
    final retentionPeriod = _selectedRetentionPeriod?.trim() ?? '';
    final dispositionDate = _calculateDispositionDate(
      _selectedDateReceived,
      retentionPeriod,
    );
    final receivedTimestamp = _selectedDateReceived == null
        ? null
        : Timestamp.fromDate(_selectedDateReceived!);

    try {
      if (await _documentAlreadyExists()) {
        if (mounted) {
          _showDuplicateEntryWarning();
        }
        return false;
      }

      await FirebaseFirestore.instance.collection('documents').add({
        'dateReceived': receivedTimestamp,
        'date': receivedTimestamp,
        'filingCode': _nullableString(filingCode),
        'filingSubCategory': _nullableString(filingSubCategory),
        'retentionPeriod': _nullableString(retentionPeriod),
        'dispositionDate': retentionPeriod.toLowerCase() == 'permanent'
            ? 'Permanent'
            : dispositionDate != null
            ? Timestamp.fromDate(dispositionDate)
            : null,
        'controlNumber': _nullableString(_controlNumberController.text),
        'office': _nullableString(_officeController.text),
        'particular': _nullableString(_particularController.text),
        'scannedFileUrl': _nullableString(_selectedPdfDataUrl),
        'pdfFileName': _nullableString(_pdfNameController.text),
        'forwardedTo': _nullableString(_selectedForwardedTo ?? ''),
        'receivedBy': _nullableString(_receivedByController.text),
        'comment': _nullableString(_commentController.text),
        'actionTaken': _nullableString(_actionTakenController.text),
        'remarks': _nullableString(_remarksController.text),
        'fileLocation': _nullableString(
          _fileLocationAfterRetentionController.text,
        ),
        'adminDocumentUrl': null,
        'adminDocumentFileName': null,
        'hasBeenDownloaded': false,
        'isConfidential': _isConfidential,
        'status': 'pending',
        'submittedBy': 'Super Admin',
        'submittedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _clearForm();
      await _generateControlNumber();

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
    setState(() {
      _selectedDateReceived = null;
      _selectedForwardedTo = null;
      _selectedFilingCode = null;
      _selectedFilingSubCategory = null;
      _selectedRetentionPeriod = null;
      _filingCodeOptions = [];
      _isConfidential = false;
    });
    _dateReceivedController.clear();
    _filingCodeController.clear();
    _officeController.clear();
    _particularController.clear();
    _pdfNameController.clear();
    _receivedByController.clear();
    _commentController.clear();
    _actionTakenController.clear();
    _remarksController.clear();
    _fileLocationAfterRetentionController.clear();
    _selectedPdfDataUrl = '';
  }

  List<String> _buildFilingCodeOptions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final options = <String>{};

    for (final doc in docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }

      options.add(name);
    }

    return options.toList()..sort();
  }

  List<String> _buildFilingSubCategoryOptions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? filingCode,
  ) {
    final normalizedFilingCode = filingCode?.trim();
    if (normalizedFilingCode == null || normalizedFilingCode.isEmpty) {
      return [];
    }

    final options = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().trim();
      if (name != normalizedFilingCode) {
        continue;
      }

      final subcategories = data['subcategories'];
      if (subcategories is Iterable) {
        for (final subcategory in subcategories) {
          final value = subcategory.toString().trim();
          if (value.isNotEmpty) {
            options.add(value);
          }
        }
      }
    }

    return options.toList()..sort();
  }

  void _syncFilingCodeSelectionFromOptions(List<String> options) {
    _filingCodeOptions = options;

    if (_selectedFilingCode != null &&
        !_filingCodeOptions.contains(_selectedFilingCode)) {
      _selectedFilingCode = null;
      _selectedFilingSubCategory = null;
    }

    _filingCodeController.text = _selectedFilingCode ?? '';
  }

  void _syncFilingSubCategorySelectionFromOptions(List<String> options) {
    if (_selectedFilingSubCategory != null &&
        !options.contains(_selectedFilingSubCategory)) {
      _selectedFilingSubCategory = null;
    }
  }

  Future<void> _showAddRdsMainDialog(
    void Function(VoidCallback fn) setDialogState,
  ) async {
    final mainController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _isDark
            ? const Color(0xFF161E27)
            : const Color(0xFFFBF9F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Filing Code',
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: mainController,
                  decoration: _dialogInputDecoration('Filing Code'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
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
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              final mainName = mainController.text.trim();

              try {
                final existing = await FirebaseFirestore.instance
                    .collection('rds_options')
                    .where('name', isEqualTo: mainName)
                    .limit(1)
                    .get();

                if (existing.docs.isEmpty) {
                  await FirebaseFirestore.instance
                      .collection('rds_options')
                      .add({'name': mainName, 'subcategories': []});
                }

                setDialogState(() {
                  _selectedFilingCode = mainName;
                  _filingCodeController.text = mainName;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filing code added successfully.'),
                      backgroundColor: _successColor,
                    ),
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    mainController.dispose();
  }

  Future<void> _showAddRdsSubCategoryDialog(
    void Function(VoidCallback fn) setDialogState,
  ) async {
    final filingCode = _selectedFilingCode?.trim();
    if (filingCode == null || filingCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a filing code before adding a sub category.'),
          backgroundColor: _warningColor,
        ),
      );
      return;
    }

    final subCategoryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _isDark
            ? const Color(0xFF161E27)
            : const Color(0xFFFBF9F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Sub Category',
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: subCategoryController,
              decoration: _dialogInputDecoration(
                'Sub Category',
                hintText: filingCode,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              final subCategory = subCategoryController.text.trim();

              try {
                final existing = await FirebaseFirestore.instance
                    .collection('rds_options')
                    .where('name', isEqualTo: filingCode)
                    .limit(1)
                    .get();

                if (existing.docs.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('rds_options')
                      .doc(existing.docs.first.id)
                      .update({
                        'subcategories': FieldValue.arrayUnion([subCategory]),
                      });
                }

                setDialogState(() {
                  _selectedFilingSubCategory = subCategory;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sub category added successfully.'),
                      backgroundColor: _successColor,
                    ),
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    subCategoryController.dispose();
  }

  Future<void> _confirmDeleteFilingCode(
    BuildContext dialogContext,
    String filingCode,
    void Function(VoidCallback fn) setDialogState,
  ) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (confirmContext) => AlertDialog(
            backgroundColor: _isDark
                ? const Color(0xFF161E27)
                : const Color(0xFFFBF9F5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Delete Filing Code',
              style:
                  TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Delete "$filingCode" and all of its sub categories? This cannot be undone.',
              style: TextStyle(color: _secondaryText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(confirmContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dangerColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('rds_options')
          .where('name', isEqualTo: filingCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Filing code not found.'),
              backgroundColor: _warningColor,
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('rds_options')
          .doc(query.docs.first.id)
          .delete();

      setDialogState(() {
        if (_selectedFilingCode == filingCode) {
          _selectedFilingCode = null;
          _selectedFilingSubCategory = null;
          _filingCodeController.clear();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filing code deleted successfully.'),
            backgroundColor: _successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting filing code: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteFilingSubCategory(
    BuildContext dialogContext,
    String filingCode,
    String subCategory,
    void Function(VoidCallback fn) setDialogState,
  ) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (confirmContext) => AlertDialog(
            backgroundColor: _isDark
                ? const Color(0xFF161E27)
                : const Color(0xFFFBF9F5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Delete Sub Category',
              style:
                  TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Remove "$subCategory" from "$filingCode"? This will delete the sub category only.',
              style: TextStyle(color: _secondaryText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(confirmContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dangerColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('rds_options')
          .where('name', isEqualTo: filingCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Filing code not found.'),
              backgroundColor: _warningColor,
            ),
          );
        }
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('rds_options')
          .doc(query.docs.first.id);

      await docRef.update({
        'subcategories': FieldValue.arrayRemove([subCategory]),
      });

      setDialogState(() {
        if (_selectedFilingSubCategory == subCategory) {
          _selectedFilingSubCategory = null;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sub category deleted successfully.'),
            backgroundColor: _successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting sub category: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildRdsCodeDropdowns(void Function(VoidCallback fn) setDialogState) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('rds_options').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final options = _buildFilingCodeOptions(docs);
        final subCategoryOptions = _buildFilingSubCategoryOptions(
          docs,
          _selectedFilingCode,
        );
        _syncFilingCodeSelectionFromOptions(options);
        _syncFilingSubCategorySelectionFromOptions(subCategoryOptions);

        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _filingCodeOptions.contains(_selectedFilingCode)
                        ? _selectedFilingCode
                        : null,
                    decoration: _dialogInputDecoration('Filing Code'),
                    items: _filingCodeOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(
                              option,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isLoading || _filingCodeOptions.isEmpty
                        ? null
                        : (value) {
                            setDialogState(() {
                              _selectedFilingCode = value;
                              _selectedFilingSubCategory = null;
                              _filingCodeController.text = value ?? '';
                            });
                          },
                    hint: Text(
                      isLoading
                          ? 'Loading filing codes...'
                          : 'Select filing code',
                    ),
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
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value:
                        subCategoryOptions.contains(_selectedFilingSubCategory)
                        ? _selectedFilingSubCategory
                        : null,
                    decoration: _dialogInputDecoration('Sub Category'),
                    items: subCategoryOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(
                              option,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isLoading || subCategoryOptions.isEmpty
                        ? null
                        : (value) {
                            setDialogState(() {
                              _selectedFilingSubCategory = value;
                            });
                          },
                    hint: Text(
                      _selectedFilingCode == null
                          ? 'Select filing code first'
                          : isLoading
                          ? 'Loading sub categories...'
                          : 'Select sub category',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value:
                        _retentionPeriodOptions.contains(
                          _selectedRetentionPeriod,
                        )
                        ? _selectedRetentionPeriod
                        : null,
                    decoration: _dialogInputDecoration('Retention Period'),
                    items: _retentionPeriodOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(
                              option,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedRetentionPeriod = value;
                      });
                    },
                    hint: const Text('Select retention period'),
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
            if (snapshot.hasError) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unable to load RDS options right now.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAddRdsMainDialog(setDialogState),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Filing Code'),
                      style:
                          TextButton.styleFrom(foregroundColor: _primaryColor),
                    ),
                    TextButton.icon(
                      onPressed: _selectedFilingCode == null
                          ? null
                          : () => _showAddRdsSubCategoryDialog(setDialogState),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Sub Category'),
                      style:
                          TextButton.styleFrom(foregroundColor: _primaryColor),
                    ),
                    TextButton.icon(
                      onPressed: _selectedFilingCode == null
                          ? null
                          : () => _confirmDeleteFilingCode(
                                context,
                                _selectedFilingCode!,
                                setDialogState,
                              ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Filing Code'),
                      style:
                          TextButton.styleFrom(foregroundColor: _dangerColor),
                    ),
                    TextButton.icon(
                      onPressed: _selectedFilingCode == null ||
                              _selectedFilingSubCategory == null
                          ? null
                          : () => _confirmDeleteFilingSubCategory(
                                context,
                                _selectedFilingCode!,
                                _selectedFilingSubCategory!,
                                setDialogState,
                              ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Sub Category'),
                      style:
                          TextButton.styleFrom(foregroundColor: _dangerColor),
                    ),
                  ],
                ),
              ],
            ),
            if (_filingCodeOptions.isEmpty && !isLoading && !snapshot.hasError)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No filing codes yet. Add one to enable the dropdown.',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _updateDocument(
    String docId,
    String field,
    String newValue,
  ) async {
    try {
      dynamic valueToUpdate = newValue.trim();
      final updates = <String, dynamic>{};
      DateTime? effectiveDateReceived;
      String? effectiveRetentionPeriod;

      if (field == 'dateReceived') {
        valueToUpdate = Timestamp.fromDate(DateTime.parse(newValue));
        effectiveDateReceived = DateTime.parse(newValue);
      }

      updates[field] = valueToUpdate;
      if (field == 'dateReceived') {
        updates['date'] = valueToUpdate;
      }
      if (field == 'filingCode') {
        updates['filingSubCategory'] = null;
      }

      if (field == 'retentionPeriod') {
        effectiveRetentionPeriod = newValue.trim();
      }

      if (field == 'dateReceived' || field == 'retentionPeriod') {
        final snapshot = await FirebaseFirestore.instance
            .collection('documents')
            .doc(docId)
            .get();
        final data = snapshot.data() ?? <String, dynamic>{};
        effectiveDateReceived ??= _extractTimestamp(data)?.toDate();
        effectiveRetentionPeriod ??= _retentionPeriodFromData(data);

        final normalizedRetention = (effectiveRetentionPeriod ?? '')
            .trim()
            .toLowerCase();
        if (normalizedRetention == 'permanent') {
          updates['dispositionDate'] = 'Permanent';
        } else {
          final dispositionDate = _calculateDispositionDate(
            effectiveDateReceived,
            effectiveRetentionPeriod ?? '',
          );
          updates['dispositionDate'] = dispositionDate == null
              ? ''
              : Timestamp.fromDate(dispositionDate);
        }
      }

      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .update(updates);
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

  Future<void> _updateFilingCodeDetails(
    String docId,
    String filingCode,
    String? filingSubCategory,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .update({
            'filingCode': _nullableString(filingCode),
            'filingSubCategory': _nullableString(filingSubCategory ?? ''),
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
    if (filter == 'All') {
      return DateTimeRange(start: DateTime(2000), end: DateTime(2100, 12, 31));
    }

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
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        );
        _exportFilter = 'Custom Range';
      });
    }
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

  Future<void> _exportCSV(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final List<List<String>> csvData = [
      [
        'Date Received',
        'Filing Code',
        'Retention Period',
        'File Location',
        'Disposition Date',
        'Control Number',
        'Office',
        'Particular',
        'Received Document',
        'Forwarded To',
        'Received By',
        'Comment',
        'Action Taken',
        'Document',
        'Remarks',
        'Access',
        'Status',
        'Received Document Attachment',
      ],
    ];

    final exportAll = _exportFilter == 'All';
    final activeRange = _exportFilter == 'Custom Range'
        ? _selectedExportRange
        : _rangeForFilter(_exportFilter, _selectedExportRange.start);

    for (final doc in docs) {
      final data = doc.data();
      final timestamp = _extractTimestamp(data);
      final date = timestamp?.toDate();
      final normalizedDate = date == null
          ? null
          : DateTime(date.year, date.month, date.day);
      final include =
          exportAll ||
          (normalizedDate != null &&
              !normalizedDate.isBefore(activeRange.start) &&
              !normalizedDate.isAfter(activeRange.end));

      if (include) {
        final receivedDocumentName = (data['pdfFileName'] ?? '')
            .toString()
            .trim();
        final hasReceivedDocument = (data['scannedFileUrl'] ?? '')
            .toString()
            .trim()
            .isNotEmpty;
        final receivedDocumentExportValue = receivedDocumentName.isNotEmpty
            ? receivedDocumentName
            : hasReceivedDocument
            ? 'Attached'
            : '';

        csvData.add([
          date == null ? '' : DateFormat('yyyy-MM-dd').format(date),
          _filingCodeWithSubCategory(data),
          _retentionPeriodFromData(data),
          _fileLocationFromData(data),
          _dispositionDateFromData(data),
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
          _isConfidentialFromData(data) ? 'confidential' : 'open',
          _statusFromData(data),
          receivedDocumentExportValue,
        ]);
      }
    }

    if (csvData.length == 1 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records found for the selected export range.'),
          backgroundColor: _warningColor,
        ),
      );
      return;
    }

    final csv = const ListToCsvConverter().convert(csvData);
    final bytes = utf8.encode('\ufeff$csv');
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final fileFilter = _exportFilter.toLowerCase().replaceAll(' ', '_');
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'documents_export_$fileFilter.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _buildExportDateLabel() {
    if (_exportFilter == 'All') {
      return 'All records';
    }

    final activeRange = _exportFilter == 'Custom Range'
        ? _selectedExportRange
        : _rangeForFilter(_exportFilter, _selectedExportRange.start);
    return '${DateFormat('MMM d, yyyy').format(activeRange.start)} - ${DateFormat('MMM d, yyyy').format(activeRange.end)}';
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
          width: 540,
          child: editable
              ? TextField(
                  controller: controller,
                  maxLines: 12,
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

  Future<void> _showUpdateRegistryDialog(
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
    String scannedFileUrl = (data['scannedFileUrl'] ?? '').toString();
    String pdfFileName = (data['pdfFileName'] ?? '').toString();
    String adminDocumentUrl = (data['adminDocumentUrl'] ?? '').toString();
    String adminDocumentFileName = (data['adminDocumentFileName'] ?? '')
        .toString();
    bool isConfidential = _isConfidentialFromData(data);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark
              ? const Color(0xFF161E27)
              : const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Update Registry',
            style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controlNumberController,
                          decoration: _dialogInputDecoration('Control Number'),
                          style: TextStyle(color: _primaryText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: officeController,
                          decoration: _dialogInputDecoration('Office'),
                          style: TextStyle(color: _primaryText),
                        ),
                      ),
                    ],
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
                        child: TextField(
                          controller: forwardedToController,
                          decoration: _dialogInputDecoration('Forwarded To'),
                          style: TextStyle(color: _primaryText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: receivedByController,
                          decoration: _dialogInputDecoration('Received By'),
                          style: TextStyle(color: _primaryText),
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isConfidential,
                    activeColor: _primaryColor,
                    secondary: Icon(
                      Icons.lock_outline,
                      color: isConfidential ? _primaryColor : _secondaryText,
                    ),
                    title: Text(
                      'Confidential',
                      style: TextStyle(
                        color: _primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Only Super Admin and Supervisor Admin can access this entry.',
                      style: TextStyle(color: _secondaryText),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        isConfidential = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final attachment = await _pickRegistryAttachment();
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
                            final attachment = await _pickRegistryAttachment();
                            if (attachment == null) return;
                            setDialogState(() {
                              adminDocumentUrl = attachment['url'] ?? '';
                              adminDocumentFileName = attachment['name'] ?? '';
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
                      'scannedFileUrl': scannedFileUrl,
                      'pdfFileName': pdfFileName,
                      'adminDocumentUrl': adminDocumentUrl,
                      'adminDocumentFileName': adminDocumentFileName,
                      'isConfidential': isConfidential,
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

  Future<void> _showDropdownCellDialog({
    required String title,
    required String docId,
    required String field,
    required String currentValue,
    required List<String> options,
  }) async {
    String? selectedValue = currentValue.trim().isEmpty ? null : currentValue;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDark
              ? const Color(0xFF161E27)
              : const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 420,
            child: DropdownButtonFormField<String>(
              value: options.contains(selectedValue) ? selectedValue : null,
              decoration: _dialogInputDecoration(title),
              dropdownColor: _cardBackground,
              items: options
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setDialogState(() {
                  selectedValue = value;
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Close',
                style: TextStyle(color: _primaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: selectedValue == null || selectedValue == currentValue
                  ? null
                  : () async {
                      await _updateDocument(docId, field, selectedValue!);
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
      ),
    );
  }

  Future<void> _showFilingCodeCellDialog({
    required String docId,
    required String currentFilingCode,
    required String currentSubCategory,
  }) async {
    String? selectedFilingCode = currentFilingCode.trim().isEmpty
        ? null
        : currentFilingCode;
    String? selectedSubCategory = currentSubCategory.trim().isEmpty
        ? null
        : currentSubCategory;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rds_options')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final filingCodeOptions = _buildFilingCodeOptions(docs);
                final subCategoryOptions = _buildFilingSubCategoryOptions(
                  docs,
                  selectedFilingCode,
                );
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

                return AlertDialog(
                  backgroundColor: _isDark
                      ? const Color(0xFF161E27)
                      : const Color(0xFFFBF9F5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    'Filing Code',
                    style: TextStyle(
                      color: _primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: SizedBox(
                    width: 460,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: filingCodeOptions.contains(selectedFilingCode)
                              ? selectedFilingCode
                              : null,
                          decoration: _dialogInputDecoration('Filing Code'),
                          dropdownColor: _cardBackground,
                          items: filingCodeOptions
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(option),
                                ),
                              )
                              .toList(),
                          onChanged: isLoading || filingCodeOptions.isEmpty
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedFilingCode = value;
                                    selectedSubCategory = null;
                                  });
                                },
                          hint: Text(
                            isLoading
                                ? 'Loading filing codes...'
                                : 'Select filing code',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value:
                              subCategoryOptions.contains(selectedSubCategory)
                              ? selectedSubCategory
                              : null,
                          decoration: _dialogInputDecoration('Sub Category'),
                          dropdownColor: _cardBackground,
                          items: subCategoryOptions
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(option),
                                ),
                              )
                              .toList(),
                          onChanged: isLoading || subCategoryOptions.isEmpty
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedSubCategory = value;
                                  });
                                },
                          hint: Text(
                            selectedFilingCode == null
                                ? 'Select filing code first'
                                : 'Select sub category',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: _primaryColor),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          selectedFilingCode == null ||
                              (selectedFilingCode == currentFilingCode &&
                                  (selectedSubCategory ?? '') ==
                                      currentSubCategory)
                          ? null
                          : () async {
                              await _updateFilingCodeDetails(
                                docId,
                                selectedFilingCode!,
                                selectedSubCategory,
                              );
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
                );
              },
            ),
      ),
    );
  }

  Widget _buildEditableCell(
    String docId,
    String field,
    String value, {
    double width = 96,
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

  Widget _buildDropdownEditableCell(
    String docId,
    String field,
    String value, {
    required String label,
    required List<String> options,
    double width = 96,
  }) {
    return _buildCellCard(
      value,
      width: width,
      onTap: () => _showDropdownCellDialog(
        title: label,
        docId: docId,
        field: field,
        currentValue: value,
        options: options,
      ),
      showEditIcon: true,
    );
  }

  Widget _buildFilingCodeEditableCell(
    String docId,
    String filingCode,
    String subCategory, {
    double width = 96,
  }) {
    final displayValue = [
      filingCode,
      subCategory,
    ].where((value) => value.trim().isNotEmpty).join('\n');

    return _buildCellCard(
      displayValue,
      width: width,
      onTap: () => _showFilingCodeCellDialog(
        docId: docId,
        currentFilingCode: filingCode,
        currentSubCategory: subCategory,
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
        onTap: () => _showCellDialog(title: 'Cell Content', value: displayValue),
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

  Widget _buildConfidentialBadge(bool isConfidential) {
    final color = isConfidential ? _primaryColor : _secondaryText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isConfidential
            ? _primaryColor.withOpacity(_isDark ? 0.22 : 0.1)
            : _softBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isConfidential
              ? _primaryColor.withOpacity(0.45)
              : _effectiveBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfidential ? Icons.lock_outline : Icons.lock_open_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isConfidential ? 'Confidential' : 'Open',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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

  Future<void> _pickAttachment(
    void Function(void Function()) setDialogState,
  ) async {
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

    setDialogState(() {
      _selectedPdfDataUrl = reader.result?.toString() ?? '';
      _pdfNameController.text = file.name;
    });
  }

  void _openAttachment(String fileUrl) {
    if (fileUrl.trim().isEmpty) {
      return;
    }

    html.window.open(fileUrl, '_blank');
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
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .update({
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
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(docId)
          .update({
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

    return {'url': reader.result?.toString() ?? '', 'name': file.name};
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

  void _showAddDocumentDialog({bool confidential = false}) {
    _clearForm();
    _isConfidential = confidential;
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
              const SizedBox(width: 12),
              FilterChip(
                selected: _isConfidential,
                avatar: Icon(
                  _isConfidential
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined,
                  size: 18,
                ),
                label: const Text('Confidential'),
                selectedColor: _primaryColor.withOpacity(0.16),
                checkmarkColor: _primaryColor,
                onSelected: (value) {
                  setDialogState(() {
                    _isConfidential = value;
                  });
                  setState(() {});
                },
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
                    GestureDetector(
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildRdsCodeDropdowns(setDialogState),
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _officeController,
                            decoration: _dialogInputDecoration('Office'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _particularController,
                      decoration: _dialogInputDecoration('Particular'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pdfNameController,
                            readOnly: true,
                            decoration: _dialogInputDecoration(
                              'Attachment',
                              hintText: 'No file selected',
                              suffixIcon: IconButton(
                                onPressed: () async {
                                  await _pickAttachment(setDialogState);
                                },
                                icon: const Icon(Icons.upload_file_outlined),
                                tooltip: 'Upload attachment',
                              ),
                            ),
                          ),
                        ),
                        if (_selectedPdfDataUrl.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openAttachment(_selectedPdfDataUrl),
                            icon: const Icon(Icons.attach_file_outlined),
                            label: const Text('Open'),
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _receivedByController,
                            decoration: _dialogInputDecoration('Received By'),
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
                      controller: _fileLocationAfterRetentionController,
                      decoration: _dialogInputDecoration('File Location'),
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
                final saved = await _addDocument();
                if (saved && dialogContext.mounted) {
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

  Widget _buildStatsPanel({
    required int totalDocuments,
    required int withAttachments,
    required int withoutActionTaken,
    required int confidential,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Super Admin Overview',
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
          subtitle: 'Files ready to download',
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
          highlightColor: _warningColor,
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
        const SizedBox(height: 16),
        _DashboardStatCard(
          title: 'Confidential',
          value: '$confidential',
          subtitle: 'Restricted registry entries',
          icon: Icons.lock_outline,
          highlightColor: _dangerColor,
          darkMode: _isDark,
          totalDocuments: totalDocuments,
        ),
      ],
    );
  }

  Widget _buildTopBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A7D9A), Color(0xFF681414)],
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
                    Icons.account_tree_outlined,
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
                    icon: Icons.verified_user_outlined,
                    label: 'Super Admin',
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

  Widget _buildToolbar(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
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
                  focusNode: _searchFocusNode,
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
                  onChanged: _onSearchChanged,
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
                  items: ['All', 'Week', 'Month', 'Year', 'Custom Range']
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
                  await _exportCSV(docs);
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
                onPressed: () => _showAddDocumentDialog(confidential: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _softBackground,
                  foregroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  side: BorderSide(color: _effectiveBorder),
                ),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Confidential'),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddDocumentDialog(),
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

    Widget attachmentRow(
      String docId,
      String label,
      String fileName,
      String url,
    ) {
      final hasFile = url.trim().isNotEmpty;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
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
                      Icons.attach_file,
                      size: 18,
                      color: hasFile ? _primaryColor : _secondaryText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasFile
                            ? (fileName.trim().isEmpty
                                  ? 'Download File'
                                  : fileName)
                            : 'No attachment',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasFile ? _primaryText : _secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: hasFile
                          ? () => _downloadAttachment(docId, url, fileName)
                          : null,
                      icon: const Icon(Icons.download_outlined),
                      color: _primaryColor,
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildConfidentialBadge(_isConfidentialFromData(data)),
                        _buildStatusBadge(_statusFromData(data)),
                      ],
                    ),
                  ]);
                  final recordDetails = infoCard('Record Details', [
                    infoRow('Filing Code', _filingCodeWithSubCategory(data)),
                    infoRow('Retention Period', _retentionPeriodFromData(data)),
                    infoRow('File Location', _fileLocationFromData(data)),
                    infoRow('Disposition Date', _dispositionDateFromData(data)),
                  ]);
                  final routing = infoCard('Routing & History', [
                    infoRow('Forwarded To', (data['forwardedTo'] ?? '').toString()),
                    infoRow('Received By', (data['receivedBy'] ?? '').toString()),
                    infoRow('Comment', (data['comment'] ?? '').toString()),
                    infoRow('Action Taken', (data['actionTaken'] ?? '').toString()),
                    infoRow('Remarks', (data['remarks'] ?? '').toString()),
                  ]);
                  final attachments = infoCard('Attachments', [
                    attachmentRow(
                      currentDoc.id,
                      'Received Document',
                      (data['pdfFileName'] ?? '').toString(),
                      (data['scannedFileUrl'] ?? '').toString(),
                    ),
                    attachmentRow(
                      currentDoc.id,
                      'Document',
                      (data['adminDocumentFileName'] ?? '').toString(),
                      (data['adminDocumentUrl'] ?? '').toString(),
                    ),
                  ]);

                  return SingleChildScrollView(
                          child: isCompact
                              ? Column(
                                  children: [
                                    coreInfo,
                                    recordDetails,
                                    attachments,
                                    routing,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          coreInfo,
                                          recordDetails,
                                          attachments,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        children: [routing],
                                      ),
                                    ),
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
                        onPressed: () =>
                            _showUpdateRegistryDialog(currentDoc.id, data),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _warningColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => exportRoutingSlipPdf(data),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF295C88),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showDeleteDialog(currentDoc.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dangerColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
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
                        'Registry Documents',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryText,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'A simplified supervisor-style view with quick controls, document details, and status tracking.',
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
                                  final accessLabel =
                                      _isConfidentialFromData(data)
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
                                        _buildValueCell(
                                          (data['controlNumber'] ?? '')
                                              .toString(),
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
                                          textColor:
                                              accessLabel == 'Confidential'
                                              ? _dangerColor
                                              : _successColor,
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 130,
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _showViewMoreDialog(
                                              docs,
                                              index,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF5A7D9A),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                      _filingCodeFromData(data),
                      _filingSubCategoryFromData(data),
                      _retentionPeriodFromData(data),
                      _dispositionDateFromData(data),
                      (data['controlNumber'] ?? '').toString(),
                      (data['office'] ?? '').toString(),
                      (data['particular'] ?? '').toString(),
                      (data['pdfFileName'] ?? '').toString(),
                      (data['forwardedTo'] ?? '').toString(),
                      (data['receivedBy'] ?? '').toString(),
                      (data['comment'] ?? '').toString(),
                      (data['actionTaken'] ?? '').toString(),
                      _fileLocationFromData(data),
                      (data['adminDocumentFileName'] ?? '').toString(),
                      (data['remarks'] ?? '').toString(),
                      _isConfidentialFromData(data) ? 'Confidential' : 'Open',
                      _statusLabel(_statusFromData(data)),
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
                  final confidentialDocs = allDocs
                      .where((doc) => _isConfidentialFromData(doc.data()))
                      .length;

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
                                withAttachments: _countWithAttachments(allDocs),
                                withoutActionTaken:
                                    _countWithoutActionTaken(allDocs),
                                confidential: confidentialDocs,
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
                                                _buildToolbar(context, docs),
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
                                        _buildToolbar(context, docs),
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
