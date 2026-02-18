# This file defines HTTP endpoints (URLs) that the Flutter app calls. It contains two endpoints:
# POST /start-sequence/start: Race officer starts a sequence
# GET /start-sequence/status: Boats check sequence status

from fastapi import APIRouter, Depends, HTTPException
# Imports three FastAPI components:
# APIRouter: Groups related endpoints together
# Depends: Dependency injection for database sessions
# HTTPException: Returns HTTP error responses (like 404 Not Found)
from sqlalchemy.orm import Session
# Imports Session type for type hints, enabling IDE autocomplete.
from datetime import datetime, timezone
# Imports datetime tools: datetime for timestamps, timezone for UTC.

from backend.db import get_db
# Imports the get_db function that provides database sessions via dependency injection.

from backend.models.start_sequence import StartSequence
from backend.schemas.start_sequence import StartSequenceCreate, StartSequenceStatus
# Imports the StartSequence ORM model representing the start_sequences table.

router = APIRouter(
    # Creates a new router to hold start sequence endpoints.
    prefix="/start-sequence",
    # All endpoints in this router get '/start-sequence' prepended. 
    # For example, @router.post('/start') becomes POST /start-sequence/start.
    tags=["Start Sequence"],
    # Tags endpoints for documentation grouping in /docs.
)


# POST: Admin fires 5-minute gun

@router.post("/start", response_model=StartSequenceStatus)
# Registers a POST endpoint at /start-sequence/start.
def start_sequence(payload: StartSequenceCreate, db: Session = Depends(get_db)):
    seq = StartSequence(
        class_name=payload.class_name,
        rrace_date=payload.race_date,
        prep_flag=payload.prep_flag,
        sequence_start_utc=datetime.now(timezone.utc),
        status="RUNNING",
)
    
    # Creates a new StartSequence object with provided fields plus:
    # sequence_start_utc=datetime.now(timezone.utc) - Current time in UTC, marking when the 5-minute gun fired
    # status="RUNNING" - Indicates the countdown is active


    db.add(seq)  # Stages the object for insertion (doesn't execute SQL yet).
    db.commit()  # Executes the SQL INSERT, permanently saving the record.
    db.refresh(seq)  # Refreshes the object from database to get auto-generated ID.

    now = datetime.now(timezone.utc)

    return {
        "id": seq.id,
        "class_name": seq.class_name,
        "race_date": seq.race_date,
        "prep_flag": seq.prep_flag,
        "sequence_start_utc": seq.sequence_start_utc,
        "status": seq.status,
        "server_time_utc": now,
    # Returns a dictionary with all sequence details. FastAPI converts this to JSON.
    }



# GET: Boats read the active sequence

@router.get("/status", response_model=StartSequenceStatus)
# Registers a GET endpoint at /start-sequence/status.
def get_sequence_status(
    class_name: str, race_date: str, db: Session = Depends(get_db)):
    try:
        race_date_parsed = date.fromisoformat(race_date)
    except ValueError:
        raise HTTPException(status_code=422, detail="race_date must be YYYY-MM-DD")

    seq = (
        db.query(StartSequence)
        .filter(
            StartSequence.class_name == class_name,
            StartSequence.race_date == race_date,
            StartSequence.status == "RUNNING",
        )
        .order_by(StartSequence.sequence_start_utc.desc())
        .first()
    # Queries for active sequences matching the class, date, and status='RUNNING'. 
    # Orders by start time descending (newest first) and gets the first result.
    )
    # SQL generated:
    # SELECT * FROM start_sequences
    # WHERE class_name=? AND race_date=? AND status='RUNNING'
    # ORDER BY sequence_start_utc DESC LIMIT 1


    if not seq:
        raise HTTPException(status_code=404, detail="No active start sequence")
    # If no sequence found, raise HTTPException(404) with message "No active start sequence".
    return {
        "class_name": seq.class_name,
        "race_date": seq.race_date,
        "prep_flag": seq.prep_flag,
        "sequence_start_utc": seq.sequence_start_utc,
        "status": seq.status,
        "server_time_utc": datetime.now(timezone.utc),
    }

# Reference: FastAPI routing and APIRouter [B1]
# Reference: FastAPI query parameters [B11]
# Reference: FastAPI response models [B12]
# Reference: SQLAlchemy ORM queries and filters [B4]
# Reference: SQLAlchemy relationships [B9]
# Reference: Python timezone handling with UTC [B10]
# Reference: Pydantic request/response validation [B2]
# Reference: HTTP exceptions for error handling [B1]