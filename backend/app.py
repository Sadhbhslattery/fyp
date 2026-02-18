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

"""

import csv # Python's built-in CSV library for creating CSV files
import io # Provides StringIO for creating in-memory text buffers (used for CSV generation)

from fastapi.responses import StreamingResponse  # Used to send file downloads to the client
# Reference: FastAPI StreamingResponse for file/CSV downloads [B8]

from datetime import datetime, date, time, timedelta 
# Python's date/time handling library
# datetime: Combined date and time
# date: Date only
# time: Time only
# timedelta: Time differences (for calculating elapsed time)

#  FASTAPI and Pydantic 

from fastapi import FastAPI, Depends, HTTPException
# FastAPI is the web framework
# FastAPI: Main application class
# Depends: Dependency injection (for get_db)
# HTTPException: For returning error responses (404, 400, etc.)
# Reference: FastAPI basic app, middleware & CORS setup [B1]

from fastapi.middleware.cors import CORSMiddleware
# CORS (Cross-Origin Resource Sharing) middleware. 
# This allows the Flutter web app (running on localhost:XXXX) 
# to call the FastAPI backend (running on localhost:8000) without browser security blocking it.

from pydantic import BaseModel, field_validator
# BaseModel: Base class for request/response schemas
# field_validator: Decorator for validating fields
# Reference: Pydantic models & validators [B3]


# SQLAlchemy ORM 
# Reference: SQLAlchemy sessions & ORM patterns [B2][B4]
from sqlalchemy.orm import Session
# Session: type hint for DB session objects coming from SessionLocal

from backend.db import Base, engine, SessionLocal
# Base: For creating tables
# engine: Database engine (MySQL connection) configured in db.py
# SessionLocal: factory for DB sessions (session per request pattern)

from backend.models.base import Race, Event, Boat, RaceStart, RaceDaySettings
# Imports the ORM models defined in models.py. These are used to query and modify database tables.
# Race: race table (not heavily used in this iteration)
# Event: placeholder / future use
# Boat: each competitor boat (sail_no, class_name, rating_value, etc.)
# RaceStart: per boat, per day start/finish and timing info

from backend.routes.start_sequence import router as start_sequence_router
# Imports a router for start sequence endpoints (defined in a separate file).


# Application Setup

app = FastAPI()
# Creates the main FastAPI application instance. 
# This object handles HTTP requests and routing.

app.include_router(start_sequence_router)
# Adds the start_sequence router to the app, making its endpoints available.

app.add_middleware(
    # Configures CORS (Cross-Origin Resource Sharing)
    CORSMiddleware,
    allow_origins=["*"], # Allow all origins (simpler for local dev)
    allow_methods=["*"], # Allow all HTTP methods (GET/POST/PUT/DELETE,…)
    allow_headers=["*"], # Allow all headers (e.g. Content-Type, Authorization)
)

Base.metadata.create_all(engine)
# This is critical! It tells SQLAlchemy to:
# 1. Look at all models that inherit from Base (Race, Boat, etc.
# 2. Generate CREATE TABLE statements for each model
# 3. Execute those statements on the MySQL database (via the engine)

# If a table already exists, SQLAlchemy skips it (won't overwrite). 
# This runs once when the app starts, ensuring all necessary tables exist.

# Reference: SQLAlchemy engine and create_all to create tables [B4]


# Database Session Dependency

# Reference: FastAPI dependency injection with Depends [B1][B2]
def get_db():
    """
    This function is a FastAPI dependency. 
    It's called automatically for every endpoint that has 'db: Session = Depends(get_db)' in its parameters.

    Usage:
        def endpoint(db: Session = Depends(get_db)):
            ...

    This pattern:
      • Opens a new session at the start of the request
      • Yields it to the route handler
      • Ensures the session is closed when finished
    """
    db = SessionLocal()
    # Creates a new database session by calling the SessionLocal factory from db.py.
    try:
        yield db # Pauses here and gives db to the endpoint
    finally:
        db.close() # Always closes the session when done
    # The 'yield' keyword makes this a generator function. 
    # It pauses execution, hands the 'db' session to the endpoint, and resumes after the endpoint finishes. 
    # The 'finally' block ensures the session is closed even if an error occurs



# Healtth Check Endpoints
# Reference: Simple JSON responses in FastAPI path operations [B1]

@app.get("/")
def root():
    """
    Simple root endpoint to check the backend is running.

    Returns:
        {"message": "Backend is running"}
    """
    return {"message": "Backend is running"}


@app.get("/health")
def health():
    """
    Healthcheck endpoint for monitoring / sanity checks.

    Returns:
        {"ok": True}
    """
    return {"ok": True}


# ADMIN LOGIN 

class LoginRequest(BaseModel):
    """
    Request model for admin login.

    Fields:
        username: admin username
        password: admin password
    """
    username: str
    password: str


class LoginResponse(BaseModel):
    """
    Response model for admin login.

    Fields:
        success: True if login is valid
        message: human-readable message
    """
    success: bool
    message: str

# Reference: SQLAlchemy ORM Models Tutorial (for how we might later store users)
# Reference: FastAPI request body models and response_model [B1][B3]

@app.post("/login", response_model=LoginResponse)
def login(body: LoginRequest):
    """
    Simple hard-coded admin login.

    Right now this does NOT check a database. It just verifies:
      username == "admin" and password == "password123"

    In a later iteration this can be replaced with a proper User table + hashing.
    """
    if body.username == "admin" and body.password == "password123":
        return LoginResponse(success=True, message="Login successful")
    else:
        return LoginResponse(success=False, message="Invalid credentials")


# RACES 
# Reference: Pydantic models for races; FastAPI POST/GET endpoints [B1][B3]

class RaceIn(BaseModel):
    """
    Input model for creating a Race.

    Fields:
        name: race name
        start_time: optional start time as datetime
    """
    name: str
    start_time: datetime| None = None


class RaceOut(BaseModel):
    """
    Output model for Race.

    Fields:
        id: race primary key
        name: race name
        status: PLANNED / RUNNING / COMPLETED
    """
    id: int
    name: str
    status: str

    class Config:
        # from_attributes=True tells Pydantic it can build this
        # from a SQLAlchemy ORM object directly (Race instance)
        from_attributes = True


@app.post("/races", response_model=RaceOut)
def create_race(body: RaceIn, db: Session = Depends(get_db)):
    """
    Create a new Race record in the database.

    Steps:
      1. Construct Race ORM object with default status "PLANNED"
      2. Add to session, commit, refresh (so it has an id)
      3. Return it as a RaceOut response
    """
    r = Race(name=body.name, start_time=body.start_time, status="PLANNED")
    db.add(r)
    db.commit()
    db.refresh(r)
    return r


@app.get("/races", response_model=list[RaceOut])
def list_races(db: Session = Depends(get_db)):
    """
    Return all races from the Race table.
    """
    return db.query(Race).all()


# Static Courses
# Reference: FastAPI path operations returning Pydantic models [B1][B3]
# These come from RCYC course card and are used by the UI so the race officer
# can select today's course

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


class CourseModel(BaseModel):
    """
    Pydantic model describing a course entry.

    Fields mirror the dictionaries in COURSES.
    """
    id: int
    name: str
    wind: str
    description: str
    rounds: list[str]


class SelectCourseRequest(BaseModel):
    """
    Request body for selecting today's course.

    course_id: which of the static COURSES to select.
    start_time: race start time as free-form string ("18:30", etc.)
    """
    course_id: int
    # Example formats: "18:30" or "2025-07-01 18:30"
    start_time: str | None = None


class CurrentCourse(BaseModel):
    """
    Model representing the currently selected course.

    Fields:
        course: the CourseModel details
        start_time: optional start time string
    """
    course: CourseModel
    start_time: str | None = None
    race_date: date


# This variable holds the current selected course in memory
# It is updated by /select-course and read by /current-course and the Flutter app
current_course: CurrentCourse | None = None


@app.get("/courses", response_model=list[CourseModel])
def list_courses():
    """
    Return a list of all predefined courses.

    The list is built by converting each dictionary in COURSES
    into a CourseModel using keyword unpacking (**c).
    """
    return [CourseModel(**c) for c in COURSES]


@app.post("/select-course", response_model=CurrentCourse)
def select_course(body: SelectCourseRequest, db: Session = Depends(get_db)):
    """
    Admin picks today's race course.
    Stored in DB so it persists for backup/deputy device and server restarts.
    """
    course_data = next((c for c in COURSES if c["id"] == body.course_id), None)
    if not course_data:
        raise HTTPException(status_code=404, detail="Course not found") 

    today = date.today()

    # Upsert settings row for today
    existing = db.get(RaceDaySettings, today)
    if existing:
        existing.course_id = body.course_id
        existing.start_time = body.start_time
    else:
        existing = RaceDaySettings(
            race_date=today,
            course_id=body.course_id,
            start_time=body.start_time,
        )
        db.add(existing)

    db.commit()

    return CurrentCourse(
        course=CourseModel(**course_data),
        start_time=existing.start_time,
        race_date=today,
    )


@app.get("/current-course", response_model=CurrentCourse)
def get_current_course(db: Session = Depends(get_db)):
    """
    Return the current selected course (for competitors).

    If none selected yet, return 404.
    Reads from DB so it survives restarts 

    Reference: FastAPI dependency injection & response models [B1]
    """
    today = date.today()
    # Retrieve today's race settings from the database
    settings = db.get(RaceDaySettings, today)
    if not settings:
        raise HTTPException(status_code=404, detail="No race selected yet")  

    # Find the matching static course definition
    course_data = next((c for c in COURSES if c["id"] == settings.course_id), None)
    if not course_data:
        raise HTTPException(status_code=404, detail="Course not found")  

    return CurrentCourse(
        course=CourseModel(**course_data),
        start_time=settings.start_time,
        race_date=today,
    )



# BOATS AND FLEET
# Reference: Pydantic field_validator for class_name [B3]
# List of valid fleet divisions; used for validation and UI filters
CLASS_OPTIONS = ["White Sail 1", "White Sail 2", "Spinnaker 1", "Spinnaker 2"]


class BoatIn(BaseModel):
    """
    Input model for creating a boat.

    Fields:
        sail_no: boat's sail number (unique identifier per club)
        name: boat name
        club: optional club name ("RCYC", etc.)
        class_name: one of CLASS_OPTIONS
        rating_value: handicap rating used for corrected time
    """
    sail_no: str
    name: str
    club: str | None = None
    class_name: str
    rating_value: float

    @field_validator("class_name")  # Reference: [B3]
    @classmethod
    def validate_class(cls, v: str) -> str:
        """
        Ensure class_name is one of the valid fleet options.

        Raises:
            ValueError if value is not in CLASS_OPTIONS.
        """
        if v not in CLASS_OPTIONS:
            raise ValueError(f"class_name must be one of {CLASS_OPTIONS}")
        return v


class BoatOut(BaseModel):
    """
    Output model for boat data.

    Fields include DB id so the client can edit/delete specific boats.
    """
    id: int
    sail_no: str
    name: str
    club: str | None
    class_name: str
    rating_value: float

    class Config:
        # Allow creating BoatOut from SQLAlchemy Boat instances
        from_attributes = True


class UserLoginRequest(BaseModel):
    """
    Request body for competitor login.

    They login using:
        sail_no  and  password
    """
    sail_no: str
    password: str


class UserLoginResponse(BaseModel):
    """
    Response body for competitor login.

    Fields:
        success: True if login valid
        message: user-friendly message
        boat: BoatOut of the logged-in boat (or None on failure)
    """
    success: bool
    message: str
    boat: BoatOut | None = None


class BoatUpdate(BaseModel):
    """
    Partial update model for boats.

    All fields are optional. Only fields that are not None
    will be applied in update_boat().
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
        If class_name is provided, validate it's one of CLASS_OPTIONS.
        """
        if v is None:
            return v
        if v not in CLASS_OPTIONS:
            raise ValueError(f"class_name must be one of {CLASS_OPTIONS}")
        return v


@app.post("/user-login", response_model=UserLoginResponse)
def user_login(body: UserLoginRequest, db: Session = Depends(get_db)):
    """
    Competitor login (boat owner) by sail number + password.

    Steps:
      1. Find boat by sail_no.
      2. If no boat found - success=False, "Boat not found".
      3. Check plain-text password against Boat.owner_password.
      4. If mismatch - success=False, "Incorrect password".
      5. If OK - success=True, message and return boat info.
    """
    boat = db.query(Boat).filter(Boat.sail_no == body.sail_no).first()
    if not boat:
        return UserLoginResponse(success=False, message="Boat not found")

    # NOTE: Simple plain-text password check (for prototype)
    # When it is a production system, this should be hashed (e.g. bcrypt)
    if boat.owner_password != body.password:
        return UserLoginResponse(success=False, message="Incorrect password")

    return UserLoginResponse(success=True, message="Login ok", boat=boat)


@app.get("/boats", response_model=list[BoatOut])
# Reference: FastAPI and SQLAlchemy to query/filter and return models [B2][B4]
def list_boats(class_name: str | None = None, db: Session = Depends(get_db)):
    """
    List boats in the fleet.

    Optional query parameter:
        class_name: filter boats by division ("White Sail 1", etc.)

    Results are ordered by sail_no for a tidy UI.
    """
    q = db.query(Boat)
    if class_name:
        q = q.filter(Boat.class_name == class_name)
    return q.order_by(Boat.sail_no).all()


@app.post("/boats", response_model=BoatOut)
def create_boat(body: BoatIn, db: Session = Depends(get_db)):
    """
    Create a new Boat record.

    Steps:
      1. Build Boat ORM object from BoatIn.
      2. Add to database & commit.
      3. Refresh to load generated id.
      4. Return BoatOut to client.
    """
    boat = Boat(
        sail_no=body.sail_no,
        name=body.name,
        club=body.club,
        class_name=body.class_name,
        rating_value=body.rating_value,
    )
    db.add(boat)
    db.commit()
    db.refresh(boat)
    return boat


@app.put("/boats/{boat_id}", response_model=BoatOut)
def update_boat(boat_id: int, body: BoatUpdate, db: Session = Depends(get_db)):
    """
    Update an existing Boat.

    Only fields that are not None in BoatUpdate are applied.
    """
    boat = db.get(Boat, boat_id)
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    # Only update fields that are not None
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

    db.add(boat)
    db.commit()
    db.refresh(boat)
    return boat


@app.delete("/boats/{boat_id}", status_code=204)
def delete_boat(boat_id: int, db: Session = Depends(get_db)):
    """
    Delete a boat by id.

    Returns:
        204 No Content on success.
    """
    boat = db.get(Boat, boat_id)
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    db.delete(boat)
    db.commit()
    # 204 No Content – return no body
    return None


# RACE START / FINISH 

class RaceStartIn(BaseModel):
    """
    Input model for creating/updating a RaceStart record for a boat.

    Fields:
        boat_id: Boat.id foreign key
        race_date: date of the race
        start_time: official start time for that boat
    """
    boat_id: int
    race_date: date
    start_time: time

# Reference: SQLAlchemy Relationships [B11]
# Reference: Pydantic models with date & time fields [B3][B5]



class RaceStartDetailOut(BaseModel):
    """
    Detailed view of a RaceStart record.

    Returned by /race-starts endpoints for admin pages.
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
# Reference: Pydantic models with date & time fields [B3][B5]


class RaceFinishIn(BaseModel):
    """
    Input model when admin presses 'Finish now' for a boat.

    Fields:
        boat_id: which boat
        race_date: which day
        finish_time: recorded time of crossing the line


        ocs: if True, mark boat as On Course Side (OCS)
        penalty_seconds: time penalty to add (e.g. 30)
    """
    boat_id: int
    race_date: date
    finish_time: time

    # coming from the finish options bottom sheet
    ocs: bool | None = None
    penalty_seconds: int | None = None
# Reference: Pydantic models with date & time fields [B3][B5]


class ClassStartIn(BaseModel):
    """
    Input model to set the start time for every boat in a class.

    Used when all boats in White Sail 1 start together, etc.
    """
    class_name: str
    race_date: date
    start_time: time


class RaceResultOut(BaseModel):
    """
    Output model representing race results for a boat in a class.

    Fields:
        boat_id, sail_no, name, class_name, rating_value
        start_time, finish_time
        elapsed_seconds: total elapsed race time in seconds
        corrected_seconds: elapsed * rating_value
        position: finishing position in class (1,2,3…) by corrected time
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
        # Not built directly from a single ORM object, we construct it manually
        from_attributes = False


#  RACE START LISTING 

@app.get("/race-starts", response_model=list[RaceStartDetailOut])
def list_race_starts(
    race_date: date,
    db: Session = Depends(get_db),
):
    """
    Get all RaceStart records for a given race_date.

    Used by admin to see which boats have start/finish times recorded.
    """
    starts = (
        db.query(RaceStart)
        .filter(RaceStart.race_date == race_date)
        .order_by(RaceStart.start_time, RaceStart.boat_id)
        .all()
    )
    return starts
# Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
# Reference: datetime combination and timedelta arithmetic [B5]


#  SINGLE BOAT START 

@app.post("/race-starts", response_model=RaceStartDetailOut)
def upsert_race_start(body: RaceStartIn, db: Session = Depends(get_db)):
    """
    Set or update a single boat's start time.

    If a RaceStart exists for (boat_id, race_date), update it.
    Otherwise, create a new RaceStart record.
    """
    boat = db.get(Boat, body.boat_id)
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    start = (
        db.query(RaceStart)
        .filter(
            RaceStart.boat_id == body.boat_id,
            RaceStart.race_date == body.race_date,
        )
        .first()
    )

    if start:
        # Update existing start time
        start.start_time = body.start_time
    else:
        # Create new record
        start = RaceStart(
            boat_id=body.boat_id,
            race_date=body.race_date,
            start_time=body.start_time,
        )
        db.add(start)

    db.commit()
    db.refresh(start)
    return start


#  CLASS START TIMES

@app.post("/race-starts/class-start", response_model=list[RaceStartDetailOut])
def set_class_start(body: ClassStartIn, db: Session = Depends(get_db)):
    """
    Set the same start time for every boat in a given class.

    Example: all "White Sail 1" boats start at 18:30:00.

    Steps:
      1. Fetch all boats in class_name.
      2. For each boat, upsert RaceStart(start_time=body.start_time).
      3. Commit once.
      4. Return all RaceStart rows for that class & date.
    """
    boats = db.query(Boat).filter(Boat.class_name == body.class_name).all()
    if not boats:
        raise HTTPException(status_code=404, detail="No boats in that class")

    for boat in boats:
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
        else:
            start = RaceStart(
                boat_id=boat.id,
                race_date=body.race_date,
                start_time=body.start_time,
            )
            db.add(start)

    db.commit()

    # Return all RaceStart entries for this date and class
    starts = (
        db.query(RaceStart)
        .join(Boat, RaceStart.boat_id == Boat.id)
        .filter(
            RaceStart.race_date == body.race_date,
            Boat.class_name == body.class_name,
        )
        .all()
    )
    return starts

# Reference: FastAPI Path and Body Params Docs [B1]


# GET BOAT START 

@app.get("/race-starts/boat", response_model=RaceStartDetailOut)
def get_boat_race_start(
    boat_id: int,
    race_date: date,
    db: Session = Depends(get_db),
):
    """
    Get start record for a specific boat on a specific date.

    If none exists, return 404 with a clear message.
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


# ADD penalties 

class PenaltyIn(BaseModel):
    # Input model for applying penalties/OCS to a boat on a given race day. 
    boat_id: int 
    race_date: date
    penalty_seconds: int | None = None  # set to none to clear penalty 
    ocs: bool | None = None  # set to none if not changing 

@app.put("/race-penalty", response_model=RaceStartDetailOut)
def set_penalty(body: PenaltyIn, db: Session = Depends(get_db)):
    """
    Apply OCS and/or a time penalty to a boat for a given race_date.
    Priority 1 #5: "flag OCS/penalties so results reflect official rulings".
    """
    start = (
        db.query(RaceStart)
        .filter(RaceStart.boat_id == body.boat_id, RaceStart.race_date == body.race_date)
        .first()
    )
    if not start:
        raise HTTPException(status_code=404, detail="No race record for boat/date")  

    # Apply changes only if values are provided
    if body.ocs is not None:
        start.ocs = 1 if body.ocs else 0

    if body.penalty_seconds is not None:
        start.penalty_seconds = body.penalty_seconds
    elif body.penalty_seconds is None:
        # If caller explicitly wants to clear, they send null; keep simple:
        pass

    # Recompute corrected if elapsed exists
    boat = db.get(Boat, start.boat_id)
    if boat and start.elapsed_seconds is not None:
        penalty = start.penalty_seconds or 0
        adjusted = start.elapsed_seconds + penalty
        start.corrected_seconds = adjusted * boat.rating_value

    db.commit()
    db.refresh(start)
    return start



#  RECORD FINISH 

@app.post("/race-finish", response_model=RaceStartDetailOut)
def record_finish(body: RaceFinishIn, db: Session = Depends(get_db)):
    """
    Admin presses 'Finish now' for a boat.

    This endpoint:
      • Finds RaceStart entry for boat_id + race_date
      • Sets finish_time
      • Computes elapsed_seconds (taking midnight into account)
      • Computes corrected_seconds = elapsed * rating_value
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

    boat = db.get(Boat, start.boat_id)
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    # Apply OCS / penalty updates if provided in the finish request
    if body.ocs is not None:
        start.ocs = 1 if body.ocs else 0

    if body.penalty_seconds is not None:
        start.penalty_seconds = body.penalty_seconds


    # Set finish time
    start.finish_time = body.finish_time

    # Combine date + start/finish times to form full datetimes
    start_dt = datetime.combine(body.race_date, start.start_time)
    finish_dt = datetime.combine(body.race_date, body.finish_time)

    # If finish crosses midnight and is earlier than start, add a day
    if finish_dt < start_dt:
        finish_dt += timedelta(days=1)

    # Compute elapsed seconds
    elapsed = int((finish_dt - start_dt).total_seconds())
    start.elapsed_seconds = elapsed

    # Apply penalty seconds if present
    penalty = start.penalty_seconds or 0
    adjusted_elapsed = elapsed + penalty

    # If OCS is flagged, I keep corrected_seconds as None (treated as “unplaced”)
    if start.ocs == 1:
        start.corrected_seconds = None
    else:
        start.corrected_seconds = adjusted_elapsed * boat.rating_value

    # Reference: Python datetime timedelta Docs

    db.commit()
    db.refresh(start)
    return start
# Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
# Reference: datetime combination and timedelta arithmetic [B5]


#  Race Results (Per Class)

@app.get("/race-results", response_model=list[RaceResultOut])
def race_results_for_class(
    race_date: date,
    class_name: str,
    db: Session = Depends(get_db),
):
    """
    Return race results for a class on a given date.

    Steps:
      1. Query RaceStart JOIN Boat filtered by race_date + class_name.
      2. Sort rows by corrected_seconds (boats with no finish go last).
      3. Assign finishing positions (1,2,3,...) to boats that have corrected times.
      4. Return list of RaceResultOut objects.

    Used by:
      • RaceResultsPage (admin)
      • UserBoatPage (competitor dashboard)
    """
    rows = (
        db.query(RaceStart, Boat)
        .join(Boat, RaceStart.boat_id == Boat.id)
        .filter(
            RaceStart.race_date == race_date,
            Boat.class_name == class_name,
        )
        .all()
    )

    # Convert to list for sorting
    temp: list[tuple[RaceStart, Boat]] = list(rows)

    def sort_key(item: tuple[RaceStart, Boat]) -> float:
        """
        Sorting key function: use corrected_seconds if available,
        else a very large number so unfinished boats go to the bottom.
        """
        start, _ = item
        # OCS always at the bottom
        if start.ocs == 1:
            return 10**13

        return (
            start.corrected_seconds
            if start.corrected_seconds is not None
            else 10**12  # large sentinel value
        )

    # Sort by corrected time ascending
    temp_sorted = sorted(temp, key=sort_key)

    results: list[RaceResultOut] = []
    position_counter = 1  # Will increment only for boats with valid corrected times

    for start, boat in temp_sorted:
        corr = start.corrected_seconds
        is_ocs = (start.ocs == 1)

        # If corrected time present, assign position; else leave as None
        pos = (position_counter if (corr is not None and not is_ocs) else None)
        if corr is not None and not is_ocs:
            position_counter += 1

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
            )
        )

    return results

# Reference: FastAPI and SQLAlchemy query patterns (join, filter) [B2][B4]
# Reference: datetime combination and timedelta arithmetic [B5]
# Reference: Pydantic models (adding optional fields to response schemas) [B3]
# Reference: World Sailing-style result codes and downstream scoring tools (e.g., Sailwave) [S1]




# Sailwave CSV Export (per race day, per class)

# Sailwave supports importing race results from CSV using field names such as:
# RaceNo, Elapsed, Start, Finish, Laps, Code, Place
# and the guide shows an example CSV header like:
#  raceno, class, sailno, start, finish
# Reference (Sailwave User Guide - Import Results from CSV):

def _time_to_sailwave_str(t: time | None) -> str:
    """
    Convert a Python `datetime.time` into a Sailwave-friendly string.

    Sailwave accepts times like:
    "HH:MM"
    "HH:MM:SS"

    If time is missing, return empty string (Sailwave import can handle blanks).
    Reference (Sailwave Dates & Times formatting rules):
    """
    if t is None:
        return ""
    return t.strftime("%H:%M:%S")


def _seconds_to_elapsed_str(seconds: int | None) -> str:
    """
    Convert elapsed seconds to "HH:MM:SS" for Sailwave Elapsed field.
    If missing, return empty string.
    """
    if seconds is None:
        return ""
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d}"


@app.get("/export/sailwave-race-csv")
def export_sailwave_race_csv(
    race_date: date,
    class_name: str,
    race_no: int,
    db: Session = Depends(get_db),
):
    """
    Export one race (one date) for one class to a Sailwave-compatible CSV.

    How it maps to Sailwave import:
      - RaceNo - `race_no` query param
      - class - `class_name` query param (must match what is used in Sailwave Fleet/Class)
      - sailno - Boat.sail_no
      - start - RaceStart.start_time
      - finish - RaceStart.finish_time
      - elapsed - RaceStart.elapsed_seconds formatted as HH:MM:SS
      - code - OCS/DNF/DNS etc. (currently only output OCS if flagged)
      - place - finishing position (output "position" based on corrected time)

    Sailwave doc: field names (RaceNo, Elapsed, Start, Finish, Code, Place)
    Example header & rows: raceno, class, sailno, start, finish
    """

    # Query the race results using the existing logic (RaceStart JOIN Boat)
    rows = (
        db.query(RaceStart, Boat)
        .join(Boat, RaceStart.boat_id == Boat.id)
        .filter(
            RaceStart.race_date == race_date,
            Boat.class_name == class_name,
        )
        .all()
    )

    # Sort for "place" using the same idea as the /race-results endpoint:
    # - OCS goes to the bottom
    # - boats with no corrected time go last
    temp: list[tuple[RaceStart, Boat]] = list(rows)

    def sort_key(item: tuple[RaceStart, Boat]) -> float:
        start, _ = item
        if start.ocs == 1:
            return 10**13
        return start.corrected_seconds if start.corrected_seconds is not None else 10**12

    temp_sorted = sorted(temp, key=sort_key)

    # Assign places (1,2,3...) only to boats with valid corrected times and not OCS
    place_by_boat_id: dict[int, int] = {}
    place_counter = 1
    for start, boat in temp_sorted:
        if start.ocs == 1:
            continue
        if start.corrected_seconds is None:
            continue
        place_by_boat_id[boat.id] = place_counter
        place_counter += 1

    # Build CSV in memory
    buffer = io.StringIO()
    writer = csv.writer(buffer)

    # Header row:
    # Sailwave is case-insensitive in many mappings but matching their example is safest.
    # Their example uses: raceno, class, sailno, start, finish
    # And they also list additional fields like Elapsed, Code, Place
    writer.writerow(["raceno", "class", "sailno", "start", "finish", "elapsed", "code", "place"])

    for start, boat in temp_sorted:
        # Scoring code:
        # Sailwave supports codes like OCS, DNF, DNS, etc.
        code = ""
        if start.ocs == 1:
            code = "OCS"
        # If you later add DNF/DNS flags to your DB, map them here too.

        place_str = ""
        if boat.id in place_by_boat_id:
            place_str = str(place_by_boat_id[boat.id])

        writer.writerow(
            [
                race_no, # raceno
                class_name, # class
                boat.sail_no, # sailno
                _time_to_sailwave_str(start.start_time),# start
                _time_to_sailwave_str(start.finish_time),# finish
                _seconds_to_elapsed_str(start.elapsed_seconds),# elapsed
                code, # code
                place_str, # place
            ]
        )

    buffer.seek(0)

    # Return as downloadable CSV
    filename = f"sailwave_race_{race_no}_{class_name}_{race_date}.csv".replace(" ", "_")
    headers = {"Content-Disposition": f'attachment; filename="{filename}"'}

    # StreamingResponse is the standard FastAPI/Starlette approach for file-like responses.
    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv",
        headers=headers,
    )

# Reference: Python csv module for writing CSV rows [B8]
# Reference: StreamingResponse for returning downloadable files in FastAPI/Starlette [B9]
# Reference: Content-Disposition header to trigger file download in browsers [B10]



# League Points (low score wins)

class LeaguePointsOut(BaseModel):
    """
    Output row for league points for one boat on one race date.
    """
    race_date: date
    class_name: str
    boat_id: int
    sail_no: str
    name: str
    place: int | None = None # finishing place in class (by corrected time)
    points: int | None = None # points for league (usually same as place)
    code: str | None = None # e.g., "OCS" if applicable


@app.get("/league-points", response_model=list[LeaguePointsOut])
def league_points_for_day(
    race_date: date,
    class_name: str,
    db: Session = Depends(get_db),
):
    """
    Return league points for a single race day & class.

    Logic:
    - Sort by corrected time (like /race-results)
    - Assign place 1..N
    - Points = place (low is best)
    - If OCS: set code="OCS" and give them points = (number of starters + 1)
        (common simple league approach)

    Sailwave supports OCS as an import code (useful consistency).
    """

    rows = (
        db.query(RaceStart, Boat)
        .join(Boat, RaceStart.boat_id == Boat.id)
        .filter(
            RaceStart.race_date == race_date,
            Boat.class_name == class_name,
        )
        .all()
    )

    temp: list[tuple[RaceStart, Boat]] = list(rows)

    def sort_key(item: tuple[RaceStart, Boat]) -> float:
        start, _ = item
        if start.ocs == 1:
            return 10**13
        return start.corrected_seconds if start.corrected_seconds is not None else 10**12

    temp_sorted = sorted(temp, key=sort_key)

    # Count "starters" (has a start_time)
    starters = sum(1 for start, _ in temp_sorted if start.start_time is not None)

    results: list[LeaguePointsOut] = []
    place_counter = 1

    for start, boat in temp_sorted:
        # Default values
        place: int | None = None
        points: int | None = None
        code: str | None = None

        if start.ocs == 1:
            code = "OCS"
            # Simple penalty: worse than last starter
            points = starters + 1
        elif start.corrected_seconds is None:
            # No finish / no corrected time 
            # For now: leave blank
            pass
        else:
            place = place_counter
            points = place_counter
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



#  Reset Race Day

@app.delete("/race-day")
def reset_race_day(
    race_date: date,
    class_name: str | None = None,
    db: Session = Depends(get_db),
):
    """
    Delete race_start records for a given date.

    If class_name is provided, only RaceStart rows for that class are deleted.
    Otherwise, ALL RaceStart rows for the date are deleted.
    This is used by:
      The 'Reset today's timings' button on the RaceStartsPage.
    """
    from models import Boat  # ensure Boat is imported here

    # Base query: all starts on that date
    q = db.query(RaceStart).filter(RaceStart.race_date == race_date)

    if class_name:
        # Filter to starts whose boat is in the given class.
        # Uses relationship-style condition (RaceStart.boat.has(...)).
        q = q.filter(RaceStart.boat.has(Boat.class_name == class_name))

    # Perform bulk delete without join (SQLAlchemy restriction)
    deleted = q.delete(synchronize_session=False)
    db.commit()

    # Reference: SQLAlchemy ORM Delete Rules [B12]
    # (Cannot call delete() on queries that use join()/outerjoin().)

    return {"deleted": deleted}
# Reference: SQLAlchemy ORM delete with filter (no joined delete) [B4]

# Reference: FastAPI application initialization [B1]
# Reference: CORS middleware configuration [B1]
# Reference: APIRouter inclusion [B1]
# Reference: Uvicorn server configuration [B1]