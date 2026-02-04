from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float, Date, Time
from sqlalchemy.orm import relationship
from db import Base

class Race(Base):
    __tablename__ = "races"
    id = Column(Integer, primary_key=True)
    name = Column(String(120))
    start_time = Column(DateTime)
    status = Column(String(20), default="PLANNED")
    entries = relationship("Entry", back_populates="race")

class Boat(Base):
    __tablename__ = "boats"
    id = Column(Integer, primary_key=True)
    sail_no = Column(String(20), unique=True, nullable=False)
    name = Column(String(100), nullable=False)
    club = Column(String(100), nullable=True)
    class_name = Column(String(50), nullable=False)   # White Sail 1, etc.
    rating_value = Column(Float, nullable=False)
    owner_password = Column(String(100), nullable=True)  # plain for now
    owner_name = Column(String(100), nullable=True)



class Entry(Base):
    __tablename__ = "entries"
    id = Column(Integer, primary_key=True)
    race_id = Column(Integer, ForeignKey("races.id"))
    boat_id = Column(Integer, ForeignKey("boats.id"))
    race = relationship("Race", back_populates="entries")

class Event(Base):
    __tablename__ = "events"
    id = Column(Integer, primary_key=True)
    entry_id = Column(Integer, ForeignKey("entries.id"))
    type = Column(String(10))
    timestamp = Column(DateTime)
    gps_lat = Column(Float)
    gps_lng = Column(Float)

class RaceStart(Base):
    __tablename__ = "race_starts"

    id = Column(Integer, primary_key=True)
    boat_id = Column(Integer, ForeignKey("boats.id"), nullable=False)
    race_date = Column(Date, nullable=False)
    start_time = Column(Time, nullable=False)

    finish_time = Column(Time, nullable=True)
    elapsed_seconds = Column(Integer, nullable=True)
    corrected_seconds = Column(Float, nullable=True)

    boat = relationship("Boat")

