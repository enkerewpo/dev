#!/bin/bash

echo "Please enter the password you want to set:"
read -s password

echo ""

# Use Python with passlib to generate SHA-512 password hash
hash=$(python3 -c "
import hashlib
import os
import base64

# Generate a random salt
salt = os.urandom(16)
salt_b64 = base64.b64encode(salt).decode('ascii')

# Create SHA-512 hash with salt
password_bytes = '$password'.encode('utf-8')
hash_obj = hashlib.sha512(password_bytes + salt)
hash_hex = hash_obj.hexdigest()

# Format as SHA-512 crypt format
print(f'\$6\${salt_b64}\${hash_hex}')
" 2>/dev/null)

# Fallback to crypt if passlib method fails
if [ $? -ne 0 ] || [ -z "$hash" ]; then
    hash=$(python3 -c "
import crypt
import os
salt = '\$6\$' + os.urandom(16).hex()
print(crypt.crypt('$password', salt))
" 2>/dev/null)
fi

echo "Generated password hash:"
echo "$hash"

echo ""
echo "Please copy the hash value above to the hashedPassword field in the loongarch.nix file" 