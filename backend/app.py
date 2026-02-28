"""
app.py is the main backend file. It creates HTTP endpoints (URLs) that this Flutter app calls to interact with the database. 
This is where all the business logic lives.

File Structure Overview

app.py is organized into these sections:
• Imports and setup 
• Database dependency 
• Health check endpoints 
• Admin login 
• Race management 
• Course selection 
• Boat CRUD operations 
• Race timing (start/finish recording) 
• Results and penalties 
• CSV export for Sailwave 
• League points calculation 
• Race day reset 

Reference: FastAPI application structure [B1]
Reference: FastAPI with SQL Databases tutorial [B2]

"""

import csv 
# Python's built-in CSV library for creating CSV files.
# csv.writer() writes rows of data as comma-separated text into any file-like
# object — in this app that is the in-memory StringIO buffer below.
# Reference: Python csv module [B19]

import io 
# Provides StringIO for creating in-memory text buffers.
# StringIO behaves exactly like a file but exists only in memory, so the CSV
# can be built and streamed without writing anything to disk.
# Reference: Python io module [B20]

from fastapi.responses import StreamingResponse  
# Used to send file downloads to the client.
# StreamingResponse streams the CSV buffer directly to the browser and sets
# the Content-Type and Content-Disposition headers so the browser treats the
# response as a file download rather than inline content.
# Reference: FastAPI StreamingResponse for file/CSV downloads [B8]
# Reference: Starlette responses [B9]

from datetime import datetime, date, time, timedelta 
# Python's standard date/time handling library
# datetime  – combined date and time object (used to compute elapsed seconds)
# date – date only (race_date fields throughout the app)
# time – time only (start_time and finish_time fields)
# timedelta – represents a duration; used to handle races that cross midnight
# Reference: Python datetime module [B5]

#  FASTAPI and Pydantic 

from fastapi import FastAPI, Depends, HTTPException
# FastAPI – the main web framework class; instantiated as `app` below
# Depends – dependency injection mechanism used with get_db() so every
#            endpoint that needs a database session receives one automatically
# HTTPException – raised to return HTTP error responses (404, 400, 401, etc.)
#               FastAPI converts these into JSON error bodies automatically
# Reference: FastAPI basic app, middleware and CORS setup [B1]

from fastapi.middleware.cors import CORSMiddleware
# CORS (Cross-Origin Resource Sharing) middleware.
# Without this, browsers block the Flutter web app (on Vercel) from calling
# the FastAPI backend (on Railway) because they are on different origins.
# allow_origins=["*"] permits requests from any origin, which is acceptable
# for this project. In production this would be restricted to the Vercel domain.
# Reference: Starlette CORS middleware [B13]

from pydantic import BaseModel, field_validator
# BaseModel  – base class for all request and response schemas.
#               Subclassing it gives automatic JSON parsing, type coercion,
#                  and validation. FastAPI uses these to validate request bodies
#                  and serialise response bodies.
# field_validator – decorator for adding custom validation to a specific field,
#                  e.g. ensuring class_name is one of the allowed fleet options.
# Reference: Pydantic models and validators [B3]

# SQLAlchemy ORM 
# Reference: SQLAlchemy sessions & ORM patterns [B2][B4]
from sqlalchemy.orm import Session
# Session is the SQLAlchemy database session type.
# Used as a type hint in endpoint signatures so IDEs and type checkers
# understand what the `db` parameter is.
# Reference: SQLAlchemy ORM sessions [B4]

from db import Base, engine, SessionLocal
# Base – the declarative base class all ORM models inherit from.
#         Base.metadata.create_all(engine) below generates CREATE TABLE
#         statements for every model.
# engine – the SQLAlchemy connection to the MySQL database on Railway,
#           built in db.py from the DATABASE_URL environment variable.
# SessionLocal – factory that creates new database sessions on demand;
#                called inside get_db() to open one fresh session per request.
# Reference: SQLAlchemy engine and session factory [B4]
# Reference: FastAPI SQL database tutorial [B2]

from models.base import Race, Event, Boat, RaceStart, RaceDaySettings, Entry, CheckIn
# Imports the ORM model classes defined in models/base.py.
# Each class maps to a MySQL table and is used to query and modify data.
# Race  – the races table (not heavily used in this iteration)
# Event – placeholder model for future use
# Boat – the boats table (sail_no, class_name, rating_value, owner_password)
# RaceStart – the race_starts table (per-boat, per-day timing: start_time,
#                   finish_time, elapsed_seconds, corrected_seconds, OCS flag, penalties)
# RaceDaySettings – the race_day_settings table (today's selected course and start time)
# Reference: SQLAlchemy declarative ORM models [B4]

from routes.start_sequence import router as start_sequence_router
# Imports a router for start sequence endpoints defined in a separate file.
# Keeping these endpoints in their own file (routes/start_sequence.py) avoids
# cluttering app.py and follows FastAPI's recommended modular routing pattern.
# Reference: FastAPI APIRouter for modular routing [B1]

# Authentication Imports

from schemas.auth import SignupRequest, AdminLoginRequest, UserLoginRequest, BoatAuthResponse
# Imports the four Pydantic schemas introduced this iteration in schemas/auth.py.
# These provide structured request validation and response models for all
# authentication endpoints, replacing ad-hoc dict handling in earlier iterations.

#   SignupRequest – body for POST /signup and POST /boat-signup
#                   Fields: sail_no (str), password (str), owner_name (Optional[str])
#   AdminLoginRequest – body for POST /login (race officer)
#                       Fields: username (str), password (str)
#   UserLoginRequest – body for POST /user-login (competitor)
#                      Fields: sail_no (str), password (str)
#   BoatAuthResponse – response for POST /boat-signup and /boat-login
#                      Fields: success (bool), message (str), boat (dict or None)

# Using Pydantic schemas means FastAPI returns HTTP 422 Unprocessable Entity
# automatically if required fields are missing, rather than crashing.
# Reference: Pydantic v2 models [B3]
# Reference: FastAPI request body and response_model [B1]
# Reference: schemas/auth.py (this project)

from auth import hash_password, verify_password
# Imports the two password utility functions introduced this iteration in auth.py.
# These replace the plain-text password storage used in earlier iterations.

#   hash_password(password: str) - str
#       Converts a plain-text password into a bcrypt hash string (e.g. "$2b$12$...")
#       using passlib's CryptContext. The hash is stored in Boat.owner_password.
#       bcrypt is deliberately slow and salted, making brute-force attacks
#       computationally expensive.
#
#   verify_password(plain: str, stored: str) - bool
#       Re-hashes the plain-text password using the salt embedded in the stored
#       hash and compares in constant time, preventing timing attacks.
#       Also handles a legacy plain-text fallback for boats registered before
#       bcrypt was introduced.
#
# Reference: passlib bcrypt [B15]
# Reference: bcrypt algorithm design [B16]
# Reference: auth.py (this project)

# Application Setup

app = FastAPI()
# Creates the main FastAPI application instance.
# This object handles all HTTP request routing and middleware configuration.
# Reference: FastAPI application initialisation [B1]

app.include_router(start_sequence_router)
# Adds the start_sequence router to the app, making its endpoints available.
# After this call, all routes defined in routes/start_sequence.py (e.g.
# POST /start-sequence/start) are served by this application.
# Reference: FastAPI APIRouter inclusion [B1]

app.add_middleware(
    # Configures CORS (Cross-Origin Resource Sharing)
    CORSMiddleware,
    allow_origins=["*"], 
    # Allows requests from any origin — permits the Flutter web app on Vercel
    # to call this backend on Railway without browser security blocking it.
    allow_methods=["*"], # Allow all HTTP methods (GET/POST/PUT/DELETE,…)
    allow_headers=["*"], # Allow all headers (e.g. Content-Type, Authorisation)
)
# Reference: Starlette CORS middleware [B13]

Base.metadata.create_all(engine)
# This is critical! It tells SQLAlchemy to:
#   1. Look at all models that inherit from Base (Race, Boat, RaceStart, etc.)
#   2. Generate CREATE TABLE SQL statements for each model
#   3. Execute those statements on the MySQL database via the engine
#
# If a table already exists, SQLAlchemy skips it and will not overwrite data.
# This runs once when the app starts on Railway, ensuring all required tables
# exist before any HTTP requests arrive.
# Reference: SQLAlchemy engine and create_all to create tables [B4]


# Database Session Dependency

# Reference: FastAPI dependency injection with Depends [B1][B2]
def get_db():
    """
    FastAPI dependency that opens a database session for each request
    and guarantees it is closed when the request finishes.

    Usage in endpoints:
        def endpoint(db: Session = Depends(get_db)):
            ...

    This pattern:
      Opens a new session at the start of the request
      Yields it to the route handler
      Ensures the session is closed when finished, even on errors

    The 'yield' keyword makes this a generator function.
    It pauses execution, hands the 'db' session to the endpoint, and resumes
    after the endpoint finishes. The 'finally' block ensures the session is
    closed even if an unhandled exception occurs.

    Reference: FastAPI dependency injection with Depends [B1]
    Reference: SQLAlchemy session-per-request pattern [B2][B4]
    """
    db = SessionLocal()
    # Creates a new database session using the SessionLocal factory from db.py.
    # This opens a connection to the Railway MySQL database.
    try:
        yield db 
        # Pauses here and gives db to the endpoint.
        # FastAPI resumes here once the endpoint function returns.
    finally:
        db.close() 
        # Always closes the session when done — releases the connection back
        # to the connection pool. Runs even if the endpoint raised an error.



# Healtth Check Endpoints

# Reference: Simple JSON responses in FastAPI path operations [B1]

