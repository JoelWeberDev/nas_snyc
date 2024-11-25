#!/bin/bash
# Date: 2024/11/05
# @Brief: Holds a file open for a duration of time
DIR="/home/joel/Development/nas/scripts/test_files"
FILE="open_test.txt"

hold_file_open_vim() {
    local duration=$1
    echo "Opening file with vim"
    vim.tiny "$DIR$FILE" &
    local vim_pid=$!
    sleep "$duration"
    echo "Closing file"
    kill $vim_pid
}

# hold_file_open_vim 40

hold_file_open_bash() {
    local duration=$1
    echo "Holding file open with bash"
    tail -f "$FILE" &
    local tail_pid=$!
    sleep "$duration"
    kill $tail_pid
    echo "File realesed"
}

hold_file_open_bash 20
