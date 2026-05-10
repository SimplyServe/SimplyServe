#!/usr/bin/env python3
# Quick test to check password length issue

password = "testpassword123"
print(f"Password: {password}")
print(f"Length: {len(password)} characters")
print(f"Bytes: {len(password.encode('utf-8'))} bytes")

# Check if it's under 72 bytes
if len(password.encode('utf-8')) <= 72:
    print("✅ Password is within bcrypt limit")
else:
    print("❌ Password exceeds bcrypt limit")
