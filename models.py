"""
models.py – SQLAlchemy ORM models for the Regatta System

This file defines all database tables used by the backend.

Each class represents a table:
    • Race
    • Boat
    • Entry
    • Event
    • RaceStart

These models are used throughout the backend for:
    • creating boats
    • storing race starts / finishes
    • storing course selection
    • linking boats to races
    • computing results

All classes inherit from Base imported from db.py.
"""
# Reference: SQLAlchemy ORM declarative models & relationships [B4]
# SQLAlchemy column + type imports
from sqlalchemy import (
    Column, Integer, String, DateTime, ForeignKey, Float, Date, Time
)

# SQLAlchemy relationship constructor for linking tables
from sqlalchemy.orm import relationship

# Base class that all ORM models inherit from
from db import Base



#  RACE TABLE


class Race(Base):
    """
    Represents a planned or active race

    Fields:
        id          Primary key
        name        Name of the race (“Thursday Night Race 1”)
        start_time  When the race begins (set by admin)
        status      PLANNED / ACTIVE / FINISHED
        entries     Relationship to Entry table (boats entered in this race)
    """
    __tablename__ = "races"

    id = Column(Integer, primary_key=True)
    name = Column(String(120))
    start_time = Column(DateTime)
    status = Column(String(20), default="PLANNED")

    # One-to-many: Race - Entries
    entries = relationship("Entry", back_populates="race")
    # Reference: One-to-many relationships with back_populates [B4]



#  BOAT TABLE


class Boat(Base):
    """
    Stores permanent information about each registered boat.

    Fields:
        id              Primary key
        sail_no         Unique identifier written on sails (e.g., IRL5355)
        name            Boat name (“Prince of Tides”)
        club            Yacht club (“RCYC”)
        class_name      Division (White Sail 1, Spinnaker 2…)
        rating_value    Handicap coefficient (IRC/ECHO)
        owner_password  Password for competitor login (plain for now)
        owner_name      Optional owner/helm name
    """
    __tablename__ = "boats"

    id = Column(Integer, primary_key=True)

    sail_no = Column(String(20), unique=True, nullable=False)
    # unique=True ensures no two boats have the same sail number

    name = Column(String(100), nullable=False)
    club = Column(String(100), nullable=True)

    # Fleet division
    class_name = Column(String(50), nullable=False)

    # Handicap used in corrected time calculation
    rating_value = Column(Float, nullable=False)

    # Used for competitor login (kept simple for project purposes)
    owner_password = Column(String(100), nullable=True)
    owner_name = Column(String(100), nullable=True)
 # Reference: Declarative columns and constraints (unique, nullable) [B4][B7]


#  ENTRY TABLE


class Entry(Base):
    """
    Links a boat to a race.
    This is useful for regattas where boats must “enter” a specific race.

    Fields:
        id
        race_id     FK to Race
        boat_id     FK to Boat
        race        Relationship back to Race
    """
    __tablename__ = "entries"

    id = Column(Integer, primary_key=True)

    race_id = Column(Integer, ForeignKey("races.id"))
    boat_id = Column(Integer, ForeignKey("boats.id"))

    # Backlink to Race.entries
    race = relationship("Race", back_populates="entries")



#  EVENT TABLE


class Event(Base):
    """
    Stores optional events recorded during a race:
        • roundings
        • GPS marks
        • penalties
        • OCS events

    Not heavily used in this iteration, but included for completeness and future extension.
    """
    __tablename__ = "events"

    id = Column(Integer, primary_key=True)
    entry_id = Column(Integer, ForeignKey("entries.id"))

    type = Column(String(10))  # e.g. "ROUND", "PENALTY"
    timestamp = Column(DateTime) # When event occurred

class RaceDaySettings(Base):
    """
    Stores "today's race selection" in the database so it survives backend restarts.
    This supports the backup/deputy device user story (Priority 1 #7).
    Reference: SQLAlchemy ORM mapping (Table + Columns)
    """
    __tablename__ = "race_day_settings"

    race_date = Column(Date, primary_key=True)         # e.g. 2025-11-14
    course_id = Column(Integer, nullable=False)        # 1,2,3 from COURSES list
    start_time = Column(String(20), nullable=True)     # store as text for simplicity


#  RACE START TABLE
# Reference: Using Date, Time, Float for race timing data [B4][B5]

class RaceStart(Base):
    """
    Stores start, finish, elapsed and corrected times
    for each boat in each race_day.

    Fields:
        id
        boat_id  - FK to Boat
        race_date  - Date of the race (YYYY-MM-DD)
        start_time  -  Start time (HH:MM:SS)
        finish_time - Finish time (optional)
        elapsed_seconds - Raw elapsed time (finish - start)
        corrected_seconds - Corrected time = elapsed * rating_value
        boat  -  ORM relationship to Boat
    """

    __tablename__ = "race_starts"

    # Primary key
    id = Column(Integer, primary_key=True)

    # Foreign key to Boat table
    boat_id = Column(Integer, ForeignKey("boats.id"), nullable=False)

    # Race date (e.g., 2025-11-14)
    race_date = Column(Date, nullable=False)

    # Start time recorded by admin
    start_time = Column(Time, nullable=False)

    # Finish time (optional)
    finish_time = Column(Time, nullable=True)

    # Computed values (nullable until finished)
    elapsed_seconds = Column(Integer, nullable=True)
    corrected_seconds = Column(Float, nullable=True)

     # NEW: OCS + penalty support (Priority 1 #5)
    ocs = Column(Integer, nullable=False, default=0)      # 0/1 (MySQL TINYINT)
    penalty_seconds = Column(Integer, nullable=True)      # added to elapsed


    # ORM: RaceStart.boat gives full Boat object
    boat = relationship("Boat")
    # Reference: SQLAlchemy one-to-many relationship

# Source for above section: SQLAlchemy ORM mapping/relationships docs : https://fastapi.tiangolo.com/pt/advanced/custom-response/
