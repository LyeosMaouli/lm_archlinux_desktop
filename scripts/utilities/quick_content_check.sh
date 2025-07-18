#!/bin/bash
# scripts/utilities/quick_violations_check.sh

echo "🚫 Quick Violations Check"
echo "========================"

violations=0

# Check for common forbidden files
echo "📄 Checking for forbidden files..."
FORBIDDEN_PATTERNS=(
    "*.tmp" "*.bak" "*~" "*.log"
    ".DS_Store" "Thumbs.db"
    "*.pyc" "__pycache__"
    "*.key" "*.pem"
    "node_modules" "venv"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    found=$(find . -name "$pattern" -not -path "./.git/*" 2>/dev/null)
    if [ -n "$found" ]; then
        echo "  🚫 Found forbidden: $pattern"
        echo "$found" | sed 's/^/    /'
        violations=$((violations + 1))
    fi
done

# Check for misplaced scripts in root
echo -e "\n📍 Checking for misplaced items..."
root_scripts=$(find . -maxdepth 1 -name "*.sh" 2>/dev/null)
if [ -n "$root_scripts" ]; then
    echo "  📍 Scripts in root (should be in scripts/):"
    echo "$root_scripts" | sed 's/^/    /'
    violations=$((violations + 1))
fi

# Check for scattered configs
scattered_configs=$(find . -maxdepth 1 -name "*.yml" -o -name "*.yaml" -o -name "*.json" | grep -v -E "(requirements\.txt|Makefile|\.gitignore)" 2>/dev/null)
if [ -n "$scattered_configs" ]; then
    echo "  📍 Config files in root (should be in configs/):"
    echo "$scattered_configs" | sed 's/^/    /'
    violations=$((violations + 1))
fi

# Summary
echo -e "\n📊 Summary:"
if [ $violations -eq 0 ]; then
    echo "  ✅ No violations found!"
else
    echo "  ⚠️  $violations violation types found"
    echo "  💡 Run 'make validate-comprehensive' for detailed analysis"
fi

exit $violations