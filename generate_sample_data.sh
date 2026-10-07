#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

count=${1:-48}
lines=${2:-20000}
destination=${3:-input}

[[ $count =~ ^[1-9][0-9]*$ && $lines =~ ^[1-9][0-9]*$ ]] || {
    printf 'Pemakaian: %s [JUMLAH_FILE_POSITIF] [BARIS_PER_FILE_POSITIF] [DIREKTORI_BARU]\n' "$0" >&2
    exit 1
}
[[ ! -e $destination ]] || { printf 'Direktori sudah ada: %s\n' "$destination" >&2; exit 1; }

mkdir "$destination"
for ((i=1; i<=count; i++)); do
    printf -v name 'log-%03d.txt' "$i"
    awk -v file="$i" -v lines="$lines" 'BEGIN {
        for (n=1; n<=lines; n++) {
            level = n % 17 == 0 ? "ERROR" : "INFO"
            printf "2026-10-07 09:10:01 %s file=%03d event=%06d service=backend message=processing_request client=web status=active\n", level, file, n
        }
    }' > "$destination/$name"
done
printf 'Data dibuat: %d file x %d baris di %s\n' "$count" "$lines" "$destination"
