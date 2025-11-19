import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'race_selection_page.dart';
import 'race_starts_page.dart';
import 'race_results_page.dart';




class FleetAdminPage extends StatefulWidget {
  const FleetAdminPage({super.key});

  @override
  State<FleetAdminPage> createState() => _FleetAdminPageState();
}

class _FleetAdminPageState extends State<FleetAdminPage> {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));
  final TextEditingController _searchController = TextEditingController();

  final List<String> _classes = [
    'All',
    'White Sail 1',
    'White Sail 2',
    'Spinnaker 1',
    'Spinnaker 2',
  ];

  String _selectedClass = 'All';
  List<dynamic> _boats = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBoats();
  }

  // ---------------------------------------------------------------------------
  // LOAD BOATS
  // ---------------------------------------------------------------------------
  Future<void> _loadBoats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = <String, dynamic>{};
      if (_selectedClass != 'All') {
        query['class_name'] = _selectedClass;
      }

      final res = await dio.get('/boats', queryParameters: query);

      final search = _searchController.text.toLowerCase().trim();
      var boats = res.data as List<dynamic>;

      if (search.isNotEmpty) {
        boats = boats.where((b) {
          final sail = (b['sail_no'] ?? '').toString().toLowerCase();
          final name = (b['name'] ?? '').toString().toLowerCase();
          return sail.contains(search) || name.contains(search);
        }).toList();
      }

      setState(() => _boats = boats);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ADD BOAT DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _showAddBoatDialog() async {
    final sailController = TextEditingController();
    final nameController = TextEditingController();
    final clubController = TextEditingController();
    final ratingController = TextEditingController();

    String classValue = 'White Sail 1';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Boat'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: sailController,
                  decoration: const InputDecoration(labelText: 'Sail Number'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Boat Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: clubController,
                  decoration: const InputDecoration(labelText: 'Club'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: classValue,
                  decoration: const InputDecoration(labelText: 'Class/Division'),
                  items: const [
                    DropdownMenuItem(value: 'White Sail 1', child: Text('White Sail 1')),
                    DropdownMenuItem(value: 'White Sail 2', child: Text('White Sail 2')),
                    DropdownMenuItem(value: 'Spinnaker 1', child: Text('Spinnaker 1')),
                    DropdownMenuItem(value: 'Spinnaker 2', child: Text('Spinnaker 2')),
                  ],
                  onChanged: (v) => classValue = v!,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ratingController,
                  decoration: const InputDecoration(labelText: 'Rating value (e.g. 0.950)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              await dio.post('/boats', data: {
                'sail_no': sailController.text.trim(),
                'name': nameController.text.trim(),
                'club': clubController.text.trim().isEmpty ? null : clubController.text.trim(),
                'class_name': classValue,
                'rating_value': double.parse(ratingController.text.trim()),
              });

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ) // Reference: Flutter ElevatedButton Docs
        ],
      ),
    );

    if (result == true) _loadBoats();
  }

  // ---------------------------------------------------------------------------
  // EDIT BOAT DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _showEditBoatDialog(Map<String, dynamic> boat) async {
    final sailController = TextEditingController(text: boat['sail_no']);
    final nameController = TextEditingController(text: boat['name']);
    final clubController = TextEditingController(text: boat['club']);
    final ratingController =
        TextEditingController(text: boat['rating_value']?.toString());

    String classValue = boat['class_name'];

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Boat'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: sailController,
                  decoration: const InputDecoration(labelText: 'Sail Number'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Boat Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: clubController,
                  decoration: const InputDecoration(labelText: 'Club'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: classValue,
                  decoration: const InputDecoration(labelText: 'Class/Division'),
                  items: const [
                    DropdownMenuItem(value: 'White Sail 1', child: Text('White Sail 1')),
                    DropdownMenuItem(value: 'White Sail 2', child: Text('White Sail 2')),
                    DropdownMenuItem(value: 'Spinnaker 1', child: Text('Spinnaker 1')),
                    DropdownMenuItem(value: 'Spinnaker 2', child: Text('Spinnaker 2')),
                  ],
                  onChanged: (v) => classValue = v!,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ratingController,
                  decoration: const InputDecoration(labelText: 'Rating value'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              await dio.put('/boats/${boat['id']}', data: {
                'sail_no': sailController.text.trim(),
                'name': nameController.text.trim(),
                'club': clubController.text.trim(),
                'class_name': classValue,
                'rating_value': double.parse(ratingController.text.trim()),
              });

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save changes'),
          )
        ],
      ),
    );

    if (result == true) _loadBoats();
  }

  // ---------------------------------------------------------------------------
  // DELETE BOAT
  // ---------------------------------------------------------------------------
  Future<void> _confirmDeleteBoat(Map<String, dynamic> boat) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete boat'),
        content: Text(
          'Are you sure you want to delete\n${boat['sail_no']} – ${boat['name']}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await dio.delete('/boats/${boat['id']}');
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );

    if (result == true) _loadBoats();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RCYC Fleet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            tooltip: "Select today's race",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RaceSelectionPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: "Record start times",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RaceStartsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: "View today's results",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RaceResultsPage()),
              );
            },
          ),

        ],
      ),


      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // SEARCH FIELD
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by sail number or name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => _loadBoats(),
            ),

            const SizedBox(height: 10),

            // FILTER CHIPS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _classes.map((c) {
                  final selected = _selectedClass == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedClass = c);
                        _loadBoats();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // LIST OF BOATS
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : _boats.isEmpty
                          ? const Center(child: Text('No boats yet.'))
                          : ListView.builder(  
                              itemCount: _boats.length,
                              itemBuilder: (_, i) {
                                final b = Map<String, dynamic>.from(_boats[i]);

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    onTap: () => _showEditBoatDialog(b),
                                    leading: CircleAvatar(
                                      child: Text(
                                        b['sail_no']
                                            .toString()
                                            .characters
                                            .take(3)
                                            .toString(),
                                      ),
                                    ),
                                    title: Text('${b['sail_no']} – ${b['name']}'),
                                    subtitle: Text(
                                      '${b['class_name']} • Rating: ${b['rating_value']}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (b['club'] != null && b['club'] != '')
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8.0),
                                            child: Text(
                                              b['club'],
                                              style: const TextStyle(
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () =>
                                              _confirmDeleteBoat(b),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ), // Reference: Flutter ListTile & ListView Docs
            ),
          ],
        ),
      ),

      // ADD BOAT BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBoatDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add boat'),
      ),
    );
  }
}
