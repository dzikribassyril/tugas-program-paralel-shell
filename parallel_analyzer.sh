#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if (( $# != 4 )); then
    printf 'Pemakaian: %s INPUT_DIR HOSTFILE KEYWORD OUTPUT_DIR\n' "$0" >&2
    exit 1
fi

input_dir=$(realpath "$1") || die "Direktori input tidak ditemukan: $1"
hostfile=$(realpath "$2") || die "Hostfile tidak ditemukan: $2"
keyword=$3
output_dir=$(realpath -m "$4")
project_dir=$(dirname "$(realpath "$0")")
worker_script="$project_dir/worker.sh"

[[ -d $input_dir ]] || die "Bukan direktori input: $input_dir"
[[ -f $hostfile ]] || die "Bukan file host: $hostfile"
[[ -n $keyword ]] || die 'Kata kunci tidak boleh kosong'
[[ ! -e $output_dir ]] || die "Direktori output sudah ada; pilih nama baru: $output_dir"
case "$output_dir/" in
    "$input_dir/"*) die 'Output tidak boleh berada di dalam direktori input' ;;
esac

hosts=()
while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line//[[:space:]]/}
    [[ -z $line ]] && continue
    [[ $line =~ ^([a-zA-Z0-9_][a-zA-Z0-9_.-]*@)?[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || die "Host tidak valid: $line"
    hosts+=("$line")
done < "$hostfile"
(( ${#hosts[@]} > 0 )) || die 'Hostfile kosong'

shopt -s nullglob
files=("$input_dir"/*.txt "$input_dir"/*.log)
(( ${#files[@]} > 0 )) || die "Tidak ada file .txt atau .log di: $input_dir"
for file in "${files[@]}"; do
    name=${file##*/}
    [[ $name != *$'\t'* && $name != *$'\n'* ]] || die "Nama file mengandung tab/newline: $name"
    [[ -f $file && -r $file ]] || die "File tidak dapat dibaca: $file"
done

mkdir -p "$(dirname "$output_dir")"
mkdir "$output_dir"
mkdir "$output_dir/manifests"

for ((id=0; id<${#hosts[@]}; id++)); do
    : > "$output_dir/manifests/worker-$id.txt"
done
for ((i=0; i<${#files[@]}; i++)); do
    id=$((i % ${#hosts[@]}))
    printf '%s\n' "${files[i]}" >> "$output_dir/manifests/worker-$id.txt"
done

printf 'File input: %d | Worker: %d | Kata kunci: %s\n' "${#files[@]}" "${#hosts[@]}" "$keyword"
start_ns=$(date +%s%N)
pids=()
for ((id=0; id<${#hosts[@]}; id++)); do
    host=${hosts[id]}
    manifest="$output_dir/manifests/worker-$id.txt"
    result="$output_dir/worker-$id.tsv"
    if [[ $host == localhost || $host == 127.0.0.1 ]]; then
        bash "$worker_script" "$id" "$manifest" "$result" "$keyword" &
    else
        # SSH menjalankan worker di host lain; path proyek/output harus shared.
        printf -v remote_command '%q ' bash "$worker_script" "$id" "$manifest" "$result" "$keyword"
        ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$host" "$remote_command" &
    fi
    pids+=("$!")
done

failed=0
for ((id=0; id<${#pids[@]}; id++)); do
    if wait "${pids[id]}"; then
        printf 'Worker %d (%s): selesai\n' "$id" "${hosts[id]}"
    else
        printf 'Worker %d (%s): GAGAL\n' "$id" "${hosts[id]}" >&2
        failed=1
    fi
done
(( failed == 0 )) || die 'Ada worker yang gagal; hasil tidak digabungkan'

details="$output_dir/details.tsv"
printf 'worker_id\tfile\tlines\twords\tbytes\tmatched_lines\n' > "$details"
for ((id=0; id<${#hosts[@]}; id++)); do
    [[ -f $output_dir/worker-$id.tsv ]] || die "Output worker $id hilang"
    awk 'NR > 1' "$output_dir/worker-$id.tsv" >> "$details"
done
(( $(wc -l < "$details") - 1 == ${#files[@]} )) || die 'Jumlah hasil tidak sesuai dengan jumlah file input'

end_ns=$(date +%s%N)
elapsed=$(awk -v ns="$((end_ns - start_ns))" 'BEGIN { printf "%.3f", ns/1000000000 }')
awk -F '\t' -v workers="${#hosts[@]}" -v elapsed="$elapsed" '
    NR > 1 { files++; lines += $3; words += $4; bytes += $5; matches += $6 }
    END {
        print "metric\tvalue"
        printf "total_files\t%d\n", files
        printf "total_lines\t%.0f\n", lines
        printf "total_words\t%.0f\n", words
        printf "total_bytes\t%.0f\n", bytes
        printf "matched_lines\t%.0f\n", matches
        printf "workers\t%d\n", workers
        printf "elapsed_seconds\t%s\n", elapsed
    }
' "$details" > "$output_dir/summary.tsv"

printf 'Hasil: %s\n' "$output_dir/summary.tsv"
printf 'Waktu eksekusi: %s detik\n' "$elapsed"
