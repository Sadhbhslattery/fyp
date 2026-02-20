RCYC REGATTA TIMING SYSTEM
Student: 122350191
Final Year Project


PROJECT OVERVIEW


This is a web-based regatta timing and results management system designed 
for keelboat racing at Royal Cork Yacht Club (RCYC). The system digitises the 
race management workflow, allowing race officers to manage races in real-time 
from a committee boat and competitors to view race information from their own 
boats.

The system replaces manual stopwatch timing and paper-based recording with a 
modern, synchronised digital solution optimised for outdoor use on the water.

The app was migrated from iOS to Flutter web this iteration after enrolling in 
the Apple Developer Programme was not feasible within the project timeline. The 
Flutter web app is deployed on Vercel and is accessible from any modern browser 
without requiring a device or app install.


SYSTEM ARCHITECTURE


The project consists of three main components:

1. FLUTTER FRONTEND (Dart/Flutter)
   - Flutter web application, deployed on Vercel
   - Accessible from any modern browser — no iOS device or install required
   - Dark theme optimised for outdoor visibility (reduces sun/water glare)
   - Two user types: Admin (Race Officers) and User (Competitors)
   - Real-time countdown synchronisation

2. FASTAPI BACKEND (Python)
   - RESTful API with JSON responses
   - Authentication endpoints (bcrypt password hashing via passlib)
   - Race timing endpoints
   - Results calculation endpoints
   - Start sequence broadcast endpoints
   - Sailwave CSV export functionality
   - Deployed on Railway

3. MYSQL DATABASE
   - Persistent storage for boats, courses, timings, results
   - Relational schema with foreign key constraints
   - UTC timestamp handling for accurate timing
   - Hosted on Railway


TECHNOLOGY STACK

Frontend:
  - Flutter (Dart)
  - Dio HTTP client
  - Material Design (dark theme)
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


KEY FEATURES


ADMIN (RACE OFFICER) FEATURES:
  Fleet management (add/edit/delete boats with CRUD interface)
  Course selection with start time
  Class start time configuration
  5-minute gun broadcast (synchronised countdown)
  Finish recording with timestamps
  OCS (On Course Side) ruling
  Penalty seconds assignment
  Live results calculation (elapsed and corrected times)
  Sailwave CSV export for series scoring
  Multi-class race management

USER (COMPETITOR) FEATURES:
  Competitor account signup using sail number and password
  Boat-specific dashboard
  Today's course information
  Live 5-4-1-START countdown
  Class results with own boat highlighted


ITERATION HISTORY


ITERATION 1:
  Basic fleet management (boats CRUD)
  Course selection system
  Initial database schema
  Admin/User authentication

ITERATION 2:
  Race start timing (record official start times)
  Finish recording by sail number
  Basic results calculation
  User login and boat association

ITERATION 3:
  OCS (On Course Side) rulings
  Penalty seconds support
  Sailwave CSV export
  Results display improvements

ITERATION 4:
  Dark theme for outdoor visibility
  Live start sequence countdown (5-4-1-START)
  Competitor dashboard (integrated course/countdown/results)
  Railway deployment attempted (deferred to Iteration 5)

ITERATION 5 (CURRENT):
  Flutter web deployment on Vercel — app migrated from iOS to Flutter web
    after Apple Developer Programme enrolment was not feasible within the
    project timeline: accessible from any browser without a device or install
  Railway backend live — deployment issue resolved by creating a small test
    project, deploying it to Railway, comparing its GitHub file structure to
    this project, and identifying the /backend folder configuration as the
    root cause
  Competitor authentication — auth.py introduced with bcrypt password hashing
    via passlib: schemas/auth.py introduced with four Pydantic models for all
    authentication endpoints (SignupRequest, AdminLoginRequest,
    UserLoginRequest, BoatAuthResponse)
  User testing conducted — structured testing completed with three participants
    including RCYC Race Officer Nin O'Leary and a peer sailor; feedback
    logged for Iteration 6


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
  - ocs (TINYINT: 1 = OCS, 0 = clean)
  - penalty_seconds

start_sequences:
  - id (Primary Key)
  - class_name
  - race_date
  - sequence_start_utc (timestamp)


API ENDPOINTS

AUTHENTICATION:
  POST   /signup # Competitor account creation
  POST   /boat-signup # Competitor signup (BoatAuthResponse)
  POST   /login # Admin login
  POST   /user-login # Competitor login
  POST   /boat-login # Competitor login (BoatAuthResponse)

FLEET MANAGEMENT:
  GET    /boats  # List all boats (optional ?class_name filter)
  POST   /boats  # Add new boat
  PUT    /boats/{id}  # Update boat
  DELETE /boats/{id} # Delete boat

COURSE MANAGEMENT:
  GET    /courses  # List all courses
  GET    /current-course  # Get today's selected course
  POST   /select-course  # Select course for today

TIMING:
  POST   /race-starts/class-start  # Set start time for class
  GET    /race-starts   # Get timing records for a date
  GET    /race-starts/boat  # Get start record for a specific boat
  POST   /race-starts # Set or update a single boat's start time
  POST   /race-finish  # Record finish time
  PUT    /race-penalty   # Apply OCS or penalty to a boat
  DELETE /race-day  # Reset timing records for a date

START SEQUENCE:
  POST   /start-sequence/start # Fire 5-minute gun
  GET    /start-sequence/status # Get countdown status

RESULTS:
  GET    /race-results  # Get results by class and date
  GET    /league-points # Get league points for a class and date
  GET    /export/sailwave-race-csv # Export Sailwave-compatible CSV

HEALTH:
  GET    /    # Root health check
  GET    /health  # Lightweight health check (used by Railway)


DEPLOYMENT

  Railway (FastAPI backend + MySQL database): Live
    https://web-production-9fd2e3.up.railway.app

  Vercel (Flutter web frontend): Live (deployed Iteration 5)
    Accessible from any browser at the Vercel project URL
    https://regatta-app-iota.vercel.app/



USER WORKFLOWS


RACE OFFICER WORKFLOW (Admin):

1. LOGIN
   - Navigate to the Vercel URL in a browser
   - Enter username/password (admin, password123)
   - Navigate to FleetAdminPage

2. PRE-RACE SETUP
   - Review fleet (add/edit boats if needed)
   - Tap flag icon - Select course and start time
   - POST /select-course

3. START SEQUENCE (Per Class)
   - Tap timer icon - RaceStartsPage
   - Tap class button - Set start time - POST /race-starts/class-start
   - Tap "5-min" button - Select prep flag - POST /start-sequence/start
   - Countdown displays for race officers and all competitors in browser

4. DURING RACE
   - Boats appear as "In progress" when start time passes
   - Monitor countdown on screen

5. RECORD FINISHES
   - Tap "Finish" button for each boat
   - Toggle OCS if needed
   - Enter penalty seconds if applicable
   - POST /race-finish
   - Boat moves to "Finished" section

6. POST-RACE
   - Tap table icon - RaceResultsPage
   - View results by class
   - Tap "Export to Sailwave" - Select class - Enter race number
   - CSV downloads for import into Sailwave

COMPETITOR WORKFLOW (User):

1. SIGNUP (first time only)
   - Navigate to the Vercel URL in a browser
   - Enter sail number (e.g. IRL15455) and choose a password
   - POST /boat-signup

2. LOGIN
   - Enter sail number and password
   - Navigate to UserBoatPage (personalised dashboard)
   - POST /boat-login

3. PRE-RACE
   - View boat information (name, class, rating)
   - View today's course selection
   - View start sequence countdown (when RO fires gun)

4. START SEQUENCE
   - Watch live countdown (MM:SS)
   - "STARTED" displays at 0:00

5. POST-RACE
   - View class results
   - Own boat highlighted in bold
   - See position, elapsed time, corrected time
