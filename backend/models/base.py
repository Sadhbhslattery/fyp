"""
models.py - SQLAlchemy ORM models for the Regatta System

This file defines all database tables used by the backend.

Each class represents a table:
    • Race
    • Boat
    • Entry
    • Event
    • RaceStart
    • Start Sequence

These models are used throughout the backend for:
    • creating boats
    • storing race starts / finishes
    • storing course selection
    • linking boats to races
    • computing results

All classes inherit from Base imported from db.py.
"""
# Reference: SQLAlchemy ORM declarative models & relationships [B4]
# SQLAlchemy column and type imports
from sqlalchemy import (
    Column, Integer, String, DateTime, ForeignKey, Float, Date, Time
)

# SQLAlchemy: Imports the relationship function. 
# This creates connections between tables in Python so I can write boat.race_starts 
# instead of manually joining tables.
from sqlalchemy.orm import relationship

# Imports the Base class that was created in db.py. 
# All model classes will inherit from this
from backend.db import Base


#  Race Table


class Race(Base):
    # Defines a Python class called Race that inherits from Base. 
    # This tells SQLAlchemy 'Race is a database table'.
    """
    Represents a planned or active race

    Fields:
        id  Primary key
        name  Name of the race 
        start_time  When the race begins (set by admin)
        status PLANNED / ACTIVE / FINISHED
        entries  Relationship to Entry table (boats entered in this race)
    """
    __tablename__ = "races"
    # Sets the actual table name in MySQL. 
    # The Python class is Race, but the MySQL table will be called 'races'.

    id = Column(Integer, primary_key=True)
    # Defines a column called 'id' of type Integer. 
    # primary_key=True means:
    # This column uniquely identifies each row
    # MySQL will auto-increment it (1, 2, 3, ...)
    # This column cannot be NULL

    name = Column(String(120))
    # Creates a 'name' column that can hold up to 120 characters. 
    # String(120) maps to VARCHAR(120) in MySQL.

    start_time = Column(DateTime)
    #A column to store both date and time (e.g., '2025-11-14 18:30:00').
    status = Column(String(20), default="PLANNED")
    # A status column with a default value. 
    # If Race is created without specifying status, it will automatically be set to 'PLANNED'.

    entries = relationship("Entry", back_populates="race")
    # Creates a one-to-many relationship. One Race can have many Entry records. 
    # This line doesn't create a column in MySQL - it just creates a Python property. 
    # When we access race.entries, SQLAlchemy will automatically query the Entry table for all rows where race_id equals this race's id.
    # back_populates="race" creates a two-way link - Entry objects have a .race property pointing back.

    # Reference: One-to-many relationships with back_populates [B4]


#  Boat Table


class Boat(Base):
    # Defines the Boat table, which stores information about each competing boat.
    """
    Stores permanent information about each registered boat.

    Fields:
        id  Primary key
        sail_no   Unique identifier written on sails (e.g., IRL5355)
        name   Boat name (“Prince of Tides”)
        club   Yacht club (“RCYC”)
        class_name  Division (White Sail 1, Spinnaker 2…)
        rating_value  Handicap coefficient (IRC/ECHO)
        owner_password  Password for competitor login (plain for now)
    """
    __tablename__ = "boats"
    # The MySQL table will be called 'boats'.

    id = Column(Integer, primary_key=True)
    # Auto-incrementing primary key, same as Race.id.

    sail_no = Column(String(20), unique=True, nullable=False)
    # unique=True ensures no two boats have the same sail number
    # nullable=False: This column cannot be empty (NULL). Every boat must have a sail number.

    name = Column(String(100), nullable=False)
    club = Column(String(100), nullable=True)

    # Fleet division
    class_name = Column(String(50), nullable=False)
    # The boat's racing class/division (e.g., 'White Sail 1', 'Spinnaker 2'). Required.

    # Handicap used in corrected time calculation
    rating_value = Column(Float, nullable=False)
    # corrected_time = elapsed_time × rating_value.

    # Used for competitor login (kept simple for project purposes)
    owner_password = Column(String(100), nullable=True)
    owner_name = Column(String(100), nullable=True)
 # Reference: Declarative columns and constraints (unique, nullable) [B4][B7]


#  Entry Table (Join table)


class Entry(Base):
    # This is a 'join table' or 'link table' that connects Boats to Races. 
    # It represents the relationship: 'This boat is entered in this race.'
    """
    Fields:
        id
        race_id  FK to Race
        boat_id  FK to Boat
        race  Relationship back to Race
    """
    __tablename__ = "entries"

    id = Column(Integer, primary_key=True)

    race_id = Column(Integer, ForeignKey("races.id"))
    # A foreign key linking to the Race table. ForeignKey("races.id") means:
    # This column must contain a value that exists in the races table's id column
    # MySQL will enforce this constraint (you can't insert an entry with race_id=999 if race 999 doesn't exist)

    boat_id = Column(Integer, ForeignKey("boats.id"))
    # Foreign key to the Boat table. This links the entry to a specific boat.

    # Backlink to Race.entries
    race = relationship("Race", back_populates="entries")
    # Creates a Python property so we can access entry.race to get the full Race object. 
    # This is the reverse side of Race.entries.


