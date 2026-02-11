// This file is the HTTP communication layer between my Flutter app and the FastAPI backend. 
// It wraps the Dio HTTP client (a popular Dart library for making HTTP requests) 
//and provides two simple methods: start() and getStatus().

// Think of this file as a translator:
// UI pages speak Dart (className, raceDate, prepFlag)
// Backend speaks JSON ({"class_name": "...", "race_date": "..."})
// This file translates between the two

import 'package:dio/dio.dart';
// Imports the Dio package. Dio is a powerful HTTP client for Dart/Flutter that handles:
// Making GET, POST, PUT, DELETE requests
// Automatic JSON encoding/decoding
// Error handling
// Request/response interceptors
// Timeout handling
// I installed Dio by adding it to pubspec.yaml (the Flutter equivalent of Python's requirements.txt).


// StartSequenceApi is a small wrapper around Dio for the start-sequence endpoints.
// It hides the URL/paths and returns simple Dart maps so UI pages can stay clean.
class StartSequenceApi {
  // This comment explains the class's purpose: it's a "wrapper" (a layer on top of) Dio that:
  // Hides implementation details (URL paths, HTTP methods)
  // Provides a clean interface (just call start() or getStatus())
  // Returns simple Dart maps that are easy to work with
  // UI pages don't need to know HOW to call the backend - they just call these methods.

  final Dio _dio;
  // Declares a private field called _dio of type Dio.
  // final: This variable can only be set once (in the constructor) and cannot be changed later
  // Dio: The type - this field holds a Dio HTTP client instance
  // _dio: The underscore prefix makes this field private. Only code inside this file can access it.

  // This is the actual HTTP client that will make requests to my backend.

  StartSequenceApi(String baseUrl)
  // The constructor takes one parameter: baseUrl (e.g., "http://127.0.0.1:8000")
      : _dio = Dio(
        // The colon starts an "initializer list" - Dart syntax for initializing fields before the constructor body runs. 
        //This line creates a new Dio instance and assigns it to _dio.
          BaseOptions(
          // Configures the Dio client with base settings:
            baseUrl: baseUrl,
            //  Sets the base URL for all requests. When we later call _dio.post("/start-sequence/start"), 
            //Dio prepends this base URL, making the full URL: http://127.0.0.1:8000/start-sequence/start
            headers: {"Content-Type": "application/json"},
            // Sets default headers for all requests. 
            //Content-Type tells the server "I'm sending JSON data". This is required by FastAPI.
          ),
        );
  // This is the constructor - the code that runs when I create a new StartSequenceApi instance.

  // POST /start-sequence/start
  // Race Officer fires the "5 minute gun" for a class and selects the preparatory flag.
  Future<Map<String, dynamic>> start({
    // The return type:
    // Future: This is an asynchronous operation (like Python's async/await). 
    // The method returns immediately with a "promise" that will complete later.
    // Map<String, dynamic>: A dictionary/map with string keys and values of any type. 
    // This represents the JSON response from the backend.
    required String className,
    required String raceDate,
    required String prepFlag,
    // These are named parameters (like keyword arguments in Python). 
    // The "required" keyword means the caller must provide these values. 
    // The curly braces {} indicate named parameters rather than positional.
  }) async {
    final res = await _dio.post(
      "/start-sequence/start",
      data: {
        "class_name": className,
        "race_date": raceDate,
        "prep_flag": prepFlag,
      },
    );
    // await: Pauses execution here until the HTTP request completes. This is like Python's await.
    // _dio.post(...): Makes a POST request. 
    // The first argument is the path (Dio adds the baseUrl to create the full URL).
    // data: {...}: The JSON body to send. 
    // Dio automatically converts this Dart map to JSON. 
    //Notice the field names use snake_case (class_name) to match my backend's Pydantic models.

    return Map<String, dynamic>.from(res.data as Map);
    // Extracts the response data and returns it as a Map. 
    // The res.data contains the JSON response body that FastAPI sent back. 
    // We cast it to Map and create a new Map<String, dynamic> to ensure type safety.
  }

  // GET /start-sequence/status
  // Sailors poll this to see the active start sequence for their class.
  Future<Map<String, dynamic>> getStatus({
    required String className,
    required String raceDate,
  }) async {
    final res = await _dio.get(
      "/start-sequence/status",
      queryParameters: {
        "class_name": className,
        "race_date": raceDate,
      },
    );
    // _dio.get(...): Makes a GET request (for reading data, not creating/modifying).
    //queryParameters: {...}: These become URL query parameters. 
    // Dio will create: /start-sequence/status?class_name=White%20Sail%201&race_date=2025-11-14
    //(Dio automatically URL-encodes the values, so "White Sail 1" becomes "White%20Sail%201")


    return Map<String, dynamic>.from(res.data as Map);
    //Same as start() - extract and return the response data.

  }
}

// Summary of start_sequence_api.dart
//This file provides two clean methods:
// 1. start(): POST to /start-sequence/start with className, raceDate, prepFlag
// 2. getStatus(): GET from /start-sequence/status?class_name=...&race_date=...

// UI pages just call these methods and get back Dart maps containing the JSON response. 
// They don't need to know about HTTP, JSON serialization, or URL construction - that's all hidden inside this service.
// Reference: Dio package for HTTP requests [D1]
// Reference: Dio BaseOptions for client configuration [D2]
// Reference: Dio GET/POST request methods [D3]
// Reference: FastAPI backend integration [B1]
// Reference: Pydantic response model parsing [B2]