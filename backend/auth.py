"""
auth.py — Authentication utilities for SimplyServe.

This module handles all JWT-based authentication and password hashing for
the FastAPI backend. It exposes:

  - `verify_password`       : Compare a plain-text password against a bcrypt
                              hash stored in the database.
  - `get_password_hash`     : Hash a plain-text password with bcrypt before
                              storing it.
  - `create_access_token`   : Mint a signed JWT containing the user's email
                              as the `sub` claim.
  - `get_current_user`      : FastAPI dependency that validates the bearer
                              token on every protected route and returns the
                              corresponding User ORM object.

Token flow
----------
1. The client POSTs credentials to `/token` (OAuth2 password flow).
2. `create_access_token` signs a JWT with HS256 and a 30-minute expiry.
3. The client includes the token in the `Authorization: Bearer <token>`
   header on subsequent requests.
4. `get_current_user` decodes and verifies the token, then loads the user
   from the database so route handlers receive a live User object.

Security note
-------------
`SECRET_KEY` is hard-coded here for development convenience. In a production
deployment it must be replaced with a random value loaded from an environment
variable or secret manager.
"""

from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from sqlalchemy.future import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import User
from schemas import TokenData

# ── JWT configuration ──────────────────────────────────────────────────────────

# Hard-coded signing secret — replace with a random secret in production.
SECRET_KEY = "supersecretkey"

# HMAC-SHA256 is used to sign and verify JWTs. It is symmetric: the same key
# both signs tokens on the server and verifies them on incoming requests.
ALGORITHM = "HS256"

# Tokens expire after 30 minutes of inactivity. After expiry the client must
# log in again via /token to receive a fresh token.
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# ── Password hashing ───────────────────────────────────────────────────────────

# CryptContext wraps passlib's bcrypt hasher. `deprecated="auto"` means that
# if the hash scheme is upgraded in future, old hashes will be transparently
# re-hashed on next login rather than rejected.
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# FastAPI security scheme. `tokenUrl="token"` tells the OpenAPI docs UI where
# to POST credentials to obtain a bearer token, enabling the Authorize button
# in the Swagger interface at /docs.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain-text password against a stored bcrypt hash.

    Args:
        plain_password: The raw password submitted by the user at login.
        hashed_password: The bcrypt hash stored in the `users` table.

    Returns:
        True if the password matches the hash, False otherwise.
    """
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a plain-text password with bcrypt for secure storage.

    Args:
        password: The raw password submitted during registration.

    Returns:
        A bcrypt hash string safe to persist in the database.
    """
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a signed JWT access token.

    The token payload contains:
      - `sub` : The user's email address (subject claim).
      - `exp` : Token expiry timestamp (UNIX epoch).

    Args:
        data: Claims to embed in the token — typically `{"sub": user.email}`.
        expires_delta: Optional custom token lifetime. Falls back to 15 minutes
            if not supplied (the `/token` route always passes 30 minutes).

    Returns:
        A URL-safe Base64-encoded JWT string signed with HS256.
    """
    to_encode = data.copy()

    # Set the expiry claim relative to the current UTC time.
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)

    to_encode.update({"exp": expire})

    # jwt.encode signs the payload dict and returns a compact serialisation
    # string in the format `header.payload.signature`.
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """FastAPI dependency: decode the bearer token and return the active user.

    This function is used as a `Depends(auth.get_current_user)` argument on
    every route that requires authentication. FastAPI automatically extracts
    the token from the `Authorization: Bearer <token>` header, passes it
    here, and injects the returned User object into the route handler.

    Args:
        token: JWT bearer token extracted from the request header by FastAPI.
        db: Active asynchronous database session from `get_db`.

    Returns:
        The User ORM object corresponding to the authenticated user.

    Raises:
        HTTPException (401): If the token is missing, expired, malformed,
            or references an email that no longer exists in the database.
    """
    # Standard 401 exception reused for all token validation failures.
    # A generic detail message avoids leaking whether a token was expired
    # vs. simply invalid.
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # Decode and verify the JWT signature + expiry claim.
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

        # Extract the `sub` (subject) claim, which holds the user's email.
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception

        token_data = TokenData(email=email)
    except JWTError:
        # JWTError is raised for signature failures, expiry, malformed tokens.
        raise credentials_exception

    # Look up the user in the database to ensure the account still exists.
    # This also allows deleted/deactivated accounts to be rejected even if
    # their token has not yet expired.
    result = await db.execute(select(User).where(User.email == token_data.email))
    user = result.scalars().first()

    if user is None:
        raise credentials_exception

    return user
