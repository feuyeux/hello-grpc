#!/bin/bash
# Master build script for all gRPC language implementations
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Master build script for hello-grpc project"
echo "=========================================="

# Function to build a specific language project
build_project() {
    local project_dir="$1"
    local project_name="$2"
    local build_script="$project_dir/build.sh"
    
    echo ""
    echo "Building $project_name project..."
    
    if [ -d "$project_dir" ] && [ -f "$build_script" ]; then
        # Make build script executable
        chmod +x "$build_script"
        
        # Execute the build script with any additional arguments
        if [ "$CLEAN_BUILD" = true ]; then
            (cd "$project_dir" && ./build.sh --clean "${BUILD_ARGS[@]}")
        else
            (cd "$project_dir" && ./build.sh "${BUILD_ARGS[@]}")
        fi
        
        echo "$project_name build completed successfully."
    else
        echo "Skipping $project_name: directory or build script not found."
    fi
}

# Process command line arguments
CLEAN_BUILD=false
BUILD_ALL=true
SELECTED_LANGS=()
BUILD_ARGS=()

# Define available language projects
LANGUAGES=(
    "cpp"
    "csharp"
    "dart"
    "flutter"
    "go"
    "java"
    "kotlin"
    "nodejs"
    "php"
    "python"
    "rust"
    "swift"
    "ts"
)

# Process arguments
for arg in "$@"; do
    case "$arg" in
        --clean)
            CLEAN_BUILD=true
            ;;
        --help)
            echo "Usage: $0 [options] [languages...]"
            echo ""
            echo "Options:"
            echo "  --clean         Clean before building"
            echo "  --help          Show this help message"
            echo ""
            echo "Languages:"
            echo "  If no languages are specified, all projects will be built."
            echo "  Available languages: ${LANGUAGES[*]}"
            echo ""
            echo "Example:"
            echo "  $0 --clean cpp go java    # Clean and build only C++, Go, and Java projects"
            exit 0
            ;;
        cpp|csharp|dart|flutter|go|java|kotlin|nodejs|php|python|rust|swift|ts)
            # If a language is specified, we're not building all
            BUILD_ALL=false
            SELECTED_LANGS+=("$arg")
            ;;
        *)
            # Pass other arguments to individual build scripts
            BUILD_ARGS+=("$arg")
            ;;
    esac
done

# Print build configuration
echo "Build configuration:"
echo "  Clean build: $CLEAN_BUILD"
if [ "$BUILD_ALL" = true ]; then
    echo "  Building all language projects"
else
    echo "  Building selected languages: ${SELECTED_LANGS[*]}"
fi
echo ""

# Build selected or all projects
build_if_selected() {
    local lang="$1"
    local dir="$2"
    local name="$3"
    
    if [ "$BUILD_ALL" = true ] || [[ " ${SELECTED_LANGS[*]} " == *" $lang "* ]]; then
        build_project "$dir" "$name"
    fi
}

# Build all selected projects
build_if_selected "cpp" "./hello-grpc-cpp" "C++"
build_if_selected "csharp" "./hello-grpc-csharp" "C#"
build_if_selected "dart" "./hello-grpc-dart" "Dart"
build_if_selected "flutter" "./hello_grpc_flutter" "Flutter"
build_if_selected "go" "./hello-grpc-go" "Go"
build_if_selected "java" "./hello-grpc-java" "Java"
build_if_selected "kotlin" "./hello-grpc-kotlin" "Kotlin"
build_if_selected "nodejs" "./hello-grpc-nodejs" "Node.js"
build_if_selected "php" "./hello-grpc-php" "PHP"
build_if_selected "python" "./hello-grpc-python" "Python"
build_if_selected "rust" "./hello-grpc-rust" "Rust"
build_if_selected "swift" "./hello-grpc-swift" "Swift"
build_if_selected "ts" "./hello-grpc-ts" "TypeScript"

echo ""
echo "All requested builds completed successfully!"
