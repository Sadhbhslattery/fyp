# Stores the live start sequence per class for a given race day.
# Admin writes it once (5-min gun). Users read it repeatedly.

from sqlalchemy import Column, Integer, String, Date, DateTime
from sqlalchemy.sql import func
from database import Base  # your existing declarative base

class StartSequence(Base):
    __tablename__ = "start_sequences"

    id = Column(Integer, primary_key=True, index=True)

    # e.g. "Spinnaker 1"
    class_name = Column(String(50), nullable=False, index=True)

    # e.g. 2026-02-04
    race_date = Column(Date, nullable=False, index=True)

    # e.g. "P", "I", "Z", "U", "BLACK"
    prep_flag = Column(String(10), nullable=False, default="P")

    # When the admin pressed the 5-minute gun (server-side, UTC)
    sequence_start_utc = Column(DateTime(timezone=True), nullable=False)

    # "RUNNING" or "STOPPED"
    status = Column(String(20), nullable=False, default="RUNNING")

    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
