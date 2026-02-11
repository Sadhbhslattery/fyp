# Pydantic models validate request bodies and shape API responses.
# FastAPI uses them for validation and OpenAPI docs.

from pydantic import BaseModel
# Imports BaseModel from the Pydantic library. 
# All Pydantic models must inherit from BaseModel. 
# This base class provides automatic validation, serialization (converting Python objects to JSON and vice versa), and error messages when validation fails.
from datetime import date, datetime

class StartSequenceCreate(BaseModel):
    # Defines a Pydantic model for creating start sequences. 
    # This model represents the data required when the race officer starts a countdown.
    class_name: str
    #Declares a required string field for the racing class name (e.g., 'White Sail 1'). 
    # Pydantic validates this is actually a string.
    race_date: date
    prep_flag: str  # "P", "I", "Z", "U", "BLACK"
    # Declares a required string field for the preparatory flag. 
    # The comment lists valid values according to racing rules

class StartSequenceStatus(BaseModel):
    # Defines a model for returning sequence status. 
    # This contains more fields than StartSequenceCreate because it includes computed information from the backend.
    class_name: str
    race_date: date
    prep_flag: str
    # Same fields as StartSequenceCreate - stores the class, date, and flag.
    sequence_start_utc: datetime
    #mStores exactly when the sequence started (when the 5-minute gun fired)
    status: str
    # Current status: RUNNING (countdown active), STARTED (race begun), or CANCELLED (abandoned).
    server_time_utc: datetime
    # Current server time at the moment of request. 
    # This solves clock synchronization - boats can calculate elapsed time by comparing server_time_utc to sequence_start_utc, 
    # ensuring all devices show the same countdown even if their clocks differ.

# Reference: Pydantic BaseModel and field validators [B2]
# Reference: Python datetime module for timestamp handling [B3]
# Reference: Type hints for API contracts [B2]
# Reference: FastAPI request/response model integration [B12]