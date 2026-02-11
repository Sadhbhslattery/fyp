"""
db.py – Database configuration for FastAPI and SQLAlchemy

This file is responsible for:
  • Loading the database connection string from environment variables
  • Creating the SQLAlchemy Engine (connection to MySQL)
  • Creating the Base class used for ORM models

It is imported by:
  • app.py  (for get_db dependency)
  • models.py (for declaring ORM models)
"""

import os  # Imports Python's built-in operating system module. This module lets us read 
# environment variables (like DATABASE_URL) that are stored on the server.
from dotenv import load_dotenv  # Imports a function called load_dotenv from the python-dotenv library. 
# This function reads the .env file (a text file containing secret configuration) and makes those values available to my program.
from sqlalchemy import create_engine  # Imports the create_engine function from SQLAlchemy. This function creates the actual connection to MySQL. 
# Think of it as opening a phone line to the database.
from sqlalchemy.orm import sessionmaker, declarative_base
# Imports two important tools: 
# sessionmaker:  A factory that creates database sessions. 
# A session is like a conversation with the database - you open it, do some work (query, insert, update), then close it.
# declarative_base: Creates a base class that all our database table definitions will inherit from. 
# This tells SQLAlchemy 'these classes represent database tables'.


# Load environment variabales 

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

#This line does several things in sequence:
#  1. __file__ is a special Python variable that contains the path to the current file (db.py)
 # 2. os.path.dirname(__file__) gets the directory (folder) containing db.py
 # 3. os.path.join(..., ".env") adds ".env" to that path, creating the full path to the .env file
 # 4. load_dotenv(...) reads that .env file and puts all variables into os.environ
# Example .env file content:
  #DATABASE_URL=mysql+pymysql://root:password@localhost/regatta

# Reference: python-dotenv load_dotenv usage [B6]


# Read database URL from environment.
# This allows switching between:
#   local MySQL
#   remote RDS

DATABASE_URL = os.getenv("DATABASE_URL")
# os.getenv is a function that retrieves an environment variable by name. 
# It's like looking up a value in a dictionary. 
# This line above reads the DATABASE_URL variable that was loaded by load_dotenv().


# This is a safety check. If DATABASE_URL is missing, raise a clear error message immediately.
# Without this, SQLAlchemy create_engine may fail in a confusing way and prevent
# this module from importing (which makes get_db "not found").
if not DATABASE_URL:
    raise RuntimeError(
        "DATABASE_URL is not set. Add it to your .env file, e.g.\n"
        "DATABASE_URL=mysql+pymysql://root:password@localhost/regatta"
    )


# SQLAlchemy Engine

# This creates the engine object, which is SQLAlchemy's main connection to MySQL. 
# Think of it as establishing a phone line that multiple conversations (sessions) can use.

# The parameters do the following:
# pool_pre_ping=True: Before using a database connection from the pool, SQLAlchemy will 'ping' MySQL to check if the connection is still alive. 
# This prevents 'MySQL server has gone away' errors that happen when a connection sits idle too long.

# future=True: Enables SQLAlchemy 2.0-style behavior. 
# This is the modern way of using SQLAlchemy and ensures the code won't break when SQLAlchemy 2.0 becomes the default.
#The engine maintains a 'connection pool' - a set of reusable database connections. 
# Instead of opening a new connection for every request (which is slow), it reuses existing connections.


# Reference: SQLAlchemy create_engine, sessionmaker, declarative_base [B4]
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    future=True,
)


# Creating the Session Factory

# sessionmaker creates a factory - a template for making session objects. Each time we call SessionLocal(), we get a new session.
# The parameters control session behavior:
# bind=engine: Connects this session factory to the engine we created above. 
# Every session made by SessionLocal will use that engine to talk to MySQL.

# autoflush=False: Normally, SQLAlchemy automatically 'flushes' (sends pending changes to the database) before running queries. 
# I turned this off to have more manual control. It will flush when we call db.commit().

# autocommit=False: Changes are not automatically committed (permanently saved) to the database. 
# We must explicitly call db.commit() to save changes. 
# This gives us transaction control - we can make multiple changes and commit them all at once, or roll them all back if there's an error.
# future=True: Same as for the engine - uses SQLAlchemy 2.0 style.

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    future=True,
)


# Creating the Base Class

# This creates the Base class that all the ORM models will inherit from.
# SQLAlchemy knows this is a database table definition because it inherits from Base. 
# Base contains the metadata (information about all the tables) that SQLAlchemy uses to generate SQL statements.

Base = declarative_base()


# FastAPI will call this for each request and then close the session safely.
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# db = SessionLocal(): Creates a new session by calling the factory
# yield db: Pauses this function and gives the session to the endpoint. 
# The endpoint can now use it to query/modify the database.
# finally db.close(): After the endpoint finishes (successfully or with an error), 
# this line runs and closes the session, returning the connection to the pool.
# This pattern ensures every request gets a fresh session, 
# and that session is always properly closed, even if an error occurs.

# END OF FILE

# Summary:

# In summary, db.py creates three critical objects:
# 1. engine: The connection to MySQL with pool management
# 2. SessionLocal: A factory for creating database sessions (conversations with the database)
#3. Base: The parent class that all ORM models inherit from
# These are imported by models.py (to define tables) and app.py (to create sessions and tables).

# Reference: SQLAlchemy engine creation [B4]
# Reference: SQLAlchemy SessionLocal pattern [B7]
# Reference: python-dotenv for environment variables [B5]
# Reference: MySQL connection string format [B6]