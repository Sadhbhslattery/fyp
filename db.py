"""
db.py – Database configuration for FastAPI + SQLAlchemy

This file is responsible for:
  • Loading the database connection string from environment variables
  • Creating the SQLAlchemy Engine (connection to MySQL)
  • Creating the SessionLocal factory (one DB session per request)
  • Creating the Base class used for ORM models

It is imported by:
  • app.py  (for get_db dependency)
  • models.py (for declaring ORM models)
"""

import os  # Standard library: allows reading environment variables
from dotenv import load_dotenv  # Loads variables from a .env file 
from sqlalchemy import create_engine  # Creates DB engine (MySQL connection)
from sqlalchemy.orm import sessionmaker, declarative_base
# sessionmaker: factory for DB sessions (SessionLocal)
# declarative_base: base class for SQLAlchemy ORM models


#  LOAD ENVIRONMENT VARIABLES 

# Loads environment variables from a `.env` file into os.environ
# Example .env:
#    DATABASE_URL=mysql+pymysql://root:password@localhost/regatta
# Reference: python-dotenv load_dotenv usage [B6]
load_dotenv()


# Read database URL from environment.
# This allows switching between:
#   local MySQL
#   remote RDS

# IMPORTANT: If DATABASE_URL is missing, FastAPI will fail on startup
DATABASE_URL = os.getenv("DATABASE_URL")


#  SQLALCHEMY ENGINE 

# Create the engine object which represents the connection pool
#
# Parameters:
#   pool_pre_ping=True:
#       SQLAlchemy will check stale MySQL connections before using them
#       Prevents "MySQL server has gone away" errors

#   future=True:
#       Enables SQLAlchemy 2.0 style behaviour
# Reference: SQLAlchemy create_engine, sessionmaker, declarative_base [B4]
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    future=True,
)


#  SESSION FACTORY (SessionLocal) 

# SessionLocal creates a *new DB session* for each request
#
# autoflush=False:
#       Prevents automatic flushing before queries. We flush manually on commit
#
# autocommit=False:
#       We control commits ourselves (FastAPI dependency handles commit/close)
#
# future=True:
#       Enables future-compatible SQLAlchemy behaviour
SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    future=True,
)


#  BASE CLASS FOR MODELS 

# All ORM classes inherit from Base
# Example in models.py:
#
#     class Boat(Base):
#         __tablename__ = "boats"
#         id = Column(Integer, primary_key=True)
#
Base = declarative_base()


# END OF FILE

"""
Summary:

This file creates:
    engine       - Connection to MySQL
    SessionLocal - DB session factory used by app.py with Depends(get_db)
    Base         - Used by all SQLAlchemy ORM models
"""
