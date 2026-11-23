#!/bin/bash
# =============================================================================
# run_steps_07_to_11.sh - Trinity genome-guided assembly, following Rita's
# Pst104E workflow, starting from the step-5 BAMs (merged per dpi, split by hap).
#
# Per time point x haplotype (each waits for the one before):
#   07 BAM -> paired FASTQ      08 in-silico normalisation
#   10 HISAT2 to own haplotype  11 Trinity genome-guided
# Once per haplotype:
#   09 HISAT2 index of hap1 / hap2 alone (skipped if it already exists)
#
# Usage (Gadi login node):
#   bash run_steps_07_to_11.sh test        # one run: 3dpi hap1 (check settings, time, cost)
#   bash run_steps_07_to_11.sh 8 hap2      # one chosen time point + haplotype
#   bash run_steps_07_to_11.sh all         # all time points x both haplotypes
# Add "dry" at the end to print the qsub commands only.
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG=$SCRIPT_DIR/00_config.sh
source "$CONFIG"

ARGS=("$@")
MODE=run
if [[ ${#ARGS[@]} -gt 0 && "${ARGS[-1]}" == "dry" ]]; then MODE=dry; unset 'ARGS[-1]'; fi
submit() { if [[ "$MODE" == "dry" ]]; then echo "qsub $*" >&2; echo "DRYRUN"; else qsub "$@"; fi; }
die() { echo "ERROR: $*" >&2; exit 1; }

# ---- Which runs ------------------------------------------------------------------
case "${ARGS[0]:-}" in
  test) RUNS="3:hap1" ;;
  all)  RUNS=$(for B in $( { ls "$HAPLOTYPE_DIR" 2>/dev/null || true; } | { grep -E '\.hap[12]\.bam$' || true; } | sort -V); do
                   T=${B%%.*}; H=${B#*.}; H=${H%.bam}; echo "${T%$TIMEPOINT_UNIT}:$H"; done) ;;
  "")   echo "Usage: bash $0 test|all|<timepoint> <hap1|hap2> [dry]" >&2; exit 1 ;;
  *)    [[ "${ARGS[1]:-}" =~ ^hap[12]$ ]] || { echo "Usage: bash $0 <timepoint> <hap1|hap2> [dry]" >&2; exit 1; }
        RUNS="${ARGS[0]%$TIMEPOINT_UNIT}:${ARGS[1]}" ;;
esac
[[ -n "$RUNS" ]] || die "no haplotype BAMs in $HAPLOTYPE_DIR - run steps 4-5 first"

# ---- Checks before submitting anything ------------------------------------------
for R in $RUNS; do
    [[ -f "$HAPLOTYPE_DIR/${R%%:*}${TIMEPOINT_UNIT}.${R##*:}.bam" ]] || die "not found: $HAPLOTYPE_DIR/${R%%:*}${TIMEPOINT_UNIT}.${R##*:}.bam"
done
for F in "$ASSEMBLY_HAP1" "$ASSEMBLY_HAP2" "$HISAT2" "$HISAT2_BUILD" "$SAMTOOLS" "$TRINITY_UTIL/insilico_read_normalization.pl"; do
    [[ -f "$F" ]] || die "not a file: $F (check 00_config.sh)"
done
# Load the Trinity modules in a subshell and check everything Trinity calls is there
CHECK=$( (
    load_trinity_modules >/dev/null 2>&1 || { echo "module load failed: $TRINITY_MODULES"; exit 0; }
    for P in Trinity python jellyfish bowtie2 salmon java samtools; do
        command -v "$P" >/dev/null 2>&1 || printf " %s" "$P"
    done
    python -c "import numpy" >/dev/null 2>&1 || printf " numpy"
) )
[[ -z "$CHECK" ]] || die "after loading the Trinity modules, missing:$CHECK (check TRINITY_MODULES in 00_config.sh)"
echo "Runs: $(for R in $RUNS; do printf "%s " "${R%%:*}${TIMEPOINT_UNIT}_${R##*:}"; done)"

# ---- Record what is being run -----------------------------------------------------
mkdir -p "$LOG_DIR" "$RUN_INFO_DIR"
if [[ "$MODE" != "dry" ]]; then
    STAMP=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$RUN_INFO_DIR/scripts_$STAMP"
    cp "$SCRIPT_DIR"/00_config.sh "$SCRIPT_DIR"/0[789]_*.pbs "$SCRIPT_DIR"/1[01]_*.pbs "$0" "$RUN_INFO_DIR/scripts_$STAMP/"
    {
        echo "Submitted steps 7-11 (Trinity, Rita's workflow): $(date)"
        echo "User: ${USER:-unknown}   Runs: $(echo $RUNS)"
        echo "Normalisation: --min_cov $NORM_MIN_COV --max_cov $NORM_MAX_COV --pairs_together --SS_lib_type $TRINITY_LIBRARY_TYPE"
        echo "Trinity: --genome_guided_max_intron $TRINITY_MAX_INTRON --jaccard_clip --SS_lib_type $TRINITY_LIBRARY_TYPE --max_memory $TRINITY_MAX_MEMORY"
        echo "Modules: $TRINITY_MODULES"
        ( load_trinity_modules >/dev/null 2>&1
          echo "Trinity: $( { Trinity --version 2>&1 || true; } | grep -m1 -i version )"
          echo "python: $(python --version 2>&1), numpy $(python -c 'import numpy; print(numpy.__version__)' 2>&1)" )
        { "$HISAT2" --version || true; } 2>&1 | head -1
        { "$SAMTOOLS" --version || true; } 2>&1 | head -1
    } > "$RUN_INFO_DIR/run_$STAMP.txt"
    echo "Run record: $RUN_INFO_DIR/run_$STAMP.txt"
fi

# ---- Step 9: haplotype indexes (once, only those needed, skip if built) ---------
declare -A INDEX_JOB
for HAP in $(for R in $RUNS; do echo "${R##*:}"; done | sort -u); do
    if [[ -s "$HAP_INDEX_DIR/$HAP/$HAP.1.ht2" ]]; then
        echo "Step 9 index $HAP: already built - skipping"; INDEX_JOB[$HAP]=""
    else
        INDEX_JOB[$HAP]=$(submit -N "09_index_$HAP" -o "$LOG_DIR/09_hisat2_index_$HAP.log" -j oe \
                          -v "HAP=$HAP,CONFIG=$CONFIG" "$SCRIPT_DIR/09_hisat2_index_per_haplotype.pbs")
        echo "Step 9 index $HAP: ${INDEX_JOB[$HAP]}"
    fi
done

# ---- Steps 7, 8, 10, 11 per time point x haplotype ------------------------------
for R in $RUNS; do
    TP=${R%%:*}; HAP=${R##*:}; NAME=${TP}${TIMEPOINT_UNIT}_${HAP}; V="TIMEPOINT=$TP,HAP=$HAP,CONFIG=$CONFIG"
    J7=$(submit -N "07_reads_$NAME" -o "$LOG_DIR/07_bam_to_reads_$NAME.log" -j oe \
         -v "$V" "$SCRIPT_DIR/07_bam_to_reads_by_haplotype.pbs")
    J8=$(submit -N "08_norm_$NAME" -o "$LOG_DIR/08_normalise_$NAME.log" -j oe \
         -W depend=afterok:"$J7" -v "$V" "$SCRIPT_DIR/08_normalise_reads.pbs")
    DEP10="afterok:$J8"; [[ -n "${INDEX_JOB[$HAP]}" ]] && DEP10="$DEP10:${INDEX_JOB[$HAP]}"
    J10=$(submit -N "10_align_$NAME" -o "$LOG_DIR/10_align_normalised_$NAME.log" -j oe \
          -W depend="$DEP10" -v "$V" "$SCRIPT_DIR/10_hisat2_align_normalised_reads.pbs")
    J11=$(submit -N "11_trinity_$NAME" -o "$LOG_DIR/11_trinity_$NAME.log" -j oe \
          -W depend=afterok:"$J10" -v "$V" "$SCRIPT_DIR/11_trinity_genome_guided.pbs")
    echo "$NAME: 07 $J7  08 $J8  10 $J10  11 $J11"
done

echo
echo "Progress: qstat -u ${USER:-\$USER}      Logs: $LOG_DIR"