@app.get("/")
def root():
    """
    Simple root endpoint to check the backend is running.

    Called during development to verify the server started successfully,
    and by Railway to confirm the container is responding to requests.

    Returns:
        {"message": "Backend is running"}
    """
    return {"message": "Backend is running"}
    # FastAPI automatically converts this Python dict to a JSON response
    # with Content-Type: application/json and HTTP 200 OK.
    # Reference: FastAPI path operations returning JSON [B1]


@app.get("/health")
def health():
    """
    Lightweight health check endpoint for monitoring and sanity checks.

    Railway calls this endpoint periodically to confirm the app is alive.
    Returns a minimal payload to keep the response fast.

    Returns:
        {"ok": True}
    """
    return {"ok": True}


# Admin Login

class LoginRequest(BaseModel):
    """
    Request model for admin login via POST /login.

    Pydantic validates that both fields are present and are strings.
    FastAPI returns HTTP 422 Unprocessable Entity if either is missing.

    Fields:
        username: admin username string
        password: admin password string

    Reference: Pydantic BaseModel [B3]
    Reference: FastAPI request body models [B1]
    """
    username: str
    password: str


class LoginResponse(BaseModel):
    """
    Response model for admin login.

    Fields:
        success: True if login credentials were accepted, False otherwise
        message: human-readable outcome description shown in the Flutter UI

    Reference: Pydantic BaseModel [B3]
    Reference: FastAPI response_model [B1]
    """
    success: bool
    message: str

# Reference: SQLAlchemy ORM Models Tutorial (for how we might later store users)
# Reference: FastAPI request body models and response_model [B1][B3]


# signup - introduced this iteration (5) to allow competitors to create
# a password-protected account linked to their existing boat record.
@app.post("/signup")
def signup(payload: SignupRequest, db: Session = Depends(get_db)):
    """
    POST /signup — Create a competitor account for an existing boat.

    The race officer must have already added the boat's sail number to the
    fleet before a competitor can sign up. Steps:
      1. Look up the Boat row by sail_no — return 404 if not found.
      2. Return 400 if the boat already has a password set.
      3. Hash the password with bcrypt via hash_password().
      4. Store the hash in Boat.owner_password.
      5. Optionally store the owner's name in Boat.owner_name.
      6. Commit and return a success message.

    Args:
        payload: SignupRequest body (sail_no, password, optional owner_name)
        db: database session injected by Depends(get_db)

    Returns:
        {"message": "Account created"} on success.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM query, filter, commit [B4]
    Reference: passlib hash_password() via auth.py [B15][B16]
    Reference: schemas/auth.py SignupRequest [B3]
    """
    boat = db.query(Boat).filter(Boat.sail_no == payload.sail_no).first()
    # Query the boats table for a row whose sail_no matches the supplied value.
    # .first() returns the first matching Boat ORM object, or None if not found.
    # Reference: SQLAlchemy ORM query and filter [B4]

    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")
        # HTTP 404 Not Found — sail number is not registered in the fleet.
        # The competitor must ask the race officer to add their boat first.
        # Reference: FastAPI HTTPException [B1]

    if boat.owner_password:
        raise HTTPException(status_code=400, detail="Account already exists")
        # HTTP 400 Bad Request — a password is already stored for this boat.
        # The competitor should use the login endpoint instead.

    boat.owner_password = hash_password(payload.password)
    # hash_password() converts the plain-text password into a bcrypt hash string
    # (e.g. "$2b$12$...") which is safe to store in the database.
    # The original plain-text password is never stored.
    # Reference: auth.py hash_password() [B15][B16]

    if payload.owner_name:
        boat.owner_name = payload.owner_name
        # Only update owner_name if the competitor provided one.
        # owner_name is Optional in SignupRequest (defaults to None).

    db.commit()
    # Writes the hashed password and optional owner_name to MySQL.
    # Reference: SQLAlchemy session commit [B4]

    return {"message": "Account created"}
    # The Flutter SignupPage displays this message in a SnackBar before
    # navigating back to the login screen.

@app.post("/login", response_model=LoginResponse)
def login(body: AdminLoginRequest):
    """
    POST /login — Authenticate the race officer (admin).

    Right now this does NOT check a database. It just verifies:
      username = "admin" and password = "password123"

    In a later iteration this can be replaced with a proper User table and hashing.

    Args:
        body: AdminLoginRequest containing username and password

    Returns:
        LoginResponse with success=True if credentials match, False otherwise.

    Reference: FastAPI POST endpoint with response_model [B1]
    Reference: Pydantic response model [B3]
    Reference: schemas/auth.py AdminLoginRequest [B3]
    """
    if body.username == "admin" and body.password == "password123":
        # Python's `and` short-circuits: if username is wrong the password
        # comparison is never evaluated.
        return LoginResponse(success=True, message="Login successful")
            # FastAPI validates this against response_model=LoginResponse before sending.
    else:
        return LoginResponse(success=False, message="Invalid credentials")
        # Returns HTTP 200 OK with success=False rather than an HTTP error code.
        # The Flutter LoginPage checks the success flag to decide what to show.

@app.post("/user-login")
def user_login(payload: UserLoginRequest, db: Session = Depends(get_db)):
    """
    POST /user-login — Authenticate a competitor using sail number and password.

    Steps:
      1. Look up the Boat row by sail_no — return 401 if not found
         (same message as wrong password to avoid revealing which field was wrong).
      2. Return 401 if no password has been set (competitor must sign up first).
      3. Return 401 if the stored value is not a bcrypt hash (needs re-signup).
      4. Verify the password against the stored hash — return 401 if wrong.
      5. Return the boat object on success for the Flutter app to store in memory.

    Args:
        payload: UserLoginRequest containing sail_no and password
        db: database session injected by Depends(get_db)

    Returns:
        JSON with success, message, and boat fields on successful login.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM query and filter [B4]
    Reference: passlib verify_password() via auth.py [B15]
    Reference: schemas/auth.py UserLoginRequest [B3]
    """
    boat = db.query(Boat).filter(Boat.sail_no == payload.sail_no).first()
    # Query the boats table for the matching sail number.
    # Reference: SQLAlchemy ORM query and filter [B4]
    if not boat:
        raise HTTPException(status_code=401, detail="Invalid sail number or password")
        # HTTP 401 Unauthorised.
        # Using the same message whether sail_no or password is wrong prevents
        # an attacker from determining which field was incorrect.

    if not boat.owner_password:
        raise HTTPException(status_code=401, detail="No password set. Please sign up first.")
        # The boat exists in the fleet but the competitor has not signed up yet.
        # owner_password is NULL in the database.

    if not str(boat.owner_password).startswith("$2"):
        raise HTTPException(status_code=401, detail="Password needs reset. Please sign up again.")
        # A bcrypt hash always begins with "$2a$", "$2b$" or "$2y$".
        # If the stored value does not start with "$2" it is a legacy plain-text
        # password from an earlier iteration — the competitor must re-sign-up.
        # Reference: bcrypt hash prefix conventions [B16]

    if not verify_password(payload.password, boat.owner_password):
        raise HTTPException(status_code=401, detail="Invalid sail number or password")
        # verify_password() re-hashes the supplied password using the salt
        # embedded in the stored hash and compares in constant time.
        # Returns False if the passwords do not match.
        # Reference: auth.py verify_password() [B15]

    return {
        "success": True,
        "message": "Login successful",
        "boat": {
            "id": boat.id,
            # Primary key — used by Flutter in subsequent API calls
            # (e.g. GET /race-starts/boat?boat_id=...).
            "sail_no": boat.sail_no,
            # Displayed in the competitor dashboard header.
            "name": boat.name,
            # Boat name, e.g. "Prince of Tides".
            "club": boat.club,
            # Club name, e.g. "RCYC".
            "class_name": boat.class_name,
            # Fleet division, e.g. "White Sail 1" — used to filter results.
            "rating_value": boat.rating_value,
            # Handicap coefficient for corrected time calculation.
        }
        # FastAPI serialises this dict to JSON automatically.
        # The Flutter UserLoginPage stores this boat dict in memory and passes
        # it to UserBoatPage via the Navigator route arguments.
    }

# Race Manamgement 
# Reference: Pydantic models for races; FastAPI POST/GET endpoints [B1][B3]

class RaceIn(BaseModel):
    """
    Input model for creating a Race record via POST /races.

    Fields:
        name: race name string (e.g. "Wednesday Evening Race 1")
        start_time: optional datetime for the planned race start

    Reference: Pydantic BaseModel [B3]
    Reference: Python datetime [B5]
    """
    name: str
    start_time: datetime| None = None
    # The | None = None syntax (Python 3.10+ union syntax) means the field
    # can be a datetime object or absent/null in the JSON body.
    # Reference: Python datetime [B5]



class RaceOut(BaseModel):
    """
    Output model returned by POST /races and GET /races.

    Fields:
        id: auto-generated database primary key
        name: race name
        status: current race state — "PLANNED", "RUNNING" or "COMPLETED"

    Reference: Pydantic BaseModel [B3]
    Reference: FastAPI response_model [B1]
    """
    id: int
    name: str
    status: str

    class Config:
        from_attributes = True
        # from_attributes=True tells Pydantic it can build this model directly
        # from a SQLAlchemy ORM object (a Race instance) rather than a plain dict.
        # Without this Pydantic cannot read ORM attributes directly.
        # Reference: Pydantic from_attributes (ORM mode) [B3]

@app.post("/races", response_model=RaceOut)
def create_race(body: RaceIn, db: Session = Depends(get_db)):
    """
    POST /races — Create a new Race record in the database.

    Steps:
      1. Construct Race ORM object with default status "PLANNED"
      2. Add to session, commit, refresh (so it has an id)
      3. Return it as a RaceOut response

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM add, commit, refresh [B4]
    """
    r = Race(name=body.name, start_time=body.start_time, status="PLANNED")
    # Constructs a Race ORM instance. The id is not set here — MySQL generates
    # it automatically as an auto-increment integer on INSERT.
    db.add(r)
    # Stages the new Race instance for insertion into the races table.
    db.commit()
    # Executes the INSERT statement and commits the transaction.
    db.refresh(r)
    # Reloads `r` from the database so auto-generated fields (like id)
    # are available on the Python object.
    return r
    # FastAPI serialises this Race ORM object using RaceOut.


@app.get("/races", response_model=list[RaceOut])
def list_races(db: Session = Depends(get_db)):
    """
    GET /races — Return all races from the Race table.

    Reference: FastAPI GET endpoint [B1]
    Reference: SQLAlchemy ORM query all [B4]
    """
    return db.query(Race).all()
    # db.query(Race) builds a SELECT * FROM races statement.
    # .all() executes it and returns a list of Race ORM objects.
    # FastAPI serialises each one using RaceOut.



# Static Courses

# Reference: FastAPI path operations returning Pydantic models [B1][B3]

# These come from the RCYC course card and are used by the UI so the race
# officer can select today's course. They are hard-coded because they do not
# change during a season and do not need to be edited in the app.
# Reference: Royal Cork Yacht Club Course Card [RCYC1]

COURSES = [
    {
        "id": 1,
        "name": "Course 1",
        "wind": "S/SW or N/NE",
        "description": "Admiral’s Choice.",
        "rounds": [
            "ROUND ONE: Ringabella (P) – W2 (P) – Cage (S) (6nm)",
            "ROUND TWO: No.7 (S) – Cage (P) (8nm)",
            "ROUND THREE: Dosco (P) – Finish. (9.8nm)",
        ],
    },
    {
        "id": 2,
        "name": "Course 2",
        "wind": "S/SW or N/NE",
        "description": "Vice Admiral’s Choice.",
        "rounds": [
            "ROUND ONE: Dutchman Mark (P) – W2 (P) – Cage (S) (4nm)",
            "Note: Dutchman mark is a laid club racing mark SE of Dutchman Rock / Fennels Bay.",
            "ROUND TWO: No.7 (S) – Cage (P) (6nm)",
            "ROUND THREE: Dosco (P) – Finish. (8nm)",
        ],
    },
    {
        "id": 3,
        "name": "Course 3",
        "wind": "S/SE or N/NW",
        "description": "Rear Admiral’s Choice.",
        "rounds": [
            "ROUND ONE: Harp Mark (P) – E1 (P) – Cage (S) (8nm)",
            "ROUND TWO: No.7 (S) – Cage (P) (10nm)",
            "ROUND THREE: Dosco (P) – Finish. (12nm)",
        ],
    },
]
# Each dict contains:
#   id – used by SelectCourseRequest to identify the chosen course
#   name – displayed in the Flutter course selector dropdown
#   wind – recommended wind direction from the RCYC course card
#   description – the admiral label (Admiral's / Vice / Rear)
#   rounds – list of strings describing each leg of the course


class CourseModel(BaseModel):
    """
    Pydantic model describing a course entry.

    Fields mirror the dictionaries in COURSES above. Used as the response
    model for GET /courses and as a nested object inside CurrentCourse.

    Reference: Pydantic BaseModel [B3]
    """
    id: int
    name: str
    wind: str
    description: str
    rounds: list[str]
    # list[str] — Pydantic validates that every element in the list is a string.

class SelectCourseRequest(BaseModel):
    """
    Request body for selecting today's course via POST /select-course.

    Fields:
        course_id:  which of the static COURSES to select (1, 2, or 3)
        start_time: race start time as free-form string ("18:30", etc.)

    Reference: Pydantic BaseModel [B3]
    Reference: FastAPI request body [B1]
    """
    course_id: int
    # Example formats: "18:30" or "2025-07-01 18:30"
    start_time: str | None = None
    # Stored as a plain string for flexibility — the race officer may type
    # the time in different formats on different days.


class CurrentCourse(BaseModel):
    """
    Model representing the currently selected course for the race day.

    Returned by POST /select-course and GET /current-course.
    The Flutter app reads this to display today's course on the admin page
    and the competitor dashboard.

    Fields:
        course: the CourseModel details (name, wind, description, rounds)
        start_time: optional start time string
        race_date: today's date, serialised as "YYYY-MM-DD" in JSON

    Reference: Pydantic BaseModel [B3]
    Reference: Python date type [B5]
    """
    course: CourseModel
    # Nested Pydantic model — serialised as a nested JSON object.
    start_time: str | None = None
    race_date: date
    # Python date is serialised by Pydantic as an ISO 8601 "YYYY-MM-DD" string.


# This variable holds the current selected course in memory.
# It is updated by /select-course and read by /current-course and the Flutter app.
# Now superseded by database persistence (RaceDaySettings table) so the
# selection survives server restarts and is accessible from any device.
current_course: CurrentCourse | None = None


@app.get("/courses", response_model=list[CourseModel])
def list_courses():
    """
    GET /courses — Return a list of all predefined RCYC courses.

    No database query is needed — the courses are hard-coded in COURSES above.
    The Flutter course selector calls this endpoint to populate its dropdown.

    The list is built by converting each dictionary in COURSES into a
    CourseModel using keyword unpacking (**c).

    Reference: FastAPI GET endpoint [B1]
    Reference: Python list comprehensions and dict unpacking [B21]
    """
    return [CourseModel(**c) for c in COURSES]
    # **c unpacks each dict as keyword arguments to CourseModel's constructor.
    # Reference: Python dict unpacking [B21]



@app.post("/select-course", response_model=CurrentCourse)
def select_course(body: SelectCourseRequest, db: Session = Depends(get_db)):
    """
    POST /select-course — Admin picks today's race course.

    Stored in the DB so it persists for backup/deputy device and server restarts.
    Uses an upsert pattern: if a RaceDaySettings row exists for today, update it;
    otherwise create a new row.

    Args:
        body: SelectCourseRequest with course_id and optional start_time
        db: database session

    Returns:
        CurrentCourse with the selected course details, start time, and date.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM get, add, commit (upsert pattern) [B4]
    Reference: Python date.today() [B5]
    """
    course_data = next((c for c in COURSES if c["id"] == body.course_id), None)
    # next() with a generator expression finds the first dict in COURSES whose
    # id matches body.course_id. Returns None if no match found.
    # Reference: Python built-in next() [B21]

    if not course_data:
        raise HTTPException(status_code=404, detail="Course not found") 
            # The supplied course_id does not match any of the three RCYC courses.

    today = date.today()
    # Gets today's date from the system clock.
    # Used as the primary key for the RaceDaySettings row.
    # Reference: Python date.today() [B5]

    # Upsert settings row for today
    existing = db.get(RaceDaySettings, today)
    # db.get() looks up a row by primary key (today's date).
    # Returns the ORM object if found, or None if no row exists for today.
    # Reference: SQLAlchemy session.get() [B4]
    if existing:
        existing.course_id = body.course_id
        existing.start_time = body.start_time
        # Update the existing row's fields in place.
        # SQLAlchemy tracks these changes and includes them in the next commit.
    else:
        existing = RaceDaySettings(
            race_date=today,
            course_id=body.course_id,
            start_time=body.start_time,
        )
        db.add(existing)
        # Create a new RaceDaySettings row and stage it for insertion.

    db.commit()
    # Writes the INSERT or UPDATE to MySQL.

    return CurrentCourse(
        # Wraps the raw course dict into a CourseModel Pydantic object.
        course=CourseModel(**course_data),
        start_time=existing.start_time,
        race_date=today,
    )


@app.get("/current-course", response_model=CurrentCourse)
def get_current_course(db: Session = Depends(get_db)):
    """
    GET /current-course — Return the current selected course (for competitors).

    Reads from the RaceDaySettings table rather than an in-memory variable so
    the selected course survives restarts and is accessible from any device.

    If none selected yet, return 404.
    Reads from DB so it survives restarts.

    Reference: FastAPI dependency injection and response models [B1]
    Reference: SQLAlchemy session.get() [B4]
    """
    today = date.today()
    # Retrieve today's race settings from the database
    settings = db.get(RaceDaySettings, today)
        # Look up today's RaceDaySettings row by primary key (today's date).
    if not settings:
        raise HTTPException(status_code=404, detail="No race selected yet")  
        # No course has been selected for today.
        # Flutter handles this by showing a "No race selected" placeholder.

    # Find the matching static course definition
    course_data = next((c for c in COURSES if c["id"] == settings.course_id), None)
    if not course_data:
        raise HTTPException(status_code=404, detail="Course not found")  
        # The stored course_id no longer matches any entry in COURSES.

    return CurrentCourse(
        course=CourseModel(**course_data),
        start_time=settings.start_time,
        race_date=today,
    )



# Boats and Fleet
# Reference: Pydantic field_validator for class_name [B3]

CLASS_OPTIONS = ["White Sail 1", "White Sail 2", "Spinnaker 1", "Spinnaker 2"]
# List of valid fleet divisions used at RCYC.
# Referenced by field_validator in BoatIn and BoatUpdate to reject any value
# not in this list. Also used by the Flutter fleet admin page to populate the
# class filter dropdown.

class BoatIn(BaseModel):
    """
    Input model for creating a new boat via POST /boats.

    Fields:
        sail_no:      unique sail number, e.g. "IRL5355"
        name:         boat name, e.g. "Prince of Tides"
        club:         optional club name, e.g. "RCYC"
        class_name:   fleet division — must be one of CLASS_OPTIONS
        rating_value: handicap coefficient for corrected time
                      corrected_time = elapsed_seconds × rating_value

    Reference: Pydantic BaseModel and field_validator [B3]
    """
    sail_no: str
    name: str
    club: str | None = None
    # Optional — not all entries will have a club specified.
    class_name: str
    rating_value: float
    #  Float allows fractional ratings, e.g. 0.9823.

    @field_validator("class_name")  # Reference: [B3]
    @classmethod
    def validate_class(cls, v: str) -> str:
        """
        Ensure class_name is one of the valid fleet options.

        Called automatically by Pydantic when a BoatIn is constructed from
        a POST /boats request body.

        Args:
            v: the value supplied for class_name

        Returns:
            v unchanged if valid.

        Raises:
            ValueError if value is not in CLASS_OPTIONS.
            FastAPI converts this to HTTP 422 Unprocessable Entity.

        Reference: Pydantic field_validator [B3]
        """
        if v not in CLASS_OPTIONS:
            raise ValueError(f"class_name must be one of {CLASS_OPTIONS}")
        return v


class BoatOut(BaseModel):
    """
    Output model for boat data returned by GET /boats, POST /boats, PUT /boats/{id}.

    Fields include DB id so the client can identify which boat to edit or delete.

    Reference: Pydantic BaseModel [B3]
    Reference: FastAPI response_model [B1]
    """
    id: int
    # Auto-generated database primary key.
    sail_no: str
    name: str
    club: str | None
    # None if no club was specified when the boat was created.
    class_name: str
    rating_value: float

    class Config:
        from_attributes = True
        # Allow creating BoatOut from SQLAlchemy Boat instances directly.
        # Reference: Pydantic from_attributes [B3]


class BoatUpdate(BaseModel):
    """
    Partial update model for PUT /boats/{boat_id}.

    All fields are optional. Only fields that are not None will be applied
    in update_boat(), leaving the rest unchanged. This is a PATCH-style update
    implemented via a PUT endpoint.

    Reference: Pydantic BaseModel [B3]
    Reference: FastAPI PUT endpoint [B1]
    """
    sail_no: str | None = None
    name: str | None = None
    club: str | None = None
    class_name: str | None = None
    rating_value: float | None = None

    @field_validator("class_name")
    @classmethod
    def validate_class(cls, v: str | None) -> str | None:
        """
        If class_name is provided, validate it is one of CLASS_OPTIONS.
        If it is None (not included in the update), skip validation.

        Reference: Pydantic field_validator [B3]
        """
        if v is None:
            return v
        if v not in CLASS_OPTIONS:
            raise ValueError(f"class_name must be one of {CLASS_OPTIONS}")
        return v


@app.post("/boat-signup", response_model=BoatAuthResponse)
def boat_signup(body: SignupRequest, db: Session = Depends(get_db)):
    """
    POST /boat-signup — Create a competitor account for an existing boat.

    Similar to POST /signup but returns BoatAuthResponse (with success, message,
    and boat fields) rather than a plain message dict. The richer response allows
    Flutter to navigate straight to UserBoatPage after signup without a
    separate login request.

    Steps:
      1. Normalise sail_no to upper-case and strip whitespace.
      2. Look up the Boat row — return failure response if not found.
      3. Return failure if the boat already has a password set.
      4. Hash and store the password using hash_password().
      5. Commit and return success response with boat data.

    Reference: FastAPI POST endpoint with response_model [B1]
    Reference: SQLAlchemy ORM query, commit, refresh [B4]
    Reference: passlib hash_password() via auth.py [B15][B16]
    Reference: schemas/auth.py SignupRequest and BoatAuthResponse [B3]
    Reference: Python str.strip() and str.upper() [B21]
    """
    sail_no = body.sail_no.strip().upper()
    # .strip() removes accidental leading/trailing whitespace.
    # .upper() normalises the sail number so "irl5355" and "IRL5355" both find
    # the same Boat row.
    # Reference: Python str methods [B21]

    boat = db.query(Boat).filter(Boat.sail_no == sail_no).first()
    # Query the boats table for the normalised sail number.
    # Reference: SQLAlchemy ORM query and filter [B4]

    if not boat:
        return {"success": False, "message": "No boat found with that sail number.", "boat": None}
        # Return a failure BoatAuthResponse rather than raising an HTTP exception.
        # The Flutter SignupPage checks success=False and shows the message.

    if boat.owner_password and boat.owner_password.strip() != "":
        return {"success": False, "message": "This boat already has an account. Please log in.", "boat": None}
        # A non-empty password is already stored — the competitor should log in.

    boat.owner_password = hash_password(body.password)
    # Converts the plain-text password into a bcrypt hash for database storage.
    # Reference: auth.py hash_password() [B15][B16]

    db.commit()
    # Write the updated owner_password to the MySQL database.
    db.refresh(boat)
    # Reload the boat object so all fields reflect the saved state.

    return {
        "success": True,
        "message": "Signup successful. You can now log in anytime.",
        "boat": {
            "id": boat.id,
            "sail_no": boat.sail_no,
            "name": boat.name,
            "class_name": boat.class_name,
            "rating_value": boat.rating_value,
        },
    }


@app.post("/boat-login", response_model=BoatAuthResponse)
def boat_login(body: LoginRequest, db: Session = Depends(get_db)):
    """
    POST /boat-login — Authenticate a competitor using sail number and password.

    Uses the sail_no field from LoginRequest (body.sail_no).
    Returns BoatAuthResponse with boat data on success so Flutter can navigate
    directly to UserBoatPage.

    Steps:
      1. Normalise sail_no to upper-case.
      2. Look up the Boat — return failure if not found or no password set.
      3. Verify the password against the stored bcrypt hash.
      4. Return success with boat data.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM query and filter [B4]
    Reference: passlib verify_password() via auth.py [B15]
    Reference: schemas/auth.py BoatAuthResponse [B3]
    """
    sail_no = body.sail_no.strip().upper()
    # Normalise sail number consistently with boat_signup.
    # Reference: Python str methods [B21]

    boat = db.query(Boat).filter(Boat.sail_no == sail_no).first()
    # Query the boats table for the normalised sail number.
    # Reference: SQLAlchemy ORM query and filter [B4]

    if not boat or not boat.owner_password:
        return {"success": False, "message": "Invalid sail number or password.", "boat": None}
        # Same message whether the boat is not found or has no password,
        # to avoid revealing which field was wrong.

    if not verify_password(body.password, boat.owner_password):
        return {"success": False, "message": "Invalid sail number or password.", "boat": None}
        # verify_password() performs a constant-time bcrypt comparison.
        # Returns False if the plain-text password does not match the stored hash.
        # Reference: auth.py verify_password() [B15]

    return {
        "success": True,
        "message": "Login successful",
        "boat": {
            "id": boat.id,
            "sail_no": boat.sail_no,
            "name": boat.name,
            "class_name": boat.class_name,
            "rating_value": boat.rating_value,
        },
    }


@app.get("/boats", response_model=list[BoatOut])
# Reference: FastAPI and SQLAlchemy to query/filter and return models [B2][B4]
def list_boats(class_name: str | None = None, db: Session = Depends(get_db)):
    """
    GET /boats — List boats in the fleet.

    Optional query parameter:
        class_name: filter boats by division ("White Sail 1", etc.)

    Results are ordered by sail_no for a tidy, consistent UI.

    Reference: FastAPI GET endpoint with optional query parameters [B1]
    Reference: SQLAlchemy ORM query, filter, order_by [B4]
    """
    q = db.query(Boat)
    # Start building a SELECT query against the boats table.
    # Reference: SQLAlchemy ORM query [B4]

    if class_name:
        q = q.filter(Boat.class_name == class_name)
        # Add WHERE class_name = :class_name if the parameter was supplied.
        # Reference: SQLAlchemy ORM filter [B4]

    return q.order_by(Boat.sail_no).all()
    # Add ORDER BY sail_no and execute, returning a list of Boat ORM objects.
    # FastAPI serialises each one using BoatOut.


@app.post("/boats", response_model=BoatOut)
def create_boat(body: BoatIn, db: Session = Depends(get_db)):
    """
    POST /boats — Create a new Boat record.

    Used by the race officer via the fleet admin page to register a new
    competitor boat before the race.

    Steps:
      1. Build Boat ORM object from BoatIn.
      2. Add to database and commit.
      3. Refresh to load the auto-generated id.
      4. Return BoatOut to client.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM add, commit, refresh [B4]
    """
    boat = Boat(
        sail_no=body.sail_no,
        # Unique sail number — MySQL raises an IntegrityError on duplicate
        # because sail_no has a UNIQUE constraint in the schema.
        name=body.name,
        club=body.club,
        class_name=body.class_name,
        # Already validated by BoatIn.validate_class to be one of CLASS_OPTIONS.
        rating_value=body.rating_value,
    )
    db.add(boat)
    # Stage the new Boat instance for INSERT into the boats table.
    db.commit()
    # Execute the INSERT and commit the transaction.
    db.refresh(boat)
    # Reload from the database to populate the auto-generated id.
    return boat
    # FastAPI serialises this Boat ORM object using BoatOut.


@app.put("/boats/{boat_id}", response_model=BoatOut)
def update_boat(boat_id: int, body: BoatUpdate, db: Session = Depends(get_db)):
    """
    PUT /boats/{boat_id} — Update an existing Boat.

    Only fields that are not None in BoatUpdate are applied, leaving the
    rest unchanged. This is a PATCH-style update via a PUT endpoint.

    Args:
        boat_id: path parameter — the database id of the boat to update
        body: BoatUpdate with optional fields
        db: database session

    Returns:
        BoatOut with the updated boat data.
        HTTP 404 if no boat with boat_id exists.

    Reference: FastAPI PUT endpoint with path parameter [B1]
    Reference: SQLAlchemy ORM session.get(), commit, refresh [B4]
    """
    boat = db.get(Boat, boat_id)
    # Look up the Boat by primary key.
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    # Only update fields that are not None — leave everything else unchanged.
    if body.sail_no is not None:
        boat.sail_no = body.sail_no
    if body.name is not None:
        boat.name = body.name
    if body.club is not None:
        boat.club = body.club
    if body.class_name is not None:
        boat.class_name = body.class_name
    if body.rating_value is not None:
        boat.rating_value = body.rating_value
    # SQLAlchemy's change tracking detects these assignments and includes them
    # in an UPDATE statement on the next commit.

    db.add(boat)
    # Re-add to explicitly mark the object as modified (good practice).
    db.commit()
    db.refresh(boat)
    return boat


@app.delete("/boats/{boat_id}", status_code=204)
def delete_boat(boat_id: int, db: Session = Depends(get_db)):
    """
    DELETE /boats/{boat_id} — Delete a boat by id.

    Args:
        boat_id: path parameter — the database id of the boat to delete
        db: database session

    Returns:
        HTTP 204 No Content on success (no response body).
        HTTP 404 if no boat with boat_id exists.

    Reference: FastAPI DELETE endpoint [B1]
    Reference: SQLAlchemy ORM session.delete(), commit [B4]
    """
    boat = db.get(Boat, boat_id)
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")
    
    # Delete child rows that reference this boat to satisfy foreign key constraints.
    # MySQL will reject deleting a boat if any rows in these tables still point to it.
    db.query(Entry).filter(Entry.boat_id == boat_id).delete()
    # Remove any race entries linking this boat to races.
    db.query(RaceStart).filter(RaceStart.boat_id == boat_id).delete()
    # Remove any timing records (starts, finishes, results) for this boat.
    db.query(CheckIn).filter(CheckIn.boat_id == boat_id).delete()
    # Removes Check In

    db.delete(boat)
    # Now safe to delete the Boat row itself — no child rows reference it.
    db.commit()
    return None
    # HTTP 204 No Content — FastAPI sends no response body.
    # The Flutter admin page removes the boat from its local list on success.

# Check-In 
# ------

@app.post("/check-in")
def check_in(boat_id: int, race_date: date, db: Session = Depends(get_db)):
    """
    POST /check-in?boat_id=X&race_date=YYYY-MM-DD
    Competitor confirms they are racing today.
    Upsert pattern — safe to call multiple times.
    """
    boat = db.get(Boat, boat_id)
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    existing = (
        db.query(CheckIn)
        .filter(CheckIn.boat_id == boat_id, CheckIn.race_date == race_date)
        .first()
    )
    if existing:
        return {"message": "Already checked in", "boat_id": boat_id}

    ci = CheckIn(
        boat_id=boat_id,
        race_date=race_date,
        checked_in_at=datetime.now(),
    )
    db.add(ci)
    db.commit()
    return {"message": "Checked in", "boat_id": boat_id}


@app.delete("/check-in")
def undo_check_in(boat_id: int, race_date: date, db: Session = Depends(get_db)):
    """
    DELETE /check-in?boat_id=X&race_date=YYYY-MM-DD
    Lets a competitor undo their check-in if they tapped by mistake.
    """
    deleted = (
        db.query(CheckIn)
        .filter(CheckIn.boat_id == boat_id, CheckIn.race_date == race_date)
        .delete()
    )
    db.commit()
    return {"deleted": deleted}


@app.get("/check-ins")
def list_check_ins(race_date: date, db: Session = Depends(get_db)):
    """
    GET /check-ins?race_date=YYYY-MM-DD
    Returns all checked-in boats for today — used by the race officer page.
    """
    rows = (
        db.query(CheckIn, Boat)
        .join(Boat, CheckIn.boat_id == Boat.id)
        .filter(CheckIn.race_date == race_date)
        .all()
    )
    return [
        {
            "boat_id": boat.id,
            "sail_no": boat.sail_no,
            "name": boat.name,
            "class_name": boat.class_name,
            "checked_in_at": ci.checked_in_at.isoformat(),
        }
        for ci, boat in rows
    ]


# Race Start / Finish — Input and Output Models


class RaceStartIn(BaseModel):
    """
    Input model for creating or updating a RaceStart record for a boat.

    Fields:
        boat_id: the Boat.id foreign key
        race_date: date of the race (YYYY-MM-DD)
        start_time: official start time for that boat (HH:MM:SS)

    Reference: SQLAlchemy Relationships [B11]
    Reference: Pydantic models with date and time fields [B3][B5]
    """
    boat_id: int
    race_date: date
    # Python date type, serialised as "YYYY-MM-DD" string in JSON.
    start_time: time
    # Python time type, serialised as "HH:MM:SS" string in JSON.
    # Reference: Python date and time types [B5]


class RaceStartDetailOut(BaseModel):
    """
    Detailed view of a RaceStart record.

    Returned by /race-starts endpoints for admin pages and the competitor dashboard.

    Fields:
        id:  database primary key of the RaceStart row
        boat_id: foreign key linking to the Boat
        race_date: date of the race
        start_time: recorded class start time
        finish_time: recorded finish time (None until the boat finishes)
        elapsed_seconds: finish - start in whole seconds (None until finished)
        corrected_seconds:elapsed × rating_value (None until finished)

    Reference: Pydantic models with date and time fields [B3][B5]
    """
    id: int
    boat_id: int
    race_date: date
    start_time: time
    finish_time: time | None = None
    elapsed_seconds: int | None = None
    corrected_seconds: float | None = None

    class Config:
        from_attributes = True
        # Required so Pydantic can build this directly from a RaceStart ORM object.
        # Reference: Pydantic from_attributes [B3]

# Reference: Pydantic models with date and time fields [B3][B5]


class RaceFinishIn(BaseModel):
    """
    Input model when admin presses 'Finish now' for a boat.

    Optionally includes OCS status and penalty seconds from the finish
    options bottom sheet in the Flutter admin UI.

    Fields:
        boat_id: which boat finished
        race_date: which day
        finish_time: recorded time of crossing the finish line
        ocs: if True, mark boat as On Course Side (OCS)
        penalty_seconds: time penalty to add in seconds (e.g. 30)

    Reference: Pydantic models with date and time fields [B3][B5]
    Reference: World Sailing result codes [S1]
    """
    boat_id: int
    race_date: date
    finish_time: time

    # coming from the finish options bottom sheet in the Flutter admin UI
    ocs: bool | None = None
    # None means "do not change the current OCS flag".
    penalty_seconds: int | None = None
    # None means "do not change the current penalty value".

# Reference: Pydantic models with date and time fields [B3][B5]


class ClassStartIn(BaseModel):
    """
    Input model for POST /race-starts/class-start.

    Used when all boats in White Sail 1 start together, etc.
    The most common scenario in RCYC keelboat racing.

    Fields:
        class_name: the fleet division (e.g. "White Sail 1")
        race_date: the date of the race
        start_time: the class start time to apply to all boats

    Reference: Pydantic BaseModel [B3]
    """
    class_name: str
    race_date: date
    start_time: time


class RaceResultOut(BaseModel):
    """
    Output model representing race results for a boat in a class.

    Combines data from both the RaceStart and Boat tables.
    Constructed manually in race_results_for_class() from (RaceStart, Boat)
    tuples, hence from_attributes=False.

    Fields:
        boat_id, sail_no, name, class_name, rating_value — from the Boat table
        start_time, finish_time                           — from RaceStart
        code: result code, e.g. "OCS" (None for clean finishes)
        elapsed_seconds: total elapsed race time in seconds
        corrected_seconds: elapsed × rating_value (handicap-adjusted time)
        position: finishing position in class (1, 2, 3...) by corrected time
                None for boats that did not finish or were flagged OCS

    Reference: Pydantic BaseModel [B3]
    Reference: World Sailing-style result codes and Sailwave scoring [S1]
    """
    boat_id: int
    sail_no: str
    name: str
    class_name: str
    rating_value: float
    start_time: time | None = None
    finish_time: time | None = None
    code: str | None = None
    elapsed_seconds: int | None = None
    corrected_seconds: float | None = None
    position: int | None = None

    class Config:
        from_attributes = False
        # Not built directly from a single ORM object — constructed manually
        # from a (RaceStart, Boat) tuple returned by a JOIN query.


# Race Start Listing


@app.get("/race-starts", response_model=list[RaceStartDetailOut])
def list_race_starts(
    race_date: date,
    db: Session = Depends(get_db),
):
    """
    GET /race-starts?race_date=YYYY-MM-DD
    Get all RaceStart records for a given race_date.

    Used by the admin to see which boats have start/finish times recorded.
    Results are ordered by start_time then boat_id, which groups boats by
    their class start time.

    Reference: FastAPI GET endpoint with query parameters [B1]
    Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
    Reference: datetime combination and timedelta arithmetic [B5]
    """
    starts = (
        db.query(RaceStart)
        .filter(RaceStart.race_date == race_date)
        # WHERE race_date = :race_date
        .order_by(RaceStart.start_time, RaceStart.boat_id)
        # ORDER BY start_time, boat_id — groups boats by their class start time.
        .all()
    )
    return starts

# Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
# Reference: datetime combination and timedelta arithmetic [B5]



# Single Boat Start


@app.post("/race-starts", response_model=RaceStartDetailOut)
def upsert_race_start(body: RaceStartIn, db: Session = Depends(get_db)):
    """
    POST /race-starts — Set or update a single boat's start time.

    If a RaceStart exists for (boat_id, race_date), update it.
    Otherwise, create a new RaceStart record.
    Safe to call multiple times — the upsert pattern handles both cases.

    Args:
        body: RaceStartIn with boat_id, race_date, start_time
        db: database session

    Returns:
        RaceStartDetailOut for the created or updated record.
        HTTP 404 if the boat_id does not exist.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM upsert pattern [B4]
    """
    boat = db.get(Boat, body.boat_id)
    # Verify the boat exists before creating a RaceStart for it.
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    start = (
        db.query(RaceStart)
        .filter(
            RaceStart.boat_id == body.boat_id,
            RaceStart.race_date == body.race_date,
        )
        .first()
        # Check whether a RaceStart already exists for this boat/date combination.
        # Reference: SQLAlchemy ORM query and filter [B4]
    )

    if start:
        # Update existing start time.
        start.start_time = body.start_time
        # SQLAlchemy's change tracking includes this in the next commit.
    else:
        # Create new record.
        start = RaceStart(
            boat_id=body.boat_id,
            race_date=body.race_date,
            start_time=body.start_time,
        )
        db.add(start)
        # Stage the new RaceStart instance for INSERT.

    db.commit()
    db.refresh(start)
    return start


# Class Start Times


@app.post("/race-starts/class-start", response_model=list[RaceStartDetailOut])
def set_class_start(body: ClassStartIn, db: Session = Depends(get_db)):
    """
    POST /race-starts/class-start — Set the same start time for every boat
    in a given class.

    Example: all "White Sail 1" boats start at 18:30:00.

    Steps:
      1. Fetch all boats in class_name.
      2. For each boat, upsert RaceStart(start_time=body.start_time).
      3. Commit once — more efficient than committing inside the loop.
      4. Return all RaceStart rows for that class and date.

    Args:
        body: ClassStartIn with class_name, race_date, start_time
        db: database session

    Returns:
        List of RaceStartDetailOut for every boat in the class.
        HTTP 404 if no boats exist in the given class.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM loop upsert with single commit [B4]
    """
    boats = db.query(Boat).filter(Boat.class_name == body.class_name).all()
    # Fetch all boats in the specified class.
    if not boats:
        raise HTTPException(status_code=404, detail="No boats in that class")

    for boat in boats:
        # Iterate over every boat in the class and upsert its start time.
        start = (
            db.query(RaceStart)
            .filter(
                RaceStart.boat_id == boat.id,
                RaceStart.race_date == body.race_date,
            )
            .first()
        )
        if start:
            start.start_time = body.start_time
            # Update the existing row's start time.
        else:
            start = RaceStart(
                boat_id=boat.id,
                race_date=body.race_date,
                start_time=body.start_time,
            )
            db.add(start)
            # Stage a new row for this boat.

    db.commit()
    # Commit all inserts/updates in a single transaction.

    # Return all RaceStart entries for this date and class.
    starts = (
        db.query(RaceStart)
        .join(Boat, RaceStart.boat_id == Boat.id)
        # JOIN race_starts ON boats.id = race_starts.boat_id
        .filter(
            RaceStart.race_date == body.race_date,
            Boat.class_name == body.class_name,
        )
        .all()
    )
    return starts

# Reference: FastAPI Path and Body Params Docs [B1]



# Get Boat Start


@app.get("/race-starts/boat", response_model=RaceStartDetailOut)
def get_boat_race_start(
    boat_id: int,
    race_date: date,
    db: Session = Depends(get_db),
):
    """
    GET /race-starts/boat?boat_id=X&race_date=YYYY-MM-DD
    Get the start record for a specific boat on a specific date.

    Used by the competitor UserBoatPage to check whether a start time has been
    recorded for the logged-in competitor today.

    If none exists, return 404 with a clear message.

    Reference: FastAPI GET endpoint with query parameters [B1]
    Reference: SQLAlchemy ORM query and filter [B4]
    """
    start = (
        db.query(RaceStart)
        .filter(
            RaceStart.boat_id == boat_id,
            RaceStart.race_date == race_date,
        )
        .first()
    )
    if not start:
        raise HTTPException(
            status_code=404,
            detail="No start recorded for this boat on this date",
        )
    return start


# Penalties and OCS


class PenaltyIn(BaseModel):
    """
    Input model for applying OCS status and/or a time penalty to a boat
    for a given race day.

    All fields except boat_id and race_date are optional, so the race officer
    can update OCS without changing the penalty, and vice versa.

    Fields:
        boat_id: which boat to update
        race_date: which race day
        penalty_seconds: seconds to add to elapsed time (None = no change)
        ocs: True to flag OCS, False to clear it (None = no change)

    Reference: Pydantic BaseModel [B3]
    Reference: World Sailing result codes [S1]
    """
    boat_id: int
    race_date: date
    penalty_seconds: int | None = None
    # None means "do not change the existing penalty_seconds value".
    ocs: bool | None = None
    # None means "do not change the existing OCS flag".


@app.put("/race-penalty", response_model=RaceStartDetailOut)
def set_penalty(body: PenaltyIn, db: Session = Depends(get_db)):
    """
    PUT /race-penalty — Apply OCS and/or a time penalty to a boat for a given race_date.

    Implements User Story 7: "flag OCS/penalties so results reflect official rulings".

    If elapsed_seconds is already recorded (the boat has finished), corrected_seconds
    is recomputed to reflect the updated penalty.

    Steps:
      1. Find the RaceStart row for the given boat and date.
      2. Update ocs and/or penalty_seconds if provided.
      3. Recompute corrected_seconds if elapsed exists.
      4. Commit and return the updated record.

    Reference: FastAPI PUT endpoint [B1]
    Reference: SQLAlchemy ORM update and commit [B4]
    Reference: World Sailing result codes [S1]
    """
    start = (
        db.query(RaceStart)
        .filter(RaceStart.boat_id == body.boat_id, RaceStart.race_date == body.race_date)
        .first()
    )
    if not start:
        raise HTTPException(status_code=404, detail="No race record for boat/date")

    # Apply changes only if values are provided in the request body.
    if body.ocs is not None:
        start.ocs = 1 if body.ocs else 0
        # Store OCS as an integer (1 = OCS, 0 = clean) because MySQL TINYINT
        # is more reliable than a Python bool for this flag.
        # Reference: MySQL TINYINT for boolean storage [B7]

    if body.penalty_seconds is not None:
        start.penalty_seconds = body.penalty_seconds
        # Set to 0 to clear an existing penalty, or a positive integer to add time.
    elif body.penalty_seconds is None:
        # If caller explicitly wants to clear, they send null; keep simple:
        pass
        # No change requested for penalty_seconds — leave the existing value.

    # Recompute corrected_seconds if elapsed_seconds already exists.
    boat = db.get(Boat, start.boat_id)
    # Retrieve the Boat to access its rating_value for corrected time calculation.
    # Reference: SQLAlchemy session.get() [B4]

    if boat and start.elapsed_seconds is not None:
        # Only recompute if the boat has already finished (elapsed_seconds is set).
        penalty = start.penalty_seconds or 0
        # Default to 0 if penalty_seconds is None.
        adjusted = start.elapsed_seconds + penalty
        # Add penalty seconds to the raw elapsed time.
        start.corrected_seconds = adjusted * boat.rating_value
        # corrected_seconds = (elapsed + penalty) × rating_value.
        # Lower corrected_seconds = better (faster) result in the standings.

    db.commit()
    db.refresh(start)
    return start


# Record Finish


@app.post("/race-finish", response_model=RaceStartDetailOut)
def record_finish(body: RaceFinishIn, db: Session = Depends(get_db)):
    """
    POST /race-finish — Admin presses 'Finish now' for a boat.

    This endpoint:
      • Finds the RaceStart entry for boat_id + race_date
      • Sets finish_time
      • Computes elapsed_seconds (taking midnight crossings into account)
      • Computes corrected_seconds = elapsed × rating_value
        (set to None if OCS is flagged — treated as "unplaced")

    Steps:
      1. Find the RaceStart row — return 404 if no start has been recorded.
      2. Apply OCS and penalty updates if included in the request.
      3. Set finish_time.
      4. Combine race_date and start_time and finish_time into full datetime objects.
      5. Handle midnight crossings by adding one day if finish_dt < start_dt.
      6. Compute elapsed_seconds = (finish_dt - start_dt).total_seconds().
      7. Compute corrected_seconds = (elapsed + penalty) × rating_value.
      8. Commit and return the updated record.

    Reference: FastAPI POST endpoint [B1]
    Reference: SQLAlchemy ORM update and commit [B4]
    Reference: Python datetime.combine and timedelta arithmetic [B5]
    Reference: World Sailing result codes [S1]
    """
    start = (
        db.query(RaceStart)
        .filter(
            RaceStart.boat_id == body.boat_id,
            RaceStart.race_date == body.race_date,
        )
        .first()
    )
    if not start:
        raise HTTPException(
            status_code=404,
            detail="No start recorded for this boat on this date",
        )
        # A class start time must be set before a finish can be recorded.

    boat = db.get(Boat, start.boat_id)
    # Retrieve the Boat to access its rating_value.
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    # Apply OCS / penalty updates if provided in the finish request.
    if body.ocs is not None:
        start.ocs = 1 if body.ocs else 0
        # Store OCS as integer 0/1 (MySQL TINYINT).
        # Reference: MySQL TINYINT [B7]

    if body.penalty_seconds is not None:
        start.penalty_seconds = body.penalty_seconds
        # Apply penalty if provided; None leaves the existing value unchanged.

    # Set finish time.
    start.finish_time = body.finish_time
    # Record the finish time on the RaceStart row.

    # Combine date and start/finish times to form full datetimes.
    start_dt = datetime.combine(body.race_date, start.start_time)
    # datetime.combine() merges a date and a time into a full datetime object.
    # e.g. date(2025,7,1) and time(18,30,0) → datetime(2025,7,1,18,30,0)
    # Reference: Python datetime.combine [B5]

    finish_dt = datetime.combine(body.race_date, body.finish_time)
    # Create the finish datetime using the same race date.

    # If finish crosses midnight and is earlier than start, add a day.
    if finish_dt < start_dt:
        finish_dt += timedelta(days=1)
        # Handles races that start in the evening and finish after midnight.
        # timedelta(days=1) adds exactly 24 hours to the finish datetime.
        # Reference: Python timedelta [B5]

    # Compute elapsed seconds.
    elapsed = int((finish_dt - start_dt).total_seconds())
    # Subtracting two datetimes gives a timedelta; .total_seconds() converts it
    # to a float; int() truncates any sub-second fraction.
    # Reference: Python datetime timedelta Docs [B5]
    start.elapsed_seconds = elapsed

    # Apply penalty seconds if present.
    penalty = start.penalty_seconds or 0
    # Default to 0 if penalty_seconds is None.
    adjusted_elapsed = elapsed + penalty

    # If OCS is flagged, keep corrected_seconds as None (treated as "unplaced").
    if start.ocs == 1:
        start.corrected_seconds = None
        # OCS boats are unplaced — the sort_key sentinel in race_results_for_class
        # puts them at the bottom of the results list.
        # Reference: World Sailing result codes [S1]
    else:
        start.corrected_seconds = adjusted_elapsed * boat.rating_value
        # corrected_seconds = adjusted_elapsed × rating_value.
        # Lower corrected_seconds = better (faster) result.

    db.commit()
    db.refresh(start)
    return start

# Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
# Reference: datetime combination and timedelta arithmetic [B5]


# Race Results (Per Class)


@app.get("/race-results", response_model=list[RaceResultOut])
def race_results_for_class(
    race_date: date,
    class_name: str,
    db: Session = Depends(get_db),
):
    """
    GET /race-results?race_date=YYYY-MM-DD&class_name=X
    Return race results for a class on a given date.

    Steps:
      1. Query RaceStart JOIN Boat filtered by race_date + class_name.
      2. Sort rows by corrected_seconds ascending; OCS to the bottom;
         boats with no finish above OCS.
      3. Assign finishing positions (1, 2, 3, ...) to boats that have
         valid corrected times.
      4. Return list of RaceResultOut objects.

    Used by:
      RaceResultsPage (admin) to display results on the committee boat.
      UserBoatPage (competitor dashboard) to show results with own boat highlighted.

    Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
    Reference: datetime combination and timedelta arithmetic [B5]
    Reference: Pydantic models (adding optional fields to response schemas) [B3]
    Reference: World Sailing-style result codes and downstream scoring tools [S1]
    """
    rows = (
        db.query(RaceStart, Boat)
        .join(Boat, RaceStart.boat_id == Boat.id)
        # INNER JOIN boats ON race_starts.boat_id = boats.id
        .filter(
            RaceStart.race_date == race_date,
            Boat.class_name == class_name,
        )
        .all()
        # Returns a list of (RaceStart, Boat) tuples.
    )

    # Convert to list for in-place sorting.
    temp: list[tuple[RaceStart, Boat]] = list(rows)

    def sort_key(item: tuple[RaceStart, Boat]) -> float:
        """
        Sorting key function: use corrected_seconds if available,
        else a very large number so unfinished boats go to the bottom.

        Uses sentinel values (10**12, 10**13) rather than None so that
        Python's sorted() can compare all results using the same float type.
        OCS boats get 10**13 (worst) and DNF/DNS boats get 10**12.

        Reference: Python sorted() with key function [B21]
        """
        start, _ = item
        # OCS always at the bottom.
        if start.ocs == 1:
            return 10**13

        return (
            start.corrected_seconds
            if start.corrected_seconds is not None
            else 10**12  # large sentinel value for unfinished boats
        )

    # Sort by corrected time ascending (lower = faster = better position).
    temp_sorted = sorted(temp, key=sort_key)
    # Reference: Python sorted() [B21]

    results: list[RaceResultOut] = []
    position_counter = 1
    # Will increment only for boats with valid corrected times.

    for start, boat in temp_sorted:
        corr = start.corrected_seconds
        is_ocs = (start.ocs == 1)

        # If corrected time is present and no OCS, assign position; else leave as None.
        pos = (position_counter if (corr is not None and not is_ocs) else None)
        if corr is not None and not is_ocs:
            position_counter += 1
            # Increment only for placed boats.

        results.append(
            RaceResultOut(
                boat_id=boat.id,
                sail_no=boat.sail_no,
                name=boat.name,
                class_name=boat.class_name,
                rating_value=boat.rating_value,
                start_time=start.start_time,
                finish_time=start.finish_time,
                elapsed_seconds=start.elapsed_seconds,
                corrected_seconds=corr,
                position=pos,
                code=("OCS" if start.ocs == 1 else None),
                # "OCS" is the World Sailing standard result code for On Course Side.
                # Reference: World Sailing result codes [S1]
            )
        )

    return results

# Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
# Reference: datetime combination and timedelta arithmetic [B5]
# Reference: Pydantic models (adding optional fields to response schemas) [B3]
# Reference: World Sailing-style result codes and downstream scoring tools (e.g., Sailwave) [S1]


# Sailwave CSV Export (per race day, per class)


# Sailwave is the race scoring software used at RCYC.
# This endpoint produces a CSV file that can be imported directly into Sailwave,
# saving the results secretary from manually re-entering times.
#
# Sailwave supports importing race results from CSV using field names such as:
# RaceNo, Elapsed, Start, Finish, Laps, Code, Place
# and the guide shows an example CSV header like: raceno, class, sailno, start, finish
#
# Reference: Sailwave race scoring software [S1]

def _time_to_sailwave_str(t: time | None) -> str:
    """
    Convert a Python datetime.time into a Sailwave-friendly string.

    Sailwave accepts times in "HH:MM" or "HH:MM:SS" format.
    If time is missing, return an empty string — Sailwave import can handle blanks.

    Args:
        t: a Python time object, or None

    Returns:
        "HH:MM:SS" string, or "" if t is None.

    Reference: Python strftime format codes [B5]
    Reference: Sailwave Dates and Times formatting rules [S1]
    """
    if t is None:
        return ""
    return t.strftime("%H:%M:%S")
    # %H = zero-padded 24-hour hour (00-23)
    # %M = zero-padded minute (00-59)
    # %S = zero-padded second (00-59)
    # Reference: Python strftime [B5]


def _seconds_to_elapsed_str(seconds: int | None) -> str:
    """
    Convert elapsed seconds to "HH:MM:SS" duration string for Sailwave Elapsed field.

    Sailwave's Elapsed field expects a duration, not a clock time.
    If missing, return an empty string.

    Args:
        seconds: elapsed time in whole seconds, or None

    Returns:
        "HH:MM:SS" duration string, or "" if seconds is None.

    Reference: Python integer arithmetic [B21]
    Reference: Sailwave Elapsed field format [S1]
    """
    if seconds is None:
        return ""
    h = seconds // 3600
    # Integer division to extract whole hours.
    m = (seconds % 3600) // 60
    # Remainder after hours converted to minutes.
    s = seconds % 60
    # Remainder after minutes gives seconds.
    return f"{h:02d}:{m:02d}:{s:02d}"
    # :02d formats each component as a zero-padded two-digit integer.
    # Reference: Python f-string format specification [B21]


@app.get("/export/sailwave-race-csv")
def export_sailwave_race_csv(
    race_date: date,
    class_name: str,
    race_no: int,
    db: Session = Depends(get_db),
):
    """
    GET /export/sailwave-race-csv?race_date=X&class_name=Y&race_no=Z
    Export one race (one date) for one class to a Sailwave-compatible CSV.

    The CSV is built in memory using io.StringIO and Python's csv module,
    then returned as a downloadable file via FastAPI's StreamingResponse.

    How it maps to Sailwave import fields:
      - raceno  - race_no query parameter
      - class   - class_name query parameter (must match Sailwave Fleet/Class)
      - sailno  - Boat.sail_no
      - start   - RaceStart.start_time formatted as HH:MM:SS
      - finish  - RaceStart.finish_time formatted as HH:MM:SS
      - elapsed - RaceStart.elapsed_seconds formatted as HH:MM:SS duration
      - code    - "OCS" if flagged, empty string otherwise
      - place  - finishing position based on corrected time

    Sailwave doc: field names (RaceNo, Elapsed, Start, Finish, Code, Place)

    Reference: FastAPI GET endpoint [B1]
    Reference: FastAPI StreamingResponse [B8]
    Reference: Starlette StreamingResponse [B9]
    Reference: HTTP Content-Disposition header [B10]
    Reference: Python csv module [B19]
    Reference: Python io.StringIO [B20]
    Reference: Sailwave import format [S1]
    """

    # Query the race results using the existing logic (RaceStart JOIN Boat).
    rows = (
        db.query(RaceStart, Boat)
        .join(Boat, RaceStart.boat_id == Boat.id)
        .filter(
            RaceStart.race_date == race_date,
            Boat.class_name == class_name,
        )
        .all()
    )

    # Sort for "place" using the same logic as the /race-results endpoint:
    # - OCS boats go to the bottom (10**13)
    # - boats with no corrected time go second from bottom (10**12)
    temp: list[tuple[RaceStart, Boat]] = list(rows)

    def sort_key(item: tuple[RaceStart, Boat]) -> float:
        start, _ = item
        if start.ocs == 1:
            return 10**13
        return start.corrected_seconds if start.corrected_seconds is not None else 10**12

    temp_sorted = sorted(temp, key=sort_key)

    # Assign places (1, 2, 3, ...) only to boats with valid corrected times and not OCS.
    place_by_boat_id: dict[int, int] = {}
    # Maps Boat.id → finishing position for clean finishers.
    place_counter = 1
    for start, boat in temp_sorted:
        if start.ocs == 1:
            continue
            # OCS boats do not receive a place number.
        if start.corrected_seconds is None:
            continue
            # Boats without a corrected time do not receive a place.
        place_by_boat_id[boat.id] = place_counter
        place_counter += 1

    # Build CSV in memory — no disk I/O needed.
    buffer = io.StringIO()
    # io.StringIO creates an in-memory text buffer that behaves like a file.
    # Reference: Python io.StringIO [B20]

    writer = csv.writer(buffer)
    # csv.writer writes rows into the StringIO buffer as comma-separated text.
    # Reference: Python csv.writer [B19]

    # Header row:
    # Sailwave is case-insensitive in many mappings but matching their example is safest.
    # Their example uses: raceno, class, sailno, start, finish
    # They also list additional fields like Elapsed, Code, Place.
    writer.writerow(["raceno", "class", "sailno", "start", "finish", "elapsed", "code", "place"])
    # Reference: Sailwave CSV import format [S1]

    for start, boat in temp_sorted:
        # Scoring code — Sailwave supports OCS, DNF, DNS, etc.
        # Currently only OCS is implemented; DNF/DNS are future work.
        code = ""
        if start.ocs == 1:
            code = "OCS"
            # "OCS" is the World Sailing standard result code for On Course Side.
        # If you later add DNF/DNS flags to your DB, map them here too.

        place_str = ""
        if boat.id in place_by_boat_id:
            place_str = str(place_by_boat_id[boat.id])
            # Convert integer place to a string for the CSV cell.

        writer.writerow(
            [
                race_no,     # raceno
                class_name,    # class
                boat.sail_no,   # sailno
                _time_to_sailwave_str(start.start_time),   # start (HH:MM:SS)
                _time_to_sailwave_str(start.finish_time), # finish (HH:MM:SS)
                _seconds_to_elapsed_str(start.elapsed_seconds),  # elapsed (HH:MM:SS)
                code,  # code (OCS or blank)
                place_str,  # place (integer or blank)
            ]
        )

    buffer.seek(0)
    # Reset the buffer's read position to the start so StreamingResponse reads
    # from the beginning of the CSV content rather than the end.

    # Return as a downloadable CSV file.
    filename = f"sailwave_race_{race_no}_{class_name}_{race_date}.csv".replace(" ", "_")
    # .replace(" ", "_") removes spaces which can cause issues in some browsers.
    headers = {"Content-Disposition": f'attachment; filename="{filename}"'}
    # Content-Disposition: attachment tells the browser to download the file
    # rather than display it inline.
    # Reference: HTTP Content-Disposition header [B10]

    # StreamingResponse is the standard FastAPI/Starlette approach for file-like responses.
    return StreamingResponse(
        iter([buffer.getvalue()]),
        # iter([...]) wraps the CSV string in an iterable as required by StreamingResponse.
        media_type="text/csv",
        # Sets Content-Type so the browser and Sailwave know it is a CSV file.
        headers=headers,
    )

# Reference: Python csv module for writing CSV rows [B19]
# Reference: StreamingResponse for returning downloadable files in FastAPI/Starlette [B8][B9]
# Reference: Content-Disposition header to trigger file download in browsers [B10]


# League Points (Low Score Wins)

class LeaguePointsOut(BaseModel):
    """
    Output row for league points for one boat on one race date.

    Fields:
        race_date:  the date of the race
        class_name: the fleet division
        boat_id: database id of the boat
        sail_no: sail number displayed in the Flutter UI
        name: boat name
        place:finishing place in class by corrected time (None if not placed)
        points: points for league scoring — usually same as place (low is best)
                    OCS boats receive starters + 1 points
        code: result code, e.g. "OCS" (None for clean finishes)

    Reference: Pydantic BaseModel [B3]
    Reference: World Sailing low-points scoring system [S1]
    """
    race_date: date
    class_name: str
    boat_id: int
    sail_no: str
    name: str
    place: int | None = None
    # Finishing position within the class (1, 2, 3, ...).
    points: int | None = None
    # League points — same value as place for clean finishers.
    code: str | None = None
    # e.g. "OCS" if applicable.


@app.get("/league-points", response_model=list[LeaguePointsOut])
def league_points_for_day(
    race_date: date,
    class_name: str,
    db: Session = Depends(get_db),
):
    """
    GET /league-points?race_date=YYYY-MM-DD&class_name=X
    Return league points for a single race day and class.

    Scoring logic (low-points system):
      - Sort by corrected time (same as /race-results).
      - Assign place 1..N.
      - Points = place (lower is better).
      - If OCS: set code="OCS" and give points = (number of starters + 1).
        This is a common simple league approach consistent with World Sailing.

    Sailwave supports OCS as an import code, which is a useful consistency.

    Reference: FastAPI GET endpoint [B1]
    Reference: SQLAlchemy JOIN query [B4]
    Reference: World Sailing low-points scoring system [S1]
    """
    rows = (
        db.query(RaceStart, Boat)
        .join(Boat, RaceStart.boat_id == Boat.id)
        # INNER JOIN boats ON race_starts.boat_id = boats.id
        .filter(
            RaceStart.race_date == race_date,
            Boat.class_name == class_name,
        )
        .all()
    )

    temp: list[tuple[RaceStart, Boat]] = list(rows)

    def sort_key(item: tuple[RaceStart, Boat]) -> float:
        # Same sort logic as race_results_for_class.
        start, _ = item
        if start.ocs == 1:
            return 10**13
        return start.corrected_seconds if start.corrected_seconds is not None else 10**12

    temp_sorted = sorted(temp, key=sort_key)

    # Count "starters" — boats that have a start_time recorded (actually started).
    # Used to calculate OCS penalty points (starters plus 1).
    starters = sum(1 for start, _ in temp_sorted if start.start_time is not None)
    # Reference: Python built-in sum() with generator expression [B21]

    results: list[LeaguePointsOut] = []
    place_counter = 1

    for start, boat in temp_sorted:
        # Default values — overwritten below depending on the boat's result.
        place: int | None = None
        points: int | None = None
        code: str | None = None

        if start.ocs == 1:
            code = "OCS"
            # Simple penalty: worse than last starter.
            points = starters + 1
            # Reference: World Sailing low-points scoring [S1]
        elif start.corrected_seconds is None:
            # No finish / no corrected time — leave place and points as None.
            # For now: leave blank.
            pass
        else:
            place = place_counter
            points = place_counter
            # Low-points: place = points. 1st place gets 1 point.
            place_counter += 1

        results.append(
            LeaguePointsOut(
                race_date=race_date,
                class_name=class_name,
                boat_id=boat.id,
                sail_no=boat.sail_no,
                name=boat.name,
                place=place,
                points=points,
                code=code,
            )
        )

    return results


# Reset Race Day


@app.delete("/race-day")
def reset_race_day(
    race_date: date,
    class_name: str | None = None,
    db: Session = Depends(get_db),
):
    """
    DELETE /race-day?race_date=YYYY-MM-DD&class_name=X
    Delete RaceStart records for a given date.

    If class_name is provided, only RaceStart rows for that class are deleted.
    Otherwise, ALL RaceStart rows for the date are deleted.

    Used by the 'Reset today's timings' button on the admin RaceStartsPage.
    Allows the race officer to clear timing data if a mistake was made and
    start the recording process again.

    Args:
        race_date:  query parameter — the date to reset
        class_name: optional — restrict deletion to one class
        db: database session

    Returns:
        {"deleted": N} where N is the number of rows deleted.

    Reference: FastAPI DELETE endpoint with query parameters [B1]
    Reference: SQLAlchemy ORM delete with filter (no joined delete) [B4]
    Reference: SQLAlchemy ORM Delete Rules [B12]
    """
    from models.base import Boat as BoatModel
    # Local import ensures the correct Boat model is used here, avoiding any
    # potential name shadowing from imports earlier in the file.

    # Base query: all RaceStart rows for the given date.
    q = db.query(RaceStart).filter(RaceStart.race_date == race_date)

    if class_name:
        # Filter to starts whose boat is in the given class.
        # Uses relationship-style condition (RaceStart.boat.has(...)) rather
        # than an explicit JOIN because SQLAlchemy does not allow .delete() on
        # queries that use .join() or .outerjoin().
        q = q.filter(RaceStart.boat.has(BoatModel.class_name == class_name))
        # .has() generates a correlated subquery compatible with bulk .delete().
        # Reference: SQLAlchemy ORM relationship has() condition [B11]
        # Reference: SQLAlchemy ORM delete restriction on joined queries [B12]

    # Perform bulk delete without join (SQLAlchemy restriction).
    deleted = q.delete(synchronize_session=False)
    # synchronize_session=False means SQLAlchemy does not update the in-memory
    # session state for deleted rows — more efficient for bulk deletes.
    # Reference: SQLAlchemy ORM Delete Rules [B12]
    # (Cannot call delete() on queries that use join()/outerjoin().)

    db.commit()
    # Commit the DELETE transaction.

    return {"deleted": deleted}
    # Returns the count of deleted rows so Flutter can confirm the reset.

# Reference: SQLAlchemy ORM delete with filter (no joined delete) [B4]

# Reference: FastAPI application initialization [B1]
# Reference: CORS middleware configuration [B13]
# Reference: APIRouter inclusion [B1]
# Reference: Uvicorn server configuration (runs this app on Railway) [B14]
