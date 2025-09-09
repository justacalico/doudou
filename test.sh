#!/bin/bash

# Kotlin DSL AGP Version Fix Script
# Specifically handles settings.gradle.kts syntax errors

echo "🔧 Fixing Kotlin DSL Android Gradle Plugin syntax errors..."

SETTINGS_FILE="android/settings.gradle.kts"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "❌ $SETTINGS_FILE not found"
    exit 1
fi

echo "📝 Current problematic lines in $SETTINGS_FILE:"
grep -n "com.android" "$SETTINGS_FILE" || echo "No com.android lines found"

# Create backup
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%s)"
echo "✅ Created backup of $SETTINGS_FILE"

# Fix the malformed syntax step by step
echo "🔧 Fixing malformed syntax..."

# Step 1: Fix doubled id(" id(" patterns
sed -i 's/id(" id("/id("/g' "$SETTINGS_FILE"

# Step 2: Fix multiple apply false statements
sed -i 's/) version.*apply false.*apply false/) version "8.7.0" apply false/g' "$SETTINGS_FILE"

# Step 3: Fix any remaining malformed version strings
sed -i 's/version "8\.7\.3.*apply false/version "8.7.0" apply false/g' "$SETTINGS_FILE"

# Step 4: Ensure proper Kotlin DSL syntax for AGP
sed -i 's/id("com\.android\.application").*version.*"8\.7\.3"/id("com.android.application") version "8.7.0"/g' "$SETTINGS_FILE"
sed -i 's/id("com\.android\.library").*version.*"8\.7\.3"/id("com.android.library") version "8.7.0"/g' "$SETTINGS_FILE"

# Step 5: Handle any remaining 8.7.3 references
sed -i 's/8\.7\.3/8.7.0/g' "$SETTINGS_FILE"

# Step 6: Ensure lines end properly
sed -i 's/apply false.*$/apply false/g' "$SETTINGS_FILE"

echo "🔍 Fixed lines in $SETTINGS_FILE:"
grep -n -A1 -B1 "com.android" "$SETTINGS_FILE" || echo "No com.android lines found after fix"

# Validate the syntax
echo "🧪 Validating Kotlin DSL syntax..."

# Check for common syntax errors
if grep -q 'id(" id(' "$SETTINGS_FILE"; then
    echo "⚠️  Still found doubled id patterns"
fi

if grep -q 'version.*version' "$SETTINGS_FILE"; then
    echo "⚠️  Still found doubled version patterns"
fi

if grep -q 'apply false.*apply false' "$SETTINGS_FILE"; then
    echo "⚠️  Still found doubled apply false patterns"
fi

# Show the plugins block if it exists
echo "📋 Current plugins block:"
echo "------------------------"
awk '/plugins \{/,/\}/' "$SETTINGS_FILE" 2>/dev/null || echo "No plugins block found"
echo "------------------------"

echo ""
echo "✅ Kotlin DSL syntax fix completed!"
echo ""
echo "📝 Expected syntax should look like:"
echo "plugins {"
echo '    id("com.android.application") version "8.7.0" apply false'
echo '    id("com.android.library") version "8.7.0" apply false'
echo '    id("org.jetbrains.kotlin.android") version "2.1.0" apply false'
echo "}"
echo ""
echo "🚀 Next steps:"
echo "1. Review the fixed file: cat $SETTINGS_FILE"
echo "2. Test locally: cd android && ./gradlew --version"
echo "3. If issues persist, manually edit $SETTINGS_FILE"
echo "4. Backup is saved as: $SETTINGS_FILE.backup.*"