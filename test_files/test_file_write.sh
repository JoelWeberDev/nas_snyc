#!/bin/bash

DIR="/home/joel/Development/nas/scripts/test_files"
FILE="open_test.txt"
APPS=( "vim" "nano" "gedit" "cat" "bash" )


write_to_file() {
    echo "Testing write to file"
    echo "This is a test line #$(wc -l < "$DIR/$FILE")" >> "$DIR/$FILE"
    tail -n 1 "$DIR/$FILE"
}

write_to_file