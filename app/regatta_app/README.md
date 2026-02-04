Project Overview
This project is a mobile-first regatta timing and results management system developed as part of my Final Year Project.
The system is designed to support Royal Cork Yacht Club (RCYC) race officers in recording race starts, finishes, penalties and results during weekly club racing.

Traditional race management tools such as Sailwave are powerful but desktop-only and not practical for use on the water or at the finish line.
This project aims to complement existing tools by providing a simple, mobile-friendly interface for live race management, while still exporting results in a format compatible with Sailwave.

This project is a race-management app built specifically for RCYC club racing. The idea is to make life easier for both the Race Officer and the sailors by replacing handwritten times, crowded WhatsApp chats, and manual Sailwave inputs with something clean, fast and reliable.
The system has two sides:
Race Officer (Admin)
    Load the fleet and ratings
    Pick today’s course
    Set class start times
    Record finish times for each individual boat
    Apply penalties
    Automatically calculate elapsed and corrected times
    View a ranked results table for each class
    Export reaults to Sailwave by CSV

Competitors (Sailors)
    Log in using their boat’s sail number and password
    Instantly see today’s course
    See results for their class
    See their own boat highlighted in the results
    This iteration focused on building an actual working race workflow, from selecting the course - starting - finishing - scoring - displaying results.

Tech Stack
Frontend (App)
Flutter (Dart)
Running on the iOS simulator (Xcode)
UI built using Flutter widgets and Material Design
I chose Flutter because it gives me one codebase for iOS and Android, and I found Dart easier to learn than Swift. It feels like a mix between Python and C#, which made it comfortable to work with.

Backend
FastAPI (Python)
SQLAlchemy ORM
MySQL (local)
REST API returning JSON
FastAPI was a good choice because it’s extremely fast to work with, very clean, and everything is typed, which makes it harder to break things accidentally.

Project Structure
This zip only includes the important files — all build folders, virtual environments and generated code have been removed, as required. All of the generated folders from Flutter and Python (build/, .dart_tool/, .venv/, pycache/ etc.) are not included.
 

Current Features (Iteration 3)

The following features have been implemented in this iteration:
Flutter-based mobile UI (iOS Simulator)
FastAPI backend with REST API
Boat and fleet management
Class-based race start times
Individual boat finish recording
Automatic elapsed time calculation
Corrected time calculation using handicap ratings
OCS and time penalty handling
Results grouped by class
CSV export compatible with Sailwave
Clear separation between “In Progress” and “Finished” boats
Reset functionality for race-day testing

ChatGPT conversations linked below that helped with Debugging:

https://chatgpt.com/c/6973c1be-7840-8386-87ba-60ebd785fcb8
https://chatgpt.com/c/6973c25b-5424-832d-ab22-5ece0d7912a1

