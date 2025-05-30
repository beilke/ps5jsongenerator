# PS5 JSON Generator

This project automates the generation of JSON metadata and cover images for PlayStation 5 (and PS4) PKG files. It is designed to run in a Docker container and can be triggered manually or as part of a scheduled job.

## Features

- **Automatic PKG Scanning:**
  - Recursively scans a specified game directory for `.pkg` files (games, updates, DLCs).

- **Metadata Extraction:**
  - Uses the OpenOrbis PkgTool to extract SFO metadata (title, title ID, version, release date, region, etc.) from each PKG.

- **Cover Image Extraction:**
  - Extracts cover images (ICON0.PNG or PIC0.PNG) from PKG files and saves them in a dedicated covers directory.

- **JSON Generation:**
  - Generates and updates three JSON files (`GAMES.json`, `UPDATES.json`, `DLC.json`) with all relevant metadata for each PKG, organized by type.

- **Duplicate Detection:**
  - Skips PKG files already present in the JSON files to avoid duplicate entries.

- **Cleanup:**
  - Removes entries from JSON files if the corresponding PKG file is missing from disk.

- **Dockerized Workflow:**
  - Runs all operations inside a Docker container for consistency and portability.
  - The container runs the script once and then exits.

- **Configurable via Environment Variables:**
  - All paths and URLs are set via environment variables or a `.env` file:
    - `GAME_DIR`: Directory containing PKG files
    - `OUTPUT_DIR`: Output directory for JSON and covers
    - `SERVER_URL`: Base URL for serving files
    - `JSON_GAMES`, `JSON_UPDATES`, `JSON_DLC`: Output JSON filenames

## Usage

1. **Configure Environment:**
   - Edit the `.env` file to set your paths and URLs.

2. **Build the Docker Image:**
   ```sh
   docker build -t ps5jsongenerator .
   ```

3. **Run the Container:**
   ```sh
   docker run --rm --env-file .env -v /your/games:/volume1/games/ps4 -v /your/output:/volume1/games/ps4/_ps5ContentLoader ps5jsongenerator
   ```
   - Adjust the volume paths as needed for your setup.

4. **Output:**
   - JSON files and cover images will be created in the output directory you specified.

## File Structure

- `jsonGenerator.sh` — Main shell script for scanning, extracting, and generating JSON/cover files.
- `dockerfile` — Docker build instructions for the environment and dependencies.
- `.env` — Environment variable configuration.
- `GAMES.json`, `UPDATES.json`, `DLC.json` — Output files (created at runtime).
- `covers/` — Directory for extracted cover images.

## Requirements

- Docker (Linux containers)
- Bash-compatible environment (for running the script)

## Credits

- Uses [OpenOrbis](https://openorbis.github.io/) PkgTool for PKG and SFO extraction.

---
This project is intended for archival, educational, and homebrew purposes only. Do not use with copyrighted or unauthorized content.
