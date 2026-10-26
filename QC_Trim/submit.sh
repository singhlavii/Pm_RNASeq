#!/bin/bash
# =============================================================================
# submit.sh - submit fastp for every sample, then MultiQC once they all succeed.
#
# Usage (on a Gadi login node, from anywhere):
#   bash /g/data/xf3/ls9057/Pmelanocephala/RNAseq/scripts/submit.sh qc      # QC report only
#   bash /g/data/xf3/ls9057/Pmelanocephala/RNAseq/scripts/submit.sh trim    # trim + report
#
# Add "dry" as a second argument to print the qsub commands without submitting.
# =============================================================================
set -euo pipefail

MODE=${1:-}
DRY=${2:-}
[[ "$MODE" == "qc" || "$MODE" == "trim" ]] || { echo "Usage: bash $0 qc|trim [dry]" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG=$SCRIPT_DIR/config.sh
source "$CONFIG"

# ---- Checks before submitting anything ---------------------------------------
# (command -v works for both a full path and a module-loaded program name)
command -v "$FASTP"   >/dev/null || { echo "ERROR: fastp not found: $FASTP (check config.sh)" >&2; exit 1; }
command -v "$MULTIQC" >/dev/null || { echo "ERROR: multiqc not found: $MULTIQC (check config.sh)" >&2; exit 1; }
echo "Using $($FASTP --version 2>&1)"

mapfile -t SAMPLES < <(find "$RAW_DIR" -maxdepth 1 -name "*_R1.fastq.gz" -printf "%f\n" \
                       | sed 's/_R1\.fastq\.gz$//' | sort -V)
[[ ${#SAMPLES[@]} -gt 0 ]] || { echo "ERROR: no *_R1.fastq.gz files in $RAW_DIR" >&2; exit 1; }

BROKEN=$(find "$RAW_DIR" -maxdepth 1 -xtype l | wc -l)
[[ $BROKEN -eq 0 ]] || { echo "ERROR: $BROKEN broken links in $RAW_DIR" >&2; exit 1; }

echo "Mode: $MODE   Samples: ${#SAMPLES[@]}"
mkdir -p "$LOG_DIR"

run() { if [[ "$DRY" == "dry" ]]; then echo "qsub $*" >&2; echo "DRYRUN.$RANDOM"; else qsub "$@"; fi; }

# ---- One fastp job per sample ------------------------------------------------
JOB_IDS=()
for S in "${SAMPLES[@]}"; do
    ID=$(run -N "fastp_${MODE}_${S}" \
             -o "$LOG_DIR/fastp_${MODE}_${S}.log" -j oe \
             -v "MODE=$MODE,SAMPLE=$S,CONFIG=$CONFIG" \
             "$SCRIPT_DIR/fastp.pbs")
    JOB_IDS+=("$ID")
    echo "  $S -> $ID"
done

# ---- MultiQC, held until every fastp job has finished successfully ----------
DEPEND=$(IFS=:; echo "${JOB_IDS[*]}")
MQC_ID=$(run -N "multiqc_${MODE}" \
             -o "$LOG_DIR/multiqc_${MODE}.log" -j oe \
             -W depend=afterok:"$DEPEND" \
             -v "MODE=$MODE,CONFIG=$CONFIG" \
             "$SCRIPT_DIR/multiqc.pbs")
echo "  MultiQC -> $MQC_ID (waits for all fastp jobs)"
echo
echo "Check progress with: qstat -u \$USER"
