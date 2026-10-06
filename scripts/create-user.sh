#!/bin/bash
# Gombey AI - Admin User Creation Script
# Usage: ./create-user.sh <username> <email> <password> [seed-directory]

set -e

CONTAINER_NAME="gombey-ai-portal"

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <username> <email> <password> [seed-directory]"
    echo "Example: $0 johndoe john@example.com SecurePass123! proof-fixtures/property-management-pilot"
    exit 1
fi

USERNAME=$1
EMAIL=$2
PASSWORD=$3
SEED_DIRECTORY=${4:-}

if [ -n "$SEED_DIRECTORY" ] && [ ! -d "$SEED_DIRECTORY" ]; then
    echo "Error: seed directory does not exist: $SEED_DIRECTORY" >&2
    exit 1
fi

echo "Creating user: $USERNAME ($EMAIL)..."

# Pass values as container environment variables instead of interpolating them
# into JavaScript. This prevents usernames, emails, or passwords from becoming
# executable code inside the container.
docker exec -i \
    -e "GOMBEY_USERNAME=$USERNAME" \
    -e "GOMBEY_EMAIL=$EMAIL" \
    -e "GOMBEY_PASSWORD=$PASSWORD" \
    "$CONTAINER_NAME" node <<'NODE'
const { User } = require('./api/models');
const bcrypt = require('bcryptjs');

async function createUser() {
  const { GOMBEY_USERNAME: username, GOMBEY_EMAIL: email, GOMBEY_PASSWORD: password } = process.env;

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({
      username,
      email,
      password: hashedPassword,
      emailVerified: true,
      role: 'user'
    });
    await user.save();
    console.log(`User created successfully: ${email}`);
  } catch (error) {
    if (error.code === 11000) {
      console.error('Error: User already exists (duplicate username or email)');
    } else {
      console.error('Error creating user:', error.message);
    }
    process.exit(1);
  }
}

createUser();
NODE

echo "Done! User can now log in at chat.gombeytech.com"

if [ -n "$SEED_DIRECTORY" ]; then
    echo "Seeding approved onboarding files for $USERNAME..."
    "$(dirname "$0")/seed-user-files.sh" "$USERNAME" "$SEED_DIRECTORY"
fi
