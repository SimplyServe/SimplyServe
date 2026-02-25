from sqlalchemy import Column, Integer, String, Boolean
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)


class Preference(Base):
    __tablename__ = "preference"

    preference_id = Column(Integer, primary_key=True, index=True)
    preference_name = Column(String)
    like = Column(Integer)
