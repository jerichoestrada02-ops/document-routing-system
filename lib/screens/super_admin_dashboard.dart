import 'package:flutter/material.dart';

class SuperAdminDashboard extends StatefulWidget {
  @override
  _SuperAdminDashboardState createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  // Start with an empty list of records
  List<Map<String, TextEditingController>> records = [];
  String searchText = '';

  @override
  void initState() {
    super.initState();
    addEmptyRow();
  }

  void addEmptyRow() {
    setState(() {
      records.add({
        'date': TextEditingController(),
        'controlNumber': TextEditingController(),
        'office': TextEditingController(),
        'particular': TextEditingController(),
        'receivedBy': TextEditingController(),
        'forwardedTo': TextEditingController(),
        'comment': TextEditingController(),
        'actionTaken': TextEditingController(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter records by Control Number
    final filteredRecords = records
        .where((r) => r['controlNumber']!.text.contains(searchText))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Super Admin Dashboard'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Control Number...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        searchText = val;
                      });
                    },
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: addEmptyRow,
                  child: Text('Add Row'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Control #')),
                  DataColumn(label: Text('Office')),
                  DataColumn(label: Text('Particular')),
                  DataColumn(label: Text('Received By')),
                  DataColumn(label: Text('Forwarded To')),
                  DataColumn(label: Text('Comment')),
                  DataColumn(label: Text('Action Taken')),
                ],
                rows: filteredRecords
                    .map(
                      (record) => DataRow(
                        cells: record.entries
                            .map(
                              (entry) => DataCell(
                                SizedBox(
                                  width: 150, // adjust column width
                                  child: TextField(
                                    controller: entry.value,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}