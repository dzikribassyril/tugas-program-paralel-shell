#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if (( $# != 4 )); then
    printf 'Pemakaian: %s WORKER_ID MANIFEST OUTPUT_FILE KEYWORD\n' "$0" >&2
    exit 1
fi

id=$1
manifest=$2
result=$3
keyword=$4
[[ -f $manifest ]] || { printf 'Worker %s: manifest tidak ditemukan\n' "$id" >&2; exit 1; }

printf 'worker_id\tfile\tlines\twords\tbytes\tmatched_lines\n' > "$result"
while IFS= read -r file || [[ -n $file ]]; do
    [[ -f $file && -r $file ]] || { printf 'Worker %s: file tidak dapat dibaca: %s\n' "$id" "$file" >&2; exit 1; }
    # Satu pemindaian per file. matched_lines = baris yang mengandung keyword literal.
    awk -v worker="$id" -v filename="${file##*/}" -v keyword="$keyword" '
        { lines++; words += NF; bytes += length($0) + 1; if (index($0, keyword)) matches++ }
        END { printf "%s\t%s\t%d\t%d\t%d\t%d\n", worker, filename, lines, words, bytes, matches }
    ' "$file" >> "$result"
done < "$manifest"
