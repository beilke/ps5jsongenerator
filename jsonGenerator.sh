#!/bin/bash

# Required configuration via environment variables
: "${OUTPUT_DIR:?Error: OUTPUT_DIR environment variable not set}"
: "${GAME_DIR:?Error: GAME_DIR environment variable not set}"
: "${SERVER_URL:?Error: SERVER_URL environment variable not set}"
: "${JSON_GAMES:?Error: JSON_GAMES environment variable not set}"
: "${JSON_UPDATES:?Error: JSON_UPDATES environment variable not set}"
: "${JSON_DLC:?Error: JSON_DLC environment variable not set}"


# Verify paths
echo "Game Directory: $GAME_DIR"
ls -ld "$GAME_DIR" || { echo "Cannot access game directory"; exit 1; }

CONTAINER_NAME="openorbis-$(date +%s)"

# Start container with Synology-compatible paths
echo "Starting container with Synology path mapping..."
container_id=$(docker run --rm -dit \
  --name "$CONTAINER_NAME" \
  -w /workspace \
  -u $(id -u):$(id -g) \
  -v "$GAME_DIR":/workspace \
  -v "$GAME_DIR/$OUTPUT_DIR":/content_loader \
  openorbisofficial/toolchain) || {
    echo "Failed to start container. Additional debugging:"
    echo "Trying test mount..."
    docker run --rm -v "$GAME_DIR:/test" alpine ls -l /test
    exit 1
}


# Fixed container name
#CONTAINER_NAME="openorbis"

# Create content loader directory structure
CONTENT_LOADER_DIR="$GAME_DIR/$OUTPUT_DIR"
IMG_DIR="$OUTPUT_DIR/covers"

mkdir -p "$CONTENT_LOADER_DIR"
mkdir -p "$CONTENT_LOADER_DIR/covers"

# Set all output files to be in CONTENT_LOADER_DIR
JSON_GAMES="$CONTENT_LOADER_DIR/$JSON_GAMES"
JSON_UPDATES="$CONTENT_LOADER_DIR/$JSON_UPDATES"
JSON_DLC="$CONTENT_LOADER_DIR/$JSON_DLC"

# Validate GAME_DIR exists
if [ ! -d "$GAME_DIR" ]; then
    echo "Error: Game directory does not exist: $GAME_DIR"
    exit 1
fi

# Initialize counters
cGames=0
cDlc=0
cUpd=0

# Debugging: Show extracted values
echo "Game Directory: $GAME_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo "Server URL: $SERVER_URL"
echo "Container Name: $CONTAINER_NAME"
echo "Content Loader Directory: $CONTENT_LOADER_DIR"
echo "JSON Games File: $JSON_GAMES"
echo "JSON Updates File: $JSON_UPDATES"
echo "JSON DLC File: $JSON_DLC"

# Function to clean paths
clean_path() {
    echo "$1" | sed 's|//|/|g' | sed 's|^/||'
}

# Function to update JSON
update_json() {
    local json_file="$1"
    local key="$2"
    local value="$3"
    
    # Create a new file if it doesn't exist
    if [ ! -f "$json_file" ]; then
        echo '{"DATA": {}}' > "$json_file"
    fi
    
    # Update the JSON file
    jq --arg k "$key" --argjson v "$value" '.DATA += {($k): $v}' "$json_file" > tmp.json && mv tmp.json "$json_file"
}

# Function to check if PKG exists in JSON
pkg_exists_in_json() {
    local pkg_name="$1"
    local json_file="$2"
    
    if [ ! -f "$json_file" ]; then
        return 1
    fi
    
    result=$(grep -Fo "$pkg_name" "$json_file" | wc -l)
    [ "$result" -gt 0 ] && return 0 || return 1
}

cleanup_json() {
    local json_file="$1"

    if [ ! -f "$json_file" ] || [ ! -s "$json_file" ]; then
        echo "JSON file $json_file not found or empty. Skipping cleanup."
        return
    fi

    echo "Cleaning $json_file..."
    jq -r '.DATA | keys[]' "$json_file" | while IFS= read -r key; do
        # Convert URL to local path
        local_path=$(echo "$key" | sed "s|^$SERVER_URL||" | sed 's|^/||')
        full_path="$GAME_DIR/$local_path"
        full_path=$(echo "$full_path" | sed 's|//|/|g')  # Normalize path
        
        if [ ! -f "$full_path" ]; then
            echo "Removing missing file: $key"
            jq "del(.DATA[\"$key\"])" "$json_file" > tmp.json && mv tmp.json "$json_file"
        fi
    done
}

# Create json files if they don't exist
for json in "$JSON_GAMES" "$JSON_UPDATES" "$JSON_DLC"; do
    if [ ! -f "$json" ]; then
        echo '{"DATA": {}}' > "$json"
    fi
done

# Remove existing container if it exists
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "Starting OpenOrbis Docker container..."
container_id=$(docker run --rm -dit --name "$CONTAINER_NAME" -w /workspace -u $(id -u):$(id -g) -v "$GAME_DIR":/workspace -v "$CONTENT_LOADER_DIR":/content_loader openorbisofficial/toolchain)
echo "Container started: $container_id"

echo "Searching for PKGs in: $GAME_DIR"
while read -r pkg; do
    pkg_name=$(basename "$pkg")
    pkg_dir=$(dirname "$pkg")
    
    # Check if already processed
    if pkg_exists_in_json "$pkg_name" "$JSON_GAMES" || 
       pkg_exists_in_json "$pkg_name" "$JSON_UPDATES" || 
       pkg_exists_in_json "$pkg_name" "$JSON_DLC"; then
        echo "Skip: $pkg_name already listed."
        continue
    fi
    
    # Handle subdirectories
    if [[ "$pkg_dir" == "$GAME_DIR"* ]]; then
        subdir=$(echo "$pkg_dir" | sed "s|^$GAME_DIR||" | sed 's|^/||')
        [ -n "$subdir" ] && pkg_name="$subdir/$pkg_name"
    fi

    # Process in container
    container_pkg_path="/workspace/$(echo "$pkg_name" | sed 's/\[/\\[/g; s/\]/\\]/g')"
    
    # Get package info
    docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core pkg_listentries "$container_pkg_path" > ./tmpfile1 || continue
    
    param_sfo_index=$(grep "PARAM_SFO" ./tmpfile1 | awk '{print $4}')
    [ -z "$param_sfo_index" ] && continue
    
    sfo_file="/workspace/${pkg_name}.sfo"
    docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core pkg_extractentry "$container_pkg_path" "$param_sfo_index" "$sfo_file" || continue
    
    docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core sfo_listentries "$sfo_file" > ./tmpfile

    # Extract metadata
    category=$(grep "^CATEGORY " ./tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    title_id=$(grep "^TITLE_ID " ./tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    title=$(grep "^TITLE " ./tmpfile | awk -F'=' '{print $2}' | sed 's/^ *//;s/ *$//')    
    version=$(grep "^APP_VER " ./tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    release_tmp=$(grep "^PUBTOOLINFO " ./tmpfile | grep -o "c_date=[0-9]*" | cut -d'=' -f2)
    release=$(echo "$release_tmp" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\2-\3-\1/')
    size=$(stat -c %s "$pkg")
    content_id=$(grep "^CONTENT_ID " ./tmpfile | awk -F'=' '{print $2}' | tr -d ' ')
    region="${content_id:0:1}"
    
    case "$region" in
        "J") region="JAP" ;;
        "E") region="EUR" ;;
        "U") region="USA" ;;
        *) region="null" ;;
    esac

    # Clean URLs
    pkg_url="$SERVER_URL/$(echo "$pkg_name" | sed 's|^/||')"
    cover_url="$SERVER_URL/$IMG_DIR/$title_id.png"    

    # Create JSON entry
    json_entry=$(jq -n \
        --arg title_id "$title_id" \
        --arg region "$region" \
        --arg name "$title" \
        --arg version "$version" \
        --arg release "$release" \
        --argjson size $size \
        --arg cover_url "$cover_url" \
        '{title_id: $title_id, region: $region, name: $name, version: $version, release: $release, size: $size, cover_url: $cover_url}')

    # Handle cover image
    cover_path="$IMG_DIR/$title_id.png"
    if [ ! -f "$cover_path" ]; then
        icon0_index=$(grep 'ICON0_PNG' ./tmpfile1 | awk '{print $4}')
        [ -z "$icon0_index" ] && icon0_index=$(grep 'PIC0_PNG' ./tmpfile1 | awk '{print $4}')
        
        if [ -n "$icon0_index" ]; then
            docker exec "$CONTAINER_NAME" /lib/OpenOrbisSDK/bin/linux/PkgTool.Core pkg_extractentry \
                "$container_pkg_path" "$icon0_index" "/content_loader/covers/$title_id.png"
        fi
    fi

    # Add to appropriate JSON
    case "$category" in
        "gd") 
            echo "Adding GAME: $title"
            update_json "$JSON_GAMES" "$pkg_url" "$json_entry"
            cGames=$((cGames + 1))
            ;;
        "gp") 
            echo "Adding UPDATE: $title"
            update_json "$JSON_UPDATES" "$pkg_url" "$json_entry"
            cUpd=$((cUpd + 1))
            ;;
        "ac") 
            echo "Adding DLC: $title"
            update_json "$JSON_DLC" "$pkg_url" "$json_entry"
            cDlc=$((cDlc + 1))
            ;;
    esac

    # Cleanup
    docker exec "$CONTAINER_NAME" rm -f "$sfo_file"
    rm -f ./tmpfile ./tmpfile1

done < <(find "$GAME_DIR" -type f -name "*.pkg" 2>/dev/null)

# Stop container
docker stop "$CONTAINER_NAME"

# Cleanup JSONs
cleanup_json "$JSON_GAMES"
cleanup_json "$JSON_UPDATES"
cleanup_json "$JSON_DLC"

# Final output
echo "========================="
echo "PKGs added:"
echo "  GAMES: $cGames"
echo "  UPDATES: $cUpd"
echo "  DLCs: $cDlc"
echo ""
echo "Content loader files created in: $CONTENT_LOADER_DIR"
echo "  JSON Files:"
echo "    $JSON_GAMES"
echo "    $JSON_UPDATES"
echo "    $JSON_DLC"
echo "  Cover images: $IMG_DIR"
echo "Processing completed."