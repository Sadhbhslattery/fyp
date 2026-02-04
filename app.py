import datetime

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session

from db import Base, engine, SessionLocal
from models import Race, Event, Boat, RaceStart

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create tables on startup if they don't exist
Base.metadata.create_all(engine)
# Reference: SQLAlchemy create_all()

# --- DB DEPENDENCY ------------------------------------------------------


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# --- BASIC HEALTH -------------------------------------------------------


@app.get("/")
def root():
    return {"message": "Backend is running"}


@app.get("/health")
def health():
    return {"ok": True}

# --- LOGIN 
class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    success: bool
    message: str

# Reference: SQLAlchemy ORM Models Tutorial


@app.post("/login", response_model=LoginResponse)
def login(body: LoginRequest):
    # Simple hardcoded admin login for now
    if body.username == "admin" and body.password == "password123":
        return LoginResponse(success=True, message="Login successful")
    else:
        return LoginResponse(success=False, message="Invalid credentials")
# Reference: FastAPI Request Body Docs

# --- RACES --------------------------------------------------------------


class RaceIn(BaseModel):
    name: str
    start_time: datetime.datetime | None = None


class RaceOut(BaseModel):
    id: int
    name: str
    status: str

    class Config:
        from_attributes = True


@app.post("/races", response_model=RaceOut)
def create_race(body: RaceIn, db: Session = Depends(get_db)):
    r = Race(name=body.name, start_time=body.start_time, status="PLANNED")
    db.add(r)
    db.commit()
    db.refresh(r)
    return r


@app.get("/races", response_model=list[RaceOut])
def list_races(db: Session = Depends(get_db)):
    return db.query(Race).all()

# ----------------------------------------------------------------------
# STATIC COURSES (from RCYC course card)
# ----------------------------------------------------------------------

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
    id: int
    name: str
    wind: str
    description: str
    rounds: list[str]


class SelectCourseRequest(BaseModel):
    course_id: int
    # e.g. '18:30', or '2025-07-01 18:30' – just a string for now
    start_time: str | None = None


class CurrentCourse(BaseModel):
    course: CourseModel
    start_time: str | None = None

current_course: CurrentCourse | None = None

@app.get("/courses", response_model=list[CourseModel])
def list_courses():
    """Return the 3 predefined courses."""
    return [CourseModel(**c) for c in COURSES]


@app.post("/select-course", response_model=CurrentCourse)
def select_course(body: SelectCourseRequest):
    """Admin picks today's race course."""
    global current_course

    course_data = next((c for c in COURSES if c["id"] == body.course_id), None)
    if not course_data:
        raise HTTPException(status_code=404, detail="Course not found")

    course = CourseModel(**course_data)
    current_course = CurrentCourse(course=course, start_time=body.start_time)
    return current_course


@app.get("/current-course", response_model=CurrentCourse)
def get_current_course():
    """Current race for competitors."""
    if current_course is None:
        raise HTTPException(status_code=404, detail="No race selected yet")
    return current_course
# Reference: FastAPI Routing Docs

# --- BOATS --------------------------------------------------------------


CLASS_OPTIONS = ["White Sail 1", "White Sail 2", "Spinnaker 1", "Spinnaker 2"]


class BoatIn(BaseModel):
    sail_no: str
    name: str
    club: str | None = None
    class_name: str
    rating_value: float

    @field_validator("class_name") # Reference: Pydantic v2 Field Validator Docs
    @classmethod
    def validate_class(cls, v: str) -> str:
        if v not in CLASS_OPTIONS:
            raise ValueError(f"class_name must be one of {CLASS_OPTIONS}")
        return v


class BoatOut(BaseModel):
    id: int
    sail_no: str
    name: str
    club: str | None
    class_name: str
    rating_value: float

    class Config:
        from_attributes = True

class UserLoginRequest(BaseModel):
    sail_no: str
    password: str

class UserLoginResponse(BaseModel):
    success: bool
    message: str
    boat: BoatOut | None = None

class BoatUpdate(BaseModel):
    sail_no: str | None = None
    name: str | None = None
    club: str | None = None
    class_name: str | None = None
    rating_value: float | None = None

    @field_validator("class_name")
    @classmethod
    def validate_class(cls, v: str | None) -> str | None:
        if v is None:
            return v
        if v not in CLASS_OPTIONS:
            raise ValueError(f"class_name must be one of {CLASS_OPTIONS}")
        return v

@app.post("/user-login", response_model=UserLoginResponse)
def user_login(body: UserLoginRequest, db: Session = Depends(get_db)):
    boat = db.query(Boat).filter(Boat.sail_no == body.sail_no).first()
    if not boat:
        return UserLoginResponse(success=False, message="Boat not found")

    if boat.owner_password != body.password:
        return UserLoginResponse(success=False, message="Incorrect password")

    return UserLoginResponse(success=True, message="Login ok", boat=boat)

@app.get("/boats", response_model=list[BoatOut])
def list_boats(class_name: str | None = None, db: Session = Depends(get_db)):
    q = db.query(Boat)
    if class_name:
        q = q.filter(Boat.class_name == class_name)
    return q.order_by(Boat.sail_no).all()


@app.post("/boats", response_model=BoatOut)
def create_boat(body: BoatIn, db: Session = Depends(get_db)):
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
    boat = db.get(Boat, boat_id)
    if not boat:
        raise HTTPException(status_code=404, detail="Boat not found")

    db.delete(boat)
    db.commit()
    # 204 No Content, so we just return None
    return None

# --- Race Start 
class RaceStartIn(BaseModel):
    boat_id: int
    race_date: datetime.date
    start_time: datetime.time

# Reference: SQLAlchemy Relationships (docs.sqlalchemy.org/orm/relationships)

class RaceStartDetailOut(BaseModel):
    id: int
    boat_id: int
    race_date: datetime.date
    start_time: datetime.time
    finish_time: datetime.time | None = None
    elapsed_seconds: int | None = None
    corrected_seconds: float | None = None

    class Config:
        from_attributes = True


class RaceFinishIn(BaseModel):
    boat_id: int
    race_date: datetime.date
    finish_time: datetime.time


class ClassStartIn(BaseModel):
    class_name: str
    race_date: datetime.date
    start_time: datetime.time


class RaceResultOut(BaseModel):
    boat_id: int
    sail_no: str
    name: str
    class_name: str
    rating_value: float
    start_time: datetime.time | None = None
    finish_time: datetime.time | None = None
    elapsed_seconds: int | None = None
    corrected_seconds: float | None = None  # NEW
    position: int | None = None             # NEW

    class Config:
        from_attributes = False


    class Config:
        from_attributes = False



# All start/finish records for a given date
@app.get("/race-starts", response_model=list[RaceStartDetailOut])
def list_race_starts(
    race_date: datetime.date,
    db: Session = Depends(get_db),
):
    starts = (
        db.query(RaceStart)
        .filter(RaceStart.race_date == race_date)
        .order_by(RaceStart.start_time, RaceStart.boat_id)
        .all()
    )
    return starts


# Set / update a single boat's start time (we keep this, but UI will mostly use class-start)
@app.post("/race-starts", response_model=RaceStartDetailOut)
def upsert_race_start(body: RaceStartIn, db: Session = Depends(get_db)):
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
        start.start_time = body.start_time
    else:
        start = RaceStart(
            boat_id=body.boat_id,
            race_date=body.race_date,
            start_time=body.start_time,
        )
        db.add(start)

    db.commit()
    db.refresh(start)
    return start


# ✅ NEW: set the same start time for every boat in a class (e.g. White Sail 1)
@app.post("/race-starts/class-start", response_model=list[RaceStartDetailOut])
def set_class_start(body: ClassStartIn, db: Session = Depends(get_db)):
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
# Reference: FastAPI Path + Body Params Docs


@app.get("/race-starts/boat", response_model=RaceStartDetailOut)
def get_boat_race_start(
    boat_id: int,
    race_date: datetime.date,
    db: Session = Depends(get_db),
):
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


# Admin presses "Finish" – we record finish and compute elapsed/corrected
@app.post("/race-finish", response_model=RaceStartDetailOut)
def record_finish(body: RaceFinishIn, db: Session = Depends(get_db)):
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

    start.finish_time = body.finish_time

    start_dt = datetime.datetime.combine(body.race_date, start.start_time)
    finish_dt = datetime.datetime.combine(body.race_date, body.finish_time)
    if finish_dt < start_dt:
        finish_dt += datetime.timedelta(days=1)

    elapsed = int((finish_dt - start_dt).total_seconds())
    start.elapsed_seconds = elapsed
    start.corrected_seconds = elapsed * boat.rating_value
    # Reference: Python datetime timedelta Docs
    db.commit()
    db.refresh(start)
    return start


@app.get("/race-results", response_model=list[RaceResultOut])
def race_results_for_class(
    race_date: datetime.date,
    class_name: str,
    db: Session = Depends(get_db),
):
    rows = (
        db.query(RaceStart, Boat)
        .join(Boat, RaceStart.boat_id == Boat.id)
        .filter(
            RaceStart.race_date == race_date,
            Boat.class_name == class_name,
        )
        .all()
    )

    # Sort by corrected_seconds (boats without a finish go at the bottom)
    temp: list[tuple[RaceStart, Boat]] = list(rows)

    def sort_key(item: tuple[RaceStart, Boat]) -> float:
        start, _ = item
        return (
            start.corrected_seconds
            if start.corrected_seconds is not None
            else 10**12  # big number so unfinished go last
        )

    temp_sorted = sorted(temp, key=sort_key)

    results: list[RaceResultOut] = []
    position_counter = 1
    for start, boat in temp_sorted:
        corr = start.corrected_seconds
        pos = position_counter if corr is not None else None
        if corr is not None:
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
            )
        )

    return results
# Reference: SQLAlchemy Query & Sort

@app.delete("/race-day")
def reset_race_day(
    race_date: datetime.date,
    class_name: str | None = None,
    db: Session = Depends(get_db),
):
    """
    Delete all race_start records for a given date.
    If class_name is provided, only that class is cleared.
    """
    from models import Boat  # make sure Boat is imporRted

    # Base query: all race starts on that date
    q = db.query(RaceStart).filter(RaceStart.race_date == race_date)

    # If a class is specified, filter by boats in that class
    if class_name:
        # Use the relationship instead of an explicit join
        q = q.filter(RaceStart.boat.has(Boat.class_name == class_name))

    deleted = q.delete(synchronize_session=False)
    db.commit()
    # Reference: SQLAlchemy ORM Delete Rules (cannot delete with join)

    return {"deleted": deleted}




