#!/bin/bash
# =============================================================================
# run_steps_04_to_06.sh - submit steps 4-6 for every time point. For each time
# point, the jobs run in order; different time points run in parallel.
#
#   4. merge replicates           (1 job per time point)
#   5. split into hap1 / hap2     (1 job per time point, after its step 4)
#   6. StringTie2                 (1 job per time point x haplotype, after its step 5)
#
# Needs steps 1-3 to be finished (one BAM per sample in 02_...).
#
# Usage (Gadi login node):
#   bash run_steps_04_to_06.sh          # submit
#   bash run_steps_04_to_06.sh dry      # print the qsub commands only
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
for FILE in "$ASSEMBLY_HAP1" "$ASSEMBLY_HAP2" "$SAMTOOLS" "$STRINGTIE"; do
    [[ -e "$FILE" ]] || { echo "ERROR: not found: $FILE (check 00_config.sh)" >&2; exit 1; }
done
BAMS=$( { ls "$ALIGN_DIR" 2>/dev/null || true; } | { grep '\.mapped_paired\.sorted\.bam$' || true; } )
[[ -n "$BAMS" ]] || { echo "ERROR: no BAMs in $ALIGN_DIR - run steps 1-3 first" >&2; exit 1; }
if ls "$ALIGN_DIR"/*.tmp >/dev/null 2>&1; then
    echo "ERROR: unfinished BAMs (*.tmp) in $ALIGN_DIR - check step 2 logs" >&2; exit 1
fi
# Time point = sample name before the "-" (0-1 -> 0, 12-4 -> 12)
TIMEPOINTS=$(echo "$BAMS" | sed 's/-.*//' | sort -un)
echo "BAMs: $(echo "$BAMS" | wc -l)   Time points: $(for TP in $TIMEPOINTS; do printf "%s " "${TP}${TIMEPOINT_UNIT}"; done)"
for TP in $TIMEPOINTS; do
    echo "  ${TP}${TIMEPOINT_UNIT}: $(echo "$BAMS" | grep "^${TP}-" | sed 's/\.mapped_paired\.sorted\.bam$//' | tr '\n' ' ')"
done

# ---- Record what is being run (reproducibility) -----------------------------
mkdir -p "$LOG_DIR" "$RUN_INFO_DIR"
if [[ "$MODE" != "dry" ]]; then
    STAMP=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$RUN_INFO_DIR/scripts_$STAMP"
    cp "$SCRIPT_DIR"/00_config.sh "$SCRIPT_DIR"/0[4-6]_*.pbs "$0" "$RUN_INFO_DIR/scripts_$STAMP/"
    {
        echo "Submitted steps 4-6: $(date)"
        echo "User: ${USER:-unknown}   Host: $(hostname)"
        echo "Time points: $(for TP in $TIMEPOINTS; do printf "%s " "${TP}${TIMEPOINT_UNIT}"; done)"
        echo "StringTie2 options: -s $STRINGTIE_MIN_SINGLE_EXON_COVERAGE -m $STRINGTIE_MIN_TRANSCRIPT_LENGTH $LIBRARY_STRAND"
        echo
        { "$SAMTOOLS" --version || true; } 2>&1 | head -1
        echo "stringtie $("$STRINGTIE" --version)"
    } > "$RUN_INFO_DIR/run_$STAMP.txt"
    echo "Run record: $RUN_INFO_DIR/run_$STAMP.txt"
fi

# ---- Submit, per time point --------------------------------------------------
for TP in $TIMEPOINTS; do
    NAME=${TP}${TIMEPOINT_UNIT}                        # e.g. 3dpi
    MERGE_JOB=$(submit "$MODE" -N "04_merge_$NAME" -o "$LOG_DIR/04_merge_$NAME.log" -j oe \
                -v "TIMEPOINT=$TP,CONFIG=$CONFIG" "$SCRIPT_DIR/04_merge_replicates_by_timepoint.pbs")
    SPLIT_JOB=$(submit "$MODE" -N "05_split_$NAME" -o "$LOG_DIR/05_split_by_haplotype_$NAME.log" -j oe \
                -W depend=afterok:"$MERGE_JOB" \
                -v "TIMEPOINT=$TP,CONFIG=$CONFIG" "$SCRIPT_DIR/05_split_by_haplotype.pbs")
    LINE="$NAME: merge $MERGE_JOB  split $SPLIT_JOB"
    for HAP in hap1 hap2; do
        ST_JOB=$(submit "$MODE" -N "06_st_${NAME}_$HAP" -o "$LOG_DIR/06_stringtie2_${NAME}_$HAP.log" -j oe \
                 -W depend=afterok:"$SPLIT_JOB" \
                 -v "TIMEPOINT=$TP,HAP=$HAP,CONFIG=$CONFIG" "$SCRIPT_DIR/06_stringtie2_assemble_transcripts.pbs")
        LINE="$LINE  stringtie_$HAP $ST_JOB"
    done
    echo "$LINE"
done

echo
echo "Progress: qstat -u ${USER:-\$USER}      Logs: $LOG_DIR"
