// This is the main admin screen after login. It provides complete fleet management:

// View all boats in the RCYC fleet
// Filter by class (White Sail 1/2, Spinnaker 1/2)
// Search by sail number or boat name
// Add new boats (form dialog)
// Edit existing boats (pre-filled form dialog)
// Delete boats (with confirmation)
// Navigate to race selection, timing, and results pages

// Key Architecture Patterns
// Master-Detail Pattern: List of boats with tap-to-edit
// CRUD Operations: Create, Read, Update, Delete via REST API
// Filtering: Server-side (class) and client-side (search)
// Dialog Forms: Reusable AlertDialog with Form widgets


import 'package:flutter/material.dart'; // Flutter UI framework (widgets, Material design)
import 'package:dio/dio.dart'; // Dio is the HTTP client used to call the FastAPI backend
import 'package:regatta_app/theme/app_theme.dart';
// Reference: Flutter Material UI (Scaffold, AppBar, ListView) [F1][F3][F5]
// Reference: Dio client configuration [D1]

// These are other pages in this app that the admin can navigate to from the top-right icons
import 'race_selection_page.dart'; // Page where the admin selects today's race/course
import 'race_starts_page.dart'; // Page where the admin records class start times and finishes
import 'race_results_page.dart'; // Page where the admin views today's race results

// This page is a StatefulWidget because the list of boats and filters can change over time (search, add, edit, delete), so they need to be a mutable state
class FleetAdminPage extends StatefulWidget {
  const FleetAdminPage({super.key}); // const constructor, no parameters

  @override
  State<FleetAdminPage> createState() => _FleetAdminPageState();
}

// This is the state class that actually holds and manages the changing data
// (boats list, selected class, loading state, etc.) for FleetAdminPage
class _FleetAdminPageState extends State<FleetAdminPage> {
  //  FIELDS / STATE

  // Dio HTTP client configured to talk to the backend
  // BaseOptions(baseUrl: 'http://127.0.0.1:8000') means
  // all requests like dio.get('/boats') will go to http://127.0.0.1:8000/boats
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));

  // Controller for the search text field at the top of the page.
  // It lets me read the current search string and also react to changes.
  final TextEditingController _searchController = TextEditingController();

  // This is the list of fleet classes/divisions we allow in the UI as filters
  // "All" means show boats from all classes.
  final List<String> _classes = [
    'All',
    'White Sail 1',
    'White Sail 2',
    'Spinnaker 1',
    'Spinnaker 2',
  ];

  // Stores whichever class is currently selected in the filter chips
  // It starts with 'All' so all of the boats are visable initially
  String _selectedClass = 'All';

  // This list will hold the boats returned by the backend
  // Each element is a map representing a boat (id, sail_no, name, club, class_name, rating_value)
  List<dynamic> _boats = [];

  // True while it is loading data (e.g. calling /boats)
  // Used to show a CircularProgressIndicator
  bool _loading = false;

  // If something goes wrong (e.g. backend down), we store the error message here and then display it in the UI.
  String? _error;

  // LIFECYCLE 

  @override
  void initState() {
    super.initState(); // Always call super.initState() first
    // As soon as this page is created and shown the first time, we load the boats from the backend
    _loadBoats();
  } // Reference: StatefulWidget, initState, setState lifecycle [F1]

  //  Load boats from backend

  // This method calls GET /boats on my FastAPI backend and updates the state.
  // It also applies:
  // - class filter (White Sail / Spinnaker / All)
  // - search filter (sail number or boat name) on the client side
  // Reference: Dio GET with queryParameters, async & Futures [D1][F8]
  // Reference: basic list filtering in Dart collections [F8]
  Future<void> _loadBoats() async {
    // Set loading=true and clear any previous error before making the request
    setState(() {
      _loading = true;  // Show spinner in the UI
      _error = null;  // Clear any previous error message
    });

    try {
      // Query parameters that we will send with GET /boats
      // By default this is empty (no filtering)
      final query = <String, dynamic>{};

      // If the user selected a specific class (not "All"), it adds class_name to the query so the backend filters it
      if (_selectedClass != 'All') {
        query['class_name'] = _selectedClass;
      }

      // Perform the HTTP GET request
      final res = await dio.get('/boats', queryParameters: query);

      // Read the current contents of the search field and normalise it
      final search = _searchController.text.toLowerCase().trim();

      // The response body (res.data) is JSON and should be a list of boats
      var boats = res.data as List<dynamic>;

      // If search is not empty, we filter the boats list locally
      if (search.isNotEmpty) {
        boats = boats.where((b) {
          // Convert sail_no and name to lowercase strings to make the search case insensitive
          final sail = (b['sail_no'] ?? '').toString().toLowerCase();
          final name = (b['name'] ?? '').toString().toLowerCase();
          // We keep the boat if either sail number or boat name contains the search text
          return sail.contains(search) || name.contains(search);
        }).toList(); // toList() creates a new filtered list
      }

      // Here the boats are into the state so the UI gets rebuilt with the new list
      setState(() => _boats = boats);
    } catch (e) {
      // If anything goes wrong (e.g. no backend running, bad response), we capture the error to show to the user
      setState(() => _error = e.toString());
    } finally {
      // In both success or failure, we stop the loading spinner
      setState(() => _loading = false);
    }
  }

  //  Add boat dialog

  // Opens a popup dialog so the admin can add a new boat
  // When the user presses "Save", it sends POST /boats to the backend
  // Reference: showDialog and AlertDialog pattern [F7]
  // Reference: Form and textFormField validation [F4]

  Future<void> _showAddBoatDialog() async {
    // Create controllers for each of the text fields inside the dialog
    final sailController = TextEditingController();  // Sail number
    final nameController = TextEditingController();  // Boat name
    final clubController = TextEditingController();  // Club (optional)
    final ratingController = TextEditingController(); // Rating / handicap

    // Default selection for class in the dropdown
    String classValue = 'White Sail 1';

    // Key for the form widget (used to validate all fields at once)
    final formKey = GlobalKey<FormState>();

    // showDialog presents an AlertDialog and returns a Future<bool?>
    // We use bool to indicate whether a new boat was successfully saved (true) or not
    final result = await showDialog<bool>(
      context: context, // context = location of this widget in the tree
      builder: (context) => AlertDialog(
        // Title of the dialog
        title: const Text('Add Boat'),

        // The main content of the dialog
        content: SingleChildScrollView(
          // SingleChildScrollView allows the content to scroll if it's too big
          child: Form(
            key: formKey, // Connect this Form to formKey for validation.
            child: Column(
              // Column arranges the fields vertically
              children: [
                // Text field for sail number
                TextFormField(
                  controller: sailController, // Read/write the text here
                  decoration: const InputDecoration(labelText: 'Sail Number'),
                  // validator is called when we run formKey.currentState!.validate()
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8), // Small vertical space

                // Text field for boat name
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Boat Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),

                // Text field for club (optional; can be blank)
                TextFormField(
                  controller: clubController,
                  decoration: const InputDecoration(labelText: 'Club'),
                ),
                const SizedBox(height: 8),

                // Dropdown to select the boat's class/division
                // Reference: DropdownButtonFormField usage for select inputs [F1]
                DropdownButtonFormField<String>(
                  initialValue: classValue, // Starting selection
                  decoration:
                      const InputDecoration(labelText: 'Class/Division'),
                  // The items in the dropdown menu
                  items: const [
                    DropdownMenuItem(
                        value: 'White Sail 1', child: Text('White Sail 1')),
                    DropdownMenuItem(
                        value: 'White Sail 2', child: Text('White Sail 2')),
                    DropdownMenuItem(
                        value: 'Spinnaker 1', child: Text('Spinnaker 1')),
                    DropdownMenuItem(
                        value: 'Spinnaker 2', child: Text('Spinnaker 2')),
                  ],
                  // When the user picks something else, we update classValue
                  onChanged: (v) => classValue = v!,
                ),
                const SizedBox(height: 8),

                // Text field for rating/handicap value
                TextFormField(
                  controller: ratingController,
                  decoration: const InputDecoration(
                      labelText: 'Rating value (e.g. 0.950)'),
                  // This keyboard type suggests numbers with decimal points
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    // Rating must not be empty and must convert to double.
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null; // null means "no error"
                  },
                ),
              ],
            ),
          ),
        ),

        // Buttons at the bottom of the Alert Dialog
        actions: [
          // Cancel button: simply close dialog and return false
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          // Save button: validates input then calls backend to create boat
          ElevatedButton(
            onPressed: () async {
              // Validate fields, if any validator returns an error string, this will be false and we don't proceed
              if (!formKey.currentState!.validate()) return;

              // Build request body from text fields and dropdown
              await dio.post('/boats', data: {
                'sail_no': sailController.text.trim(),
                'name': nameController.text.trim(),
                // If club is blank, send null, otherwise send the trimmed text
                'club': clubController.text.trim().isEmpty
                    ? null
                    : clubController.text.trim(),
                'class_name': classValue, // Selected class from dropdown
                'rating_value':
                    double.parse(ratingController.text.trim()), // parsed rating
              });

              // If the widget is still in the tree, close the dialog and return true
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // If the result from dialog is true, we reload boats from the backend
    if (result == true) _loadBoats();
  }

  //  Edit boat dialog

  // Opens a dialog with existing boat details pre-filled, so the admin can update them. Calls PUT /boats/{id}.
  // Reference: Edit dialog using Form and TextFormField [F4][F7]
  Future<void> _showEditBoatDialog(Map<String, dynamic> boat) async {
    // Pre-fill controllers with the current boat data
    final sailController = TextEditingController(text: boat['sail_no']);
    final nameController = TextEditingController(text: boat['name']);
    final clubController = TextEditingController(text: boat['club']);
    final ratingController =
        TextEditingController(text: boat['rating_value']?.toString());

    // Class dropdown starts at the boat's existing class
    String classValue = boat['class_name'];

    // Again, use a Form key for validation
    final formKey = GlobalKey<FormState>();

    // Show edit dialog in the same way as add dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Boat'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                // Sail number field (editable)
                TextFormField(
                  controller: sailController,
                  decoration: const InputDecoration(labelText: 'Sail Number'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),

                // Boat name field (editable)
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Boat Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),

                // Club field (editable, optional)
                TextFormField(
                  controller: clubController,
                  decoration: const InputDecoration(labelText: 'Club'),
                ),
                const SizedBox(height: 8),

                // Dropdown for class/division (editable)
                DropdownButtonFormField<String>(
                  initialValue: classValue,
                  decoration:
                      const InputDecoration(labelText: 'Class/Division'),
                  items: const [
                    DropdownMenuItem(
                        value: 'White Sail 1', child: Text('White Sail 1')),
                    DropdownMenuItem(
                        value: 'White Sail 2', child: Text('White Sail 2')),
                    DropdownMenuItem(
                        value: 'Spinnaker 1', child: Text('Spinnaker 1')),
                    DropdownMenuItem(
                        value: 'Spinnaker 2', child: Text('Spinnaker 2')),
                  ],
                  onChanged: (v) => classValue = v!,
                ),
                const SizedBox(height: 8),

                // Rating field (editable)
                TextFormField(
                  controller: ratingController,
                  decoration:
                      const InputDecoration(labelText: 'Rating value'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
          // Cancel: just dismiss the dialog
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          // Save changes: validate then PUT to backend
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              // PUT /boats/{id} to update this boat
              await dio.put('/boats/${boat['id']}', data: {
                'sail_no': sailController.text.trim(),
                'name': nameController.text.trim(),
                'club': clubController.text.trim(),
                'class_name': classValue,
                'rating_value':
                    double.parse(ratingController.text.trim()),
              });

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save changes'),
          )
        ],
      ),
    );

    // If edit succeeded, reload boats
    if (result == true) _loadBoats();
  }

  //  Delete Boat Confirmation

  // Prompts the admin to confirm they really want to delete a boat, then calls DELETE /boats/{id} if they confirm
  // Reference: Confirmation dialogs, then Dio DELETE [F7][D1]

  Future<void> _confirmDeleteBoat(Map<String, dynamic> boat) async {
    // Show an AlertDialog to confirm deletion
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete boat'),
        // Include sail number and boat name in the message so it's clear which boat
        content: Text(
          'Are you sure you want to delete\n${boat['sail_no']} – ${boat['name']}?',
        ),
        actions: [
          // Cancel button: do nothing
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          // Delete button: calls DELETE /boats/{id}
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () async {
              await dio.delete('/boats/${boat['id']}');
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );

    // If result == true, deletion happened - reload the fleet
    if (result == true) _loadBoats();
  }

  //  Build UI

  // The build method describes how to display this screen
  // It returns a Scaffold (app structure) containing AppBar, body and FAB
  // Reference: AppBar actions and Navigator.push to other pages [F2][F1]

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar at the top with the title and navigation icons
      appBar: AppBar(
        title: const Text('RCYC Fleet'),  // Screen title text

        // Actions are the small icon buttons on the right side of the AppBar
        actions: [
          // Flag icon: go to page where admin selects today's race/course
          IconButton(
            icon: const Icon(Icons.flag),
            tooltip: "Select today's race",  // Tooltip shown on long press
            onPressed: () {
              // Navigator.push opens a new page on top of the current one
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RaceSelectionPage()),
              );
            },
          ),
          // Timer icon: go to page where admin records start/finish times
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
          // Table icon: go to results page to see today's race results
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: "View today's results",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RaceResultsPage(isAdmin: true,)),
              );
            },
          ),
        ],
      ),

      // The body of the screen: everything below the AppBar
      body: Padding(
        padding: const EdgeInsets.all(12), // 12px padding on all sides
        child: Column(
          // Column stacks children vertically: search bar, filters, list of boats
          children: [
            // Search Bar
            TextField(
              controller: _searchController, // Connects text field to the controller
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),  // Magnifying glass icon
                hintText: 'Search by sail number or name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),  // Rounded corners
                ),
              ),
              // Whenever the user types, we call _loadBoats to apply search filter
              onChanged: (_) => _loadBoats(),
            ),

            const SizedBox(height: 10), // Small gap below search bar

            // Class Filter Chips
            // Horizontally scrollable row of ChoiceChips for All/White Sail/Spinnaker
            // Reference: TextField for live search, ChoiceChip for filters [F1]
            SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Allow sideways scrolling
              child: Row(
                children: _classes.map((c) {
                  // For each class name in _classes, we create a chip
                  final selected = _selectedClass == c; // True if this chip is active
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),   // The text on the chip (e.g. "White Sail 1")
                      selected: selected, // Highlights the chip if active
                      onSelected: (_) {
                        // When the user taps a chip:
                        setState(() => _selectedClass = c); // update the selected class
                        _loadBoats(); // reload boats with the new class filter
                      },
                    ),
                  );
                }).toList(), // Convert from Iterable<Widget> to List<Widget>
              ),
            ),

            const SizedBox(height: 10),
            // List of Boats (or Loading/error status)
            // Reference: ListView.builder and Card and ListTile UI pattern [F5]

            Expanded(
              // Expanded tells the Column that this child should take up all remaining space
              child: _loading
                  // Case 1: If loading, show a spinner in the center
                  ? const Center(child: CircularProgressIndicator())
                  // Case 2: If there is an error message, show it
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      // Case 3: No boats found after filters/search to show a message
                      : _boats.isEmpty
                          ? const Center(child: Text('No boats yet.'))
                          // Case 4: Normal case, we have boats to show ListView.builder
                          : ListView.builder(
                              itemCount:
                                  _boats.length, // Number of rows in the list
                              itemBuilder: (_, i) {
                                // Convert dynamic JSON map to Map<String, dynamic>
                                final b =
                                    Map<String, dynamic>.from(_boats[i]);

                                // Each boat is shown inside a Card with ListTile inside
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12), // Rounded corners
                                  ),
                                  child: ListTile(
                                    // onTap: when user taps the row, open edit dialog.
                                    onTap: () => _showEditBoatDialog(b),

                                    // leading: the small circular avatar on the left
                                    leading: CircleAvatar(
                                      child: Text(
                                        // Show the first 3 characters of the sail number inside the circle
                                        b['sail_no']
                                            .toString()
                                            .characters
                                            .take(3)
                                            .toString(),
                                      ),
                                    ),

                                    // title: main bold text, shows "SailNo – Boat Name"
                                    title: Text(
                                        '${b['sail_no']} – ${b['name']}'),

                                    // subtitle: smaller text under the title.
                                    // Shows class and rating
                                    subtitle: Text(
                                      '${b['class_name']} • Rating: ${b['rating_value']}',
                                    ),

                                    // trailing: widgets on the right side (club and delete icon)
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize
                                          .min, // Take only as much width as needed
                                      children: [
                                        // If the boat has a non-empty club, show it in italics
                                        if (b['club'] != null &&
                                            b['club'] != '')
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Text(
                                              b['club'],
                                              style: const TextStyle(
                                                  fontStyle:
                                                      FontStyle.italic),
                                            ),
                                          ),
                                        // The trash can icon button, to delete this boat
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline),
                                          onPressed: () =>
                                              _confirmDeleteBoat(b),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),

      // Floating 'add boat' button
      // Reference: FloatingActionButton.extended for primary action [F3]

      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _showAddBoatDialog, // When pressed, open the Add Boat dialog
        icon: const Icon(Icons.add), // "plus" icon
        label: const Text('Add boat'), // Text label next to the icon
      ),
    );
  }
}
// Summary 
// Complete fleet management interface with:
// 1. Real-time search and class filtering
// 2. CRUD operations via dialogs
// 3. Navigation to other admin pages
// 4. Clean Material Design UI with cards and icons

// Reference: StatefulWidget for async data operations [F14]
// Reference: ListView.builder for dynamic boat list [F5]
// Reference: Card and ListTile for boat display [F19][F5]
// Reference: CircleAvatar for visual identifiers [F25]
// Reference: FloatingActionButton for add action [F1]
// Reference: AlertDialog for add/edit forms [F18]
// Reference: Form validation with GlobalKey [F4]
// Reference: TextFormField with validators [F4]
// Reference: DropdownButtonFormField for class selection [F1]
// Reference: ChoiceChip for class filtering [F24]
// Reference: Dio GET/POST/PUT/DELETE methods [D1][D3]
// Reference: FastAPI CRUD endpoints [B1]
// Reference: Query parameters for filtering [B11]
// Reference: SnackBar for feedback [F7]
// Reference: Navigator for navigation [F28]
// Reference: RefreshIndicator for pull-to-refresh [F27]