RCYC REGATTA TIMING SYSTEM
Student: 122350191
Final Year Project


Project overview


This is a web-based regatta timing and results management system designed 
for keelboat racing at Royal Cork Yacht Club (RCYC). The system digitises the 
race management workflow, allowing race officers to manage races in real-time 
from a committee boat and competitors to view race information from their own 
boats.

The system replaces manual stopwatch timing and paper-based recording with a 
modern, synchronised digital solution optimised for outdoor use on the water.

The app was migrated from iOS to Flutter web in Iteration 5 after enrolling in 
the Apple Developer Programme was not feasible within the project timeline. The 
Flutter web app is deployed on Vercel and is accessible from any modern browser 
without requiring a device or app install.


System Architecture

The project consists of three main components:

1. Flutter Frontend (Dart/Flutter)
   - Flutter web application, deployed on Vercel
   - Accessible from any modern browser — no iOS device or install required
   - Dark nautical theme optimised for outdoor visibility (reduces sun/water glare)
   - Two user types: Admin (Race Officers) and User (Competitors)
   - Real-time countdown synchronisation with 1-second tick timer
   - Three-state competitor Race Status Card (scheduled time / countdown / elapsed timer)
   - Auto-fire 5-minute gun based on scheduled class start times
   - Race check-in system for competitors

2. FastAPI Backend(Python)
   - RESTful API with JSON responses
   - Authentication endpoints (bcrypt password hashing via passlib)
   - Race timing endpoints
   - Results calculation endpoints
   - Start sequence broadcast endpoints
   - Check-in endpoints
   - Sailwave CSV export functionality (supports all World Sailing result codes)
   - Deployed on Railway

3. MySQL Database
   - Persistent storage for boats, courses, timings, results, check-ins
   - Relational schema with foreign key constraints
   - UTC timestamp handling for accurate timing
   - Hosted on Railway


Technology Stack

Frontend:
  - Flutter (Dart)
  - Dio HTTP client
  - Material Design (dark nautical theme)
  - Vercel (deployment)

Backend:
  - FastAPI (Python 3.12)
  - Pydantic (data validation)
  - SQLAlchemy (ORM)
  - passlib / bcrypt (password hashing)
  - python-dotenv (environment config)
  - Railway (deployment)

Database:
  - MySQL 8.0 (hosted on Railway)

Development Tools:
  - VS Code
  - Chrome (Flutter web debugging)
  - MySQL Workbench
  - Railway dashboard
  - Vercel dashboard
  - Git


Key Features 


ADMIN (RACE OFFICER) Features:
  Fleet management (add/edit/delete boats with CRUD interface)
  Course selection with start time
  Class start time configuration (per-class, e.g. White Sail 1 at 11:00, Spinnaker 1 at 11:10)
  Auto-fire 5-minute gun (fires automatically when scheduled, manual fallback available)
  5-minute gun broadcast (synchronised countdown with sequence restoration on page re-entry)
  Finish recording with timestamps
  Result codes: Normal Finish, OCS, DNS, DNF, RET, DSQ, BFD (World Sailing standard)
  Penalty seconds assignment
  Live results calculation (elapsed and corrected times)
  Sailwave CSV export for series scoring (all result codes supported)
  Multi-class race management
  Check-in overview (see which competitors are racing per class)
  Reset race day (clears all timing, check-ins, and start sequences)

USER (COMPETITOR) Features:
  Competitor account signup using sail number and password
  Boat-specific dashboard
  Race check-in ("Racing today?" dialog on login)
  Three-state Race Status Card:
    - Before gun: scheduled class start time (or general course time as fallback)
    - During countdown: live MM:SS countdown with phase labels (5-min / 4-min / 1-min)
    - After start: elapsed HH:MM:SS timer (freezes to official time when admin records finish)
  Today's course information with per-class start time ("Your start: 11:00")
  Live 5-4-1-START countdown
  Class results with own boat highlighted in bold
  Result code display (OCS, DNF, DNS, RET, DSQ, BFD)


DATABASE SCHEMA


TABLES:

boats:
  - id (Primary Key)
  - sail_no (Unique)
  - name
  - club
  - class_name (White Sail 1/2, Spinnaker 1/2)
  - rating_value (handicap rating)
  - owner_password (bcrypt hash, introduced Iteration 5)

race_day_settings:
  - race_date (Primary Key)
  - course_id (Foreign Key)
  - start_time

race_starts:
  - id (Primary Key)
  - boat_id (Foreign Key)
  - race_date
  - start_time
  - finish_time
  - elapsed_seconds
  - corrected_seconds
  - ocs (TINYINT: 1 = OCS, 0 = clean — kept for backward compatibility)
  - result_code (VARCHAR: "OCS", "DNF", "DNS", "RET", "DSQ", "BFD" or NULL for normal finish)
  - penalty_seconds

start_sequences:
  - id (Primary Key)
  - class_name
  - race_date
  - sequence_start_utc (timestamp)

check_ins (NEW — Iteration 6):
  - id (Primary Key)
  - boat_id (Foreign Key → boats.id)
  - race_date
  - checked_in_at (timestamp)


API ENDPOINTS

AUTHENTICATION:
  POST   /signup # Competitor account creation
  POST   /boat-signup # Competitor signup (BoatAuthResponse)
  POST   /login # Admin login
  POST   /user-login # Competitor login
  POST   /boat-login # Competitor login (BoatAuthResponse)

FLEET MANAGEMENT:
  GET    /boats # List all boats (optional ?class_name filter)
  POST   /boats # Add new boat
  PUT    /boats/{id}  # Update boat
  DELETE /boats/{id} # Delete boat (also removes check-ins)

COURSE MANAGEMENT:
  GET    /courses # List all courses
  GET    /current-course # Get today's selected course
  POST   /select-course # Select course for today

TIMING:
  POST   /race-starts/class-start  # Set start time for class
  GET    /race-starts # Get timing records for a date
  GET    /race-starts/boat # Get start record for a specific boat (includes finish_time, elapsed_seconds)
  POST   /race-starts # Set or update a single boat's start time
  POST   /race-finish # Record finish time (with result_code and penalty_seconds)
  PUT    /race-penalty  # Apply OCS or penalty to a boat
  DELETE /race-day  # Reset timing records, check-ins, and start sequences for a date

START SEQUENCE:
  POST   /start-sequence/start # Fire 5-minute gun
  GET    /start-sequence/status # Get countdown status (returns sequence_start_utc, server_time_utc)

CHECK-IN (NEW — Iteration 6):
  POST   /check-in  # Competitor confirms racing today
  DELETE /check-in # Competitor cancels check-in
  GET    /check-ins # Get all check-ins for a date (with boat details)

RESULTS:
  GET    /race-results # Get results by class and date (includes result_code)
  GET    /league-points  # Get league points for a class and date
  GET    /export/sailwave-race-csv # Export Sailwave-compatible CSV (all result codes supported)

HEALTH:
  GET    / # Root health check
  GET    /health   # Lightweight health check (used by Railway)


DEPLOYMENT

  Railway (FastAPI backend + MySQL database): Live
    https://web-production-9fd2e3.up.railway.app
    https://railway.com/project/1b12c1cf-48d5-4aad-a8ae-15313597d069/service/bc4a1910-ec3c-489c-9a47-517c564f1075?environmentId=4ef45ced-35e6-4d8a-904a-708788fa6846
    
  Vercel (Flutter web frontend): Live
    https://regatta-app-iota.vercel.app/