#  Event Table


class Event(Base):
    # Stores events that occur during a race (mark roundings, penalties, etc.). 
    # Currently not heavily used, but included for future expansion.
    __tablename__ = "events"

    id = Column(Integer, primary_key=True)
    entry_id = Column(Integer, ForeignKey("entries.id"))
    # Links the event to a specific entry (boat in a race).

    type = Column(String(10))  # e.g. "PENALTY"
    timestamp = Column(DateTime) # When event occurred

class RaceDaySettings(Base):
    """
    Stores "today's race selection" in the database so it survives backend restarts.
    This supports the backup/deputy device user story (Priority 1 #7).
    Reference: SQLAlchemy ORM mapping (Table and Columns)
    """
    __tablename__ = "race_day_settings"

    race_date = Column(Date, primary_key=True) # e.g. 2025-11-14
    course_id = Column(Integer, nullable=False) # 1,2,3 from COURSES list in app.py
    start_time = Column(String(20), nullable=True) # store as text for simplicity


# Race Start Table
# Reference: Using Date, Time, Float for race timing data [B4][B5]

class RaceStart(Base):
    # This is the core table for recording race times. 
    # Each row represents one boat's participation in one race day.
    """

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
    # Links to the Boat table. This identifies which boat this record is for.

    # Race date (e.g., 2025-11-14)
    race_date = Column(Date, nullable=False)
    # The date of the race (e.g., 2025-11-14). 
    # Combined with boat_id, this uniquely identifies a boat's participation in a specific race day.

    # Start time recorded by admin
    start_time = Column(Time, nullable=False)

    # Finish time (optional)
    finish_time = Column(Time, nullable=True)
    # When the boat finished. 
    # Initially NULL (None), set when the race officer presses 'Finish' for this boat.

    # Computed values (nullable until finished)
    elapsed_seconds = Column(Integer, nullable=True)
    corrected_seconds = Column(Float, nullable=True)
    # Computed values, calculated when finish time is recorded:
    # elapsed_seconds: Total race time in seconds (finish - start)
    # corrected_seconds: Handicap-adjusted time (elapsed × rating_value)

    # OCS and penalty support (Priority 1 #5)
    ocs = Column(Integer, nullable=False, default=0) # 0/1 (MySQL TINYINT)
    # OCS (On Course Side) flag. 0 = OK, 1 = OCS. 
    # Stored as Integer because MySQL TINYINT (1 byte integer) is efficient for boolean values.
    # Defaults to 0 (not OCS).
    penalty_seconds = Column(Integer, nullable=True) # added to elapsed
    # Time penalty in seconds (e.g., 30 seconds for a rules violation). 
    # Added to elapsed_seconds when calculating corrected_seconds.

    # ORM: RaceStart.boat gives full Boat object
    boat = relationship("Boat")
    # Creates a Python property so we can access race_start.boat to get the full Boat object (with name, sail_no, rating_value, etc.). 
    # This is a one-way relationship (no back_populates).
    # Reference: SQLAlchemy one-to-many relationship

# Source for above section: SQLAlchemy ORM mapping/relationships docs : https://fastapi.tiangolo.com/pt/advanced/custom-response/

class StartSequence(Base):
    # Stores information about start sequences (countdown timers for different classes). 
    # This supports features like displaying which flag is flying and when the gun will fire.

    __tablename__ = "start_sequences"

    id = Column(Integer, primary_key=True)
    class_name = Column(String(50), nullable=False) # Which class this sequence is for (e.g., 'White Sail 1').
    race_date = Column(Date, nullable=False)
    prep_flag = Column(String(10), nullable=False)
    sequence_start_utc = Column(DateTime, nullable=False)
    status = Column(String(20), nullable=False) # Current status (e.g., 'STARTED' after gun).

# Summary of base.py
#models.py defines 7 tables:

# 1. Race: Basic race information (name, start time, status)
# 2. Boat: Boat details (sail number, name, class, handicap, owner password)
# 3. Entry: Links boats to races
# 4. Event: Records events during races (roundings, penalties)
# 5. RaceDaySettings: Stores today's course selection
# 6. RaceStart: Core timing data (start, finish, elapsed, corrected times, OCS, penalties)
# 7. StartSequence: Start countdown information

# Each class defines columns using Column(), foreign keys using ForeignKey(), 
# and relationships using relationship(). 
# SQLAlchemy translates these Python class definitions into CREATE TABLE SQL statements.

# Reference: SQLAlchemy declarative base and column definitions [B4]
# Reference: SQLAlchemy relationships for foreign keys [B9]
# Reference: MySQL DateTime column type [B6]
# Reference: SQLAlchemy String and Integer types [B4]
# Reference: Database schema design for timing data [B7]