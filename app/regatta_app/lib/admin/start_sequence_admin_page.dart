// This is the race officer's interface for starting countdown sequences. It provides:
// A form to select racing class, race date, and preparatory flag
// A "5-minute gun" button that fires the start sequence
// Display of the created sequence details

import 'package:flutter/material.dart'; //  Core Flutter widgets (Scaffold, AppBar, Button, Text, etc.)
import '../services/start_sequence_api.dart'; // The HTTP service
import '../ui/flags/flag_chip.dart'; // A custom widget that displays racing flags with proper colors (Not currenlty working)

class StartSequenceAdminPage extends StatefulWidget {
  const StartSequenceAdminPage({super.key});

  @override
  State<StartSequenceAdminPage> createState() => _StartSequenceAdminPageState();
}
// This is the immutable widget class. The only method is createState(), 
// which creates the State object that holds all the actual data and logic.

class _StartSequenceAdminPageState extends State<StartSequenceAdminPage> {
  // The underscore prefix makes this class private to this file. 
  // This State class will hold all the form data, API client and UI state.
  final api = StartSequenceApi('http://127.0.0.1:8000');
  // Creates an instance of StartSequenceApi pointing to localhost:8000. This is the HTTP client that will talk to your FastAPI backend.
  // For production, I'll change this to the Railway deployment URL (e.g., 'https://your-app.railway.app').

  // The 4 classes
  final classes = const ['Spinnaker 1', 'Spinnaker 2', 'IRC 1', 'IRC 2'];
  final flags = const ['P', 'I', 'Z', 'U', 'BLACK'];
  // These are the available options for dropdowns/selection:
  // classes: the four racing divisions
  //flags: The five preparatory flags defined by racing rules


  String selectedClass = 'Spinnaker 1';
  String selectedFlag = 'P';
  // These hold the current selections. 
  // They start with default values and update when the race officer makes selections.

  // Use today's date string for now 
  String raceDate = '2026-02-04';
  // The current race date in YYYY-MM-DD format. This is editable via a text field. 
  // In a more polished version, I will integrate with my race selection page to automatically use today's date.

  Map<String, dynamic>? latest;
  String? error;
  bool loading = false;

  // latest: Holds the response from the backend after starting a sequence (null until first success)
  // error: Holds error message if API call fails (null when no error)
  // loading: true while API request is in progress, false otherwise

  Future<void> fireFiveMinuteGun() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await api.start(
        className: selectedClass,
        raceDate: raceDate,
        prepFlag: selectedFlag,
      );
      setState(() => latest = res);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }
  // This method fires when the race officer presses the "5-minute gun" button.
  // setState(() { loading = true; error = null; }): Updates the UI state to show loading indicator and clear any previous error
  // await api.start(...): Calls the backend endpoint, waits for response
  // setState(() => latest = res): On success, stores the response and triggers UI rebuild
  // catch (e): If error occurs, stores error message
  // finally: Always sets loading = false when done

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Sequence (Admin)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Race date (YYYY-MM-DD)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // Scaffold is Flutter's basic screen structure with AppBar and body. 
              // SafeArea ensures content doesn't overlap with system UI (notch, status bar).
              TextFormField(
                initialValue: raceDate,
                onChanged: (v) => setState(() => raceDate = v.trim()),
              ),
              // A text input field. onChanged fires whenever the user types, 
              // updating raceDate and rebuilding the UI.

              const SizedBox(height: 16),
              Text('Select class', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedClass,
                items: classes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedClass = v ?? selectedClass),
              ),
              // A dropdown with the four racing classes. When selection changes, updates selectedClass.

              const SizedBox(height: 16),
              Text('Preparatory flag', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: flags.map((f) {
                  final selected = selectedFlag == f;
                  return ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => selectedFlag = f),
                  );
                }).toList(),
              ),
              // Creates a row of chips (P, I, Z, U, BLACK) where the selected one is highlighted.

              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: loading ? null : fireFiveMinuteGun,
                child: Text(loading ? 'Firing…' : '5-minute gun (START SEQUENCE)'),
              ),
              // The main action button. When loading is true, onPressed is null (button disabled). 
              // The text changes to show loading state.

              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],

              if (latest != null) ...[
                const SizedBox(height: 18),

                FlagChip(
                  flagCode: latest?["prep_flag"],
                  label: 'Broadcast flag: ${latest?["prep_flag"]}',
                ),

                const SizedBox(height: 10),

                Text('Class: ${latest?["class_name"]}'),
                Text('Race date: ${latest?["race_date"]}'),
                Text('Sequence start (UTC): ${latest?["sequence_start_utc"]}'),
                Text('Server time (UTC): ${latest?["server_time_utc"]}'),
            ],
            // Conditionally shows error message (if error != null) or success details (if latest != null), including the flag chip and sequence information.

            ],
          ),
        ),
      ),
    );
  }
}

// Summary 
// This page provides a form-based interface for starting sequences:
// 1. Race officer selects class, date, and flag
// 2. Presses "5-minute gun" button
// 3. App calls api.start(), sends data to backend
// 4. Backend creates sequence record and returns confirmation
// 5. App displays success message with sequence details

// The UI automatically handles loading states, errors and success display.


// Reference: StatefulWidget lifecycle management [F14]
// Reference: Form validation with TextFormField [F4]
// Reference: DropdownButtonFormField for class selection [F1]
// Reference: ChoiceChip for preparatory flag selection [F24]
// Reference: AlertDialog for user confirmations [F18]
// Reference: SnackBar for success/error feedback [F7]
// Reference: Navigator for screen transitions [F28]