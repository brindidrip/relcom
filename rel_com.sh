#!/bin/bash

function process_file() {
    local file_a="$1"
    local file_name="$(basename "$file_a")"

    modified_string=$(echo "$file_name" | sed 's/[^a-zA-Z0-9]/_/g')
   
    echo "Checking file name: ${modified_string}"

    # Re-create the associative array from the exported string
    declare -A dir_b_files
    eval "dir_b_files=${DIR_B_FILES_STRING}"
    local file_found=${dir_b_files["${modified_string}"]:-false}

    if [ "$file_found" == false ]; then
        #echo "File not found in Directory B: $file_a"
        local uuid=$(uuidgen)
        # Create the target directory and copy the file
	local randomuuid=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)

        local target_dir="missingno/images/$randomuuid-$file_name"
	#mkdir -p $target_dir
	echo "Moving.."
	echo ""
        #echo "moving file: ${file_a} into the target dir: ${modified_string}"
        mv "$file_a" "$target_dir"
    fi
    #rm "$file_a"
    echo ""
}

export -f process_file

function display_help() {
    echo "Usage: $0 [options] <Directory A> <Directory B>"
    echo ""
    echo "This script compares two directories (Directory A and Directory B) recursively"
    echo "and lists all files from Directory A that are not in Directory B, based on their"
    echo "filename and file type."
    echo ""
    echo "Options:"
    echo "  -t, --types <file types>  Comma-separated list of file types to search (e.g., '.txt,.pdf')."
    echo ""
    echo "Arguments:"
    echo "  <Directory A>  The first directory to compare."
    echo "  <Directory B>  The second directory to compare."
}

file_types=""
while getopts ":t:-:" opt; do
    case $opt in
        t)
            file_types="$OPTARG"
            ;;
        -)
            long_opt="$OPTARG"
            if [[ $long_opt == "types="* ]]; then
                file_types="${long_opt#types=}"
            else
                echo "Unknown option: --$long_opt"
                display_help
                exit 1
            fi
            ;;
        \?)
            echo "Unknown option: -$OPTARG"
            display_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            display_help
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

if [ "$#" -ne 2 ]; then
    display_help
    exit 1
fi

dir_a="$1"
dir_b="$2"

if [ ! -d "$dir_a" ]; then
    echo "Directory A not found: $dir_a"
    exit 1
fi

if [ ! -d "$dir_b" ]; then
    echo "Directory B not found: $dir_b"
    exit 1
fi

# Convert the comma-separated list of file types to an array.
IFS=',' read -ra file_types_arr <<< "$file_types"

# Count the number of files in Directory B
file_count=$(find "$dir_b" -type f | wc -l)

echo "File count in Dir B: $file_count"

grep_pattern="${file_types//,/|}\$"

# Process the files and display a progress bar
#find "$dir_b" -type d -print0 | parallel -0 --no-notice --bar 'find {} -type f -exec basename {} \; 2>/dev/null' | pv -pls "${file_count}" >> "$temp_file"
#find "$dir_b" -type d -print0 | parallel -0 --no-notice --bar 'find {} -type f -print0' | grep -zPi "$grep_pattern" | xargs -0 -I{} basename {} | pv -pls "${file_count}" >> "$temp_file"
#find "$dir_b" -type d -print0 | parallel -0 --no-notice --bar 'find {} -type f -print0 | grep -zPi "'"${grep_pattern}"'" | xargs -0 -I{} basename {}' > "${temp_file}"

dir_b_map="mappings/map${file_types}"

echo $dir_b_map
if [ ! -e "$dir_b_map" ]; then
   temp_file=${dir_b_map}
   # Most performant thus far...
   find "$dir_b" -type d -print0 | parallel -0 --no-notice --bar 'find {} -type f -print0 | grep -zPi "'"${grep_pattern}"'" | xargs -0 -I{} basename {}' > "${temp_file}"
else
    temp_file=${dir_b_map}
fi

temp_result_file=$(mktemp)

awk '{gsub(/[^a-zA-Z0-9]/, "_"); if (!seen[$0]++) print}' "$temp_file" > "$temp_result_file"

# Read the modified lines from the temporary result file
while IFS= read -r modified_string; do
    # Process the modified_string as needed
    echo "$modified_string"
done < "$temp_result_file"

rm -f "$temp_result_file"

# Read the temporary file into an associative array
declare -A dir_b_files
while IFS= read -r file_b; do
    modified_string=$(echo "$file_b" | sed 's/[^a-zA-Z0-9]/_/g')
    dir_b_files["$modified_string"]=1
done < "$temp_file"

# Export associative array as a string
export DIR_B_FILES_STRING=$(declare -p dir_b_files | sed 's/declare -A dir_b_files=//')

#rm "$temp_file"

echo ""
echo ""
echo ""
echo "Processing"


find_cmd="find \"$dir_a\" -type f -print0 | grep -zPi '${file_types//,/|}\$'"
eval "$find_cmd" | parallel -q -0 --bar process_file
#find "$dir_a" -type d -print0 | parallel -0 --no-notice --bar 'find {} -type f -print0 | grep -zPi "'"$grep_pattern"'" | xargs -0 -I{} bash -c "process_file {}"'

exit 0
