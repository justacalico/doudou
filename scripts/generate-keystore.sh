#!/bin/bash

# Script to generate Android release keystore for Doudou app
# Run this script from the project root directory

echo "🔐 Generating Android Release Keystore for Doudou"
echo "=================================================="

# Prompt for keystore details
read -p "Enter your name (e.g., John Doe): " USER_NAME
read -p "Enter your organization (e.g., Your Company): " ORG_NAME
read -p "Enter your city: " CITY
read -p "Enter your state/province: " STATE
read -p "Enter your country code (e.g., US): " COUNTRY

echo ""
echo "⚠️  IMPORTANT: Remember these passwords! You'll need them for every app update."
echo ""

# Generate keystore
keytool -genkey -v -keystore android/app/key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias doudou \
    -dname "CN=$USER_NAME, OU=$ORG_NAME, O=$ORG_NAME, L=$CITY, S=$STATE, C=$COUNTRY"

echo ""
echo "✅ Keystore generated successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Keep your key.jks file safe and NEVER commit it to version control"
echo "2. Create environment variables for the passwords:"
echo "   export KEYSTORE_PASSWORD='your_keystore_password'"
echo "   export KEY_PASSWORD='your_key_password'"
echo "   export KEY_ALIAS='doudou'"
echo "   export KEYSTORE_PATH='android/app/key.jks'"
echo ""
echo "3. For production builds, you can also create a key.properties file:"
echo "   storePassword=your_keystore_password"
echo "   keyPassword=your_key_password"
echo "   keyAlias=doudou"
echo "   storeFile=key.jks"
echo ""
echo "🚨 SECURITY REMINDER:"
echo "   - Never share your keystore or passwords"
echo "   - Store them securely (password manager recommended)"
echo "   - Make a backup of your keystore file"
echo "   - If you lose this keystore, you cannot update your app on the Play Store!"
