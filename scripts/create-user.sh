#!/bin/bash
# Gombey AI - Admin User Creation Script
# Usage: ./create-user.sh <username> <email> <password>

set -e

CONTAINER_NAME="gombey-ai-portal"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <username> <email> <password>"
    echo "Example: $0 johndoe john@example.com SecurePass123!"
    exit 1
fi

USERNAME=$1
EMAIL=$2
PASSWORD=$3

echo "Creating user: $USERNAME ($EMAIL)..."

# Run user creation inside the LibreChat container
docker exec -i $CONTAINER_NAME node -e "
const { User } = require('./api/models');
const bcrypt = require('bcryptjs');

async function createUser() {
  try {
    const hashedPassword = await bcrypt.hash('$PASSWORD', 10);
    const user = new User({
      username: '$USERNAME',
      email: '$EMAIL',
      password: hashedPassword,
      emailVerified: true,
      role: 'user'
    });
    await user.save();
    console.log('User created successfully!');
    console.log('Username: $USERNAME');
    console.log('Email: $EMAIL');
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
"

echo "Done! User can now log in at chat.gombeytech.com"
