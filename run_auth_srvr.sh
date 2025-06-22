

#!/bin/bash

GODOT_BIN=~/dev/GodotEngine-Builds/Godot_v4.4.1-stable_linux.x86_64
PROJECT_PATH=~/dev/GodotProj/godot-4-mariadb-multiplayer-tutorial-series/authserver

"$GODOT_BIN" --headless --path "$PROJECT_PATH"
