#!/bin/bash
# Description: This script goes through the ledger and the file system directory and queues 
#   new actions to be performed based on the times stamps. This script will run periodically.
#   Each client will constantly run this script to both update and execute actions.

# Imports
source "helper_functions.sh"


# Reading functions

# Add new pull action to ledger
add_pull() {
    local id=$1
    local time=$2
    local action="pull($id)"
    # echo "$time $action" >> "$FS_DIR/$LEDGER_FILE"
}

update() {
    # Keeps all the other info the same, but updates the time with to time stamp of the file in consideration
    # The update function is the one that processes and updates the line based on the new time stamp
    local line_num=$1
    local update_function=$2

    # Get the line
    local line=$(sed -n "${line_num}p" "$FS_DIR/$LEDGER_FILE")
    local output
    output=($(parse_line_vars "$line"))
    local valid=$?
    
    if [ $valid -eq 1 ]; then
        echo "Invalid line"
    else
        # Since the line is valid we will run the process function on the output
        local fname=${output[0]}
        local mod_date=${output[1]}
        local pull_id=${output[2]}
        local push_ids=${output[@]:3}

        # Get the time stamp of the file
        local local_ts=$(get_mod_time "$FS_DIR/$fname")

        # Run the update function
        "${update_func}" "$fname" "$mod_date" "$pull_id" "$push_ids" "$local_ts" "$line_num"
}
