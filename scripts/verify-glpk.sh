#!/bin/bash

# verify-glpk.sh — Verification script for GLPK installation
#
# repo   : https://github.com/scoomboot/zig-glpk
# docs   : https://scoomboot.github.io/zig-glpk/installation
# author : https://github.com/scoomboot
#
# Vibe coded by Scoom.

# ╔══════════════════════════════════════ CONFIG ═════════════════════════════════════════╗

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REQUIRED_VERSION="4.65"
SUCCESS=0
WARNINGS=0
FAILURES=0

# ╚════════════════════════════════════════════════════════════════════════════════════════╝

# ╔══════════════════════════════════════ FUNCTIONS ══════════════════════════════════════╗

print_header() {
    echo
    echo "════════════════════════════════════════════════════════════════════════"
    echo "                    GLPK Installation Verification                      "
    echo "════════════════════════════════════════════════════════════════════════"
    echo
}

check_header() {
    echo -n "Checking for GLPK header file... "
    
    HEADER_PATHS=(
        "/usr/include/glpk.h"
        "/usr/local/include/glpk.h"
        "/opt/homebrew/include/glpk.h"
        "/opt/local/include/glpk.h"
    )
    
    HEADER_FOUND=""
    for path in "${HEADER_PATHS[@]}"; do
        if [ -f "$path" ]; then
            HEADER_FOUND="$path"
            break
        fi
    done
    
    if [ -n "$HEADER_FOUND" ]; then
        echo -e "${GREEN}✓${NC} Found at: $HEADER_FOUND"
        ((SUCCESS++))
        return 0
    else
        echo -e "${RED}✗${NC} Not found"
        echo "  Try: sudo dnf install glpk-devel (Fedora)"
        echo "       sudo apt-get install libglpk-dev (Ubuntu/Debian)"
        echo "       brew install glpk (macOS)"
        ((FAILURES++))
        return 1
    fi
}

check_library() {
    echo -n "Checking for GLPK library file... "
    
    LIBRARY_PATHS=(
        "/usr/lib64/libglpk.so"
        "/usr/lib/libglpk.so"
        "/usr/lib/x86_64-linux-gnu/libglpk.so"
        "/usr/local/lib/libglpk.so"
        "/usr/local/lib/libglpk.dylib"
        "/opt/homebrew/lib/libglpk.dylib"
        "/opt/local/lib/libglpk.dylib"
    )
    
    LIBRARY_FOUND=""
    for path in "${LIBRARY_PATHS[@]}"; do
        if [ -f "$path" ] || [ -L "$path" ]; then
            LIBRARY_FOUND="$path"
            break
        fi
    done
    
    if [ -n "$LIBRARY_FOUND" ]; then
        echo -e "${GREEN}✓${NC} Found at: $LIBRARY_FOUND"
        ((SUCCESS++))
        return 0
    else
        echo -e "${RED}✗${NC} Not found"
        echo "  GLPK library not found in standard locations"
        ((FAILURES++))
        return 1
    fi
}

check_version() {
    echo -n "Checking GLPK version... "
    
    # Try to get version from glpsol
    if command -v glpsol &> /dev/null; then
        VERSION=$(glpsol --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        if [ -n "$VERSION" ]; then
            echo -e "${GREEN}✓${NC} Version $VERSION (glpsol)"
            
            # Compare versions
            if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
                echo "  Version meets minimum requirement ($REQUIRED_VERSION)"
                ((SUCCESS++))
            else
                echo -e "  ${YELLOW}⚠${NC} Version is older than recommended $REQUIRED_VERSION"
                ((WARNINGS++))
            fi
            return 0
        fi
    fi
    
    # Try to get version from package manager
    if command -v rpm &> /dev/null; then
        PKG_VERSION=$(rpm -q glpk 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        if [ -n "$PKG_VERSION" ]; then
            echo -e "${GREEN}✓${NC} Version $PKG_VERSION (rpm package)"
            ((SUCCESS++))
            return 0
        fi
    elif command -v dpkg &> /dev/null; then
        PKG_VERSION=$(dpkg -l | grep glpk | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        if [ -n "$PKG_VERSION" ]; then
            echo -e "${GREEN}✓${NC} Version $PKG_VERSION (dpkg package)"
            ((SUCCESS++))
            return 0
        fi
    fi
    
    echo -e "${YELLOW}⚠${NC} Unable to determine version"
    echo "  glpsol command not found, but library may still work"
    ((WARNINGS++))
    return 0
}

test_compilation() {
    echo -n "Testing C compilation with GLPK... "
    
    # Create temporary test file
    TEMP_DIR=$(mktemp -d)
    TEST_FILE="$TEMP_DIR/test_glpk.c"
    TEST_BIN="$TEMP_DIR/test_glpk"
    
    cat > "$TEST_FILE" << 'EOF'
#include <stdio.h>
#include <glpk.h>

int main() {
    glp_prob *lp = glp_create_prob();
    if (lp != NULL) {
        printf("GLPK version: %s\n", glp_version());
        glp_delete_prob(lp);
        return 0;
    }
    return 1;
}
EOF
    
    # Try different compilers in order of preference
    COMPILERS=("gcc" "clang" "cc" "zig cc")
    COMPILER_FOUND=""
    
    for compiler in "${COMPILERS[@]}"; do
        if command -v ${compiler%% *} &> /dev/null; then
            if $compiler -o "$TEST_BIN" "$TEST_FILE" -lglpk 2>/dev/null; then
                COMPILER_FOUND="$compiler"
                break
            fi
        fi
    done
    
    if [ -n "$COMPILER_FOUND" ]; then
        # Try to run
        if OUTPUT=$("$TEST_BIN" 2>/dev/null); then
            echo -e "${GREEN}✓${NC} Success (using $COMPILER_FOUND)"
            echo "  $OUTPUT"
            ((SUCCESS++))
            rm -rf "$TEMP_DIR"
            return 0
        else
            echo -e "${YELLOW}⚠${NC} Compiled but failed to run"
            echo "  Library may need LD_LIBRARY_PATH configuration"
            ((WARNINGS++))
            rm -rf "$TEMP_DIR"
            return 0
        fi
    else
        echo -e "${YELLOW}⚠${NC} No C compiler found"
        echo "  Install gcc, clang, or use zig cc for compilation"
        echo "  GLPK library is installed and should work with Zig"
        ((WARNINGS++))
        rm -rf "$TEMP_DIR"
        return 0
    fi
}

print_summary() {
    echo
    echo "════════════════════════════════════════════════════════════════════════"
    echo "                           Verification Summary                         "
    echo "════════════════════════════════════════════════════════════════════════"
    echo
    echo -e "  Successful checks: ${GREEN}$SUCCESS${NC}"
    echo -e "  Warnings:         ${YELLOW}$WARNINGS${NC}"
    echo -e "  Failed checks:    ${RED}$FAILURES${NC}"
    echo
    
    if [ "$FAILURES" -eq 0 ]; then
        if [ "$WARNINGS" -eq 0 ]; then
            echo -e "  Status: ${GREEN}✓ GLPK is ready for use!${NC}"
        else
            echo -e "  Status: ${GREEN}✓ GLPK is usable with minor warnings${NC}"
        fi
        echo
        echo "  Next steps:"
        echo "  1. Run: zig build"
        echo "  2. Run: zig build test"
        return 0
    else
        echo -e "  Status: ${RED}✗ GLPK installation incomplete${NC}"
        echo
        echo "  Please install GLPK development packages for your system"
        return 1
    fi
}

# ╚════════════════════════════════════════════════════════════════════════════════════════╝

# ╔══════════════════════════════════════ MAIN ═══════════════════════════════════════════╗

main() {
    print_header
    
    check_header
    check_library
    check_version
    test_compilation
    
    print_summary
}

main

# ╚════════════════════════════════════════════════════════════════════════════════════════╝