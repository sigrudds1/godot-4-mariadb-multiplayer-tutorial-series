#!/usr/bin/env bash

# Files
SCHEMA_FILE="GameSrvrTemplate_no_data_dump_YYYYMMDD_HHMMSS.sql"
DATA_FILE="GameSrvrTemplate_data_YYYYMMDD_HHMMSS.sql"

# Check schema file
if [ -f "$SCHEMA_FILE" ]; then
    sudo mariadb --user=root -p -e "DROP DATABASE GameSrvrTemplate;"
    sudo mariadb --user=root -p < "$SCHEMA_FILE"
else
    echo "Schema file not found: $SCHEMA_FILE"
    exit 1
fi


# Check data file
if [ -f "$DATA_FILE" ]; then
    sudo mariadb --user=root -p GameSrvrTemplate < "$DATA_FILE"
else
    echo "Data file not found: $DATA_FILE"
    exit 1
fi

