#!/bin/bash
# =============================================================================
# submit_maprate.sh - what fraction of each sample's reads come from the assembly?
#
# Submits, in order (each waits for the previous one to succeed):
#   1. build the HISAT2 index        (skipped if it already exists)
#   2. map each sample               (one job per sample)
#   3. table of alignment rates + MultiQC report
#
# Usage (Gadi login node):
#   bash scripts/submit_maprate.sh          # submit
#   bash scripts/submit_maprate.sh dry      # show what would be submitted
# =============================================================================
set -euo pipefail

DRY=${1:-}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG=$SCRIPT_DIR/maprate_config.sh
source "$CONFIG"

die() { echo "ERROR: $*" >&2; exit 1; }
run() { if [[ "$DRY" == "dry" ]]; then echo "qsub $*" >&2; echo "DRYRUN.$RANDOM"; else qsub "$@"; fi; }

# ---- Checks ------------------------------------------------------------------
for P in "$HISAT2" "$HISAT2_BUILD" "$MULTIQC"; do
    [[ -x "$P" ]] || die "program not found: $P (check maprate_config.sh)"
done
mapfile -t SAMPLES < <(find "$TRIM_DIR" -maxdepth 1 -name "*_R1.trimmed.fastq.gz" -printf "%f\n" \
                       | sed 's/_R1\.trimmed\.fastq\.gz$//' | sort -V)
[[ ${#SAMPLES[@]} -gt 0 ]] || die "no *_R1.trimmed.fastq.gz files in $TRIM_DIR"
mkdir -p "$LOG_DIR" "$OUT_DIR"

echo "Using $($HISAT2 --version | head -1 | sed 's/.*version/hisat2 version/')"
echo "Samples: ${#SAMPLES[@]}   Reads per sample: ${N_READS:-all}"

# ---- 1. Index (only if not built yet) ------------------------------------------
DEP=()
if [[ -s "$INDEX_PREFIX.1.ht2" || -s "$INDEX_PREFIX.1.ht2l" ]]; then
    echo "Index already exists at $INDEX_PREFIX - skipping"
else
    [[ -s "$GENOME_FA" ]] || die "genome not found: $GENOME_FA (check maprate_config.sh)"
    [[ "$GENOME_FA" != *.gz ]] || die "GENOME_FA must be uncompressed (gunzip it first)"
    IDX=$(run -N maprate_index -o "$LOG_DIR/maprate_index.log" -j oe \
              -v "CONFIG=$CONFIG" "$SCRIPT_DIR/maprate_index.pbs")
    echo "  index -> $IDX"
    DEP=(-W depend=afterok:"$IDX")
fi

# ---- 2. Map each sample (waits for the index, if it is being built) ----------
IDS=()
for S in "${SAMPLES[@]}"; do
    ID=$(run -N "maprate_$S" -o "$LOG_DIR/maprate_$S.log" -j oe "${DEP[@]}" \
             -v "SAMPLE=$S,CONFIG=$CONFIG" "$SCRIPT_DIR/maprate_map.pbs")
    IDS+=("$ID"); echo "  $S -> $ID"
done

# ---- 3. Summary table + MultiQC, after all mapping jobs succeed -------------
ALL=$(IFS=:; echo "${IDS[*]}")
SUM=$(run -N maprate_summary -o "$LOG_DIR/maprate_summary.log" -j oe \
          -W depend=afterok:"$ALL" -v "CONFIG=$CONFIG" "$SCRIPT_DIR/maprate_summary.pbs")
echo "  summary -> $SUM"
echo
echo "Check progress: qstat -u \$USER"
echo "Result:         $OUT_DIR/maprate_summary.tsv"
