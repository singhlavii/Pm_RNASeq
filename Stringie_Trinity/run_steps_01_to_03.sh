#!/bin/bash
# =============================================================================
# run_steps_01_to_03.sh - submit steps 1-3 in one go. Each step waits for the
# previous one to finish successfully.
#
#   1. build HISAT2 index        (1 job)
#   2. align each sample         (1 job per sample, after step 1)
#   3. check strandedness        (1 job, after all of step 2)
#
# Usage (Gadi login node):
#   bash run_steps_01_to_03.sh          # submit
#   bash run_steps_01_to_03.sh dry      # print the qsub commands only
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG=$SCRIPT_DIR/00_config.sh
source "$CONFIG"

submit() {
    if [[ "${1:-}" == "dry" ]]; then shift; echo "qsub $*" >&2; echo "DRYRUN"; else shift; qsub "$@"; fi
}
MODE=${1:-run}

# ---- Checks before submitting anything --------------------------------------
for FILE in "$ASSEMBLY_HAP1_HAP2" "$HISAT2" "$HISAT2_BUILD" "$SAMTOOLS"; do
    [[ -e "$FILE" ]] || { echo "ERROR: not found: $FILE (check 00_config.sh)" >&2; exit 1; }
done
python3 "$HISAT2_BUILD" --version >/dev/null 2>&1 \
    || { echo "ERROR: 'python3 $HISAT2_BUILD --version' failed" >&2; exit 1; }
SAMPLES=$( { ls "$TRIMMED_READS_DIR" 2>/dev/null || true; } | { grep '_R1.trimmed.fastq.gz$' || true; } \
          | sed 's/_R1.trimmed.fastq.gz$//' | sort -V)
[[ -n "$SAMPLES" ]] || { echo "ERROR: no trimmed reads in $TRIMMED_READS_DIR" >&2; exit 1; }
echo "Samples ($(echo "$SAMPLES" | wc -w)): $(echo $SAMPLES)"

# ---- Record what is being run (reproducibility) -----------------------------
mkdir -p "$LOG_DIR" "$RUN_INFO_DIR"
if [[ "$MODE" != "dry" ]]; then
    STAMP=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$RUN_INFO_DIR/scripts_$STAMP"
    cp "$SCRIPT_DIR"/00_config.sh "$SCRIPT_DIR"/0[1-3]_*.pbs "$0" "$RUN_INFO_DIR/scripts_$STAMP/"
    {
        echo "Submitted: $(date)"
        echo "User: ${USER:-unknown}   Host: $(hostname)"
        echo "Assembly: $ASSEMBLY_HAP1_HAP2"
        echo "Samples: $(echo $SAMPLES)"
        echo
        { "$HISAT2" --version || true; } 2>&1 | head -1
        { "$SAMTOOLS" --version || true; } 2>&1 | head -1
    } > "$RUN_INFO_DIR/run_$STAMP.txt"
    echo "Run record: $RUN_INFO_DIR/run_$STAMP.txt"
fi

# ---- Step 1: index ------------------------------------------------------------
INDEX_JOB=$(submit "$MODE" -N 01_index -o "$LOG_DIR/01_hisat2_build_index.log" -j oe \
            -v "CONFIG=$CONFIG" "$SCRIPT_DIR/01_hisat2_build_index.pbs")
echo "Step 1 index:   $INDEX_JOB"

# ---- Step 2: align each sample (after step 1) --------------------------------
ALIGN_JOBS=""
for SAMPLE in $SAMPLES; do
    JOB=$(submit "$MODE" -N "02_align_$SAMPLE" -o "$LOG_DIR/02_hisat2_align_$SAMPLE.log" -j oe \
          -W depend=afterok:"$INDEX_JOB" \
          -v "SAMPLE=$SAMPLE,CONFIG=$CONFIG" "$SCRIPT_DIR/02_hisat2_align_sample.pbs")
    ALIGN_JOBS="$ALIGN_JOBS:$JOB"
    echo "Step 2 align $SAMPLE: $JOB"
done

# ---- Step 3: strandedness (after all of step 2) ------------------------------
STRAND_JOB=$(submit "$MODE" -N 03_strand -o "$LOG_DIR/03_check_strandedness.log" -j oe \
             -W depend=afterok"$ALIGN_JOBS" \
             -v "CONFIG=$CONFIG" "$SCRIPT_DIR/03_check_strandedness.pbs")
echo "Step 3 strand:  $STRAND_JOB"

echo
echo "Progress: qstat -u ${USER:-\$USER}      Logs: $LOG_DIR"
