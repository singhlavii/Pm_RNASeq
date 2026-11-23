# =============================================================================
# 00_config.sh - all paths and settings for the transcript assembly workflow
# (RNA-seq evidence for genome annotation of P. melanocephala).
# Every script reads this file. Change settings here only.
# =============================================================================

# ---- Project ----------------------------------------------------------------
PROJECT_DIR=/g/data/xf3/ls9057/Pmelanocephala/RNAseq
TRIMMED_READS_DIR=$PROJECT_DIR/trimmed_fastq          # <sample>_R1/_R2.trimmed.fastq.gz

# ---- Reference: dikaryotic assembly (18 chromosomes x 2 haplotypes) ---------
ASSEMBLY_DIR=/g/data/xf3/ls9057/Pmelanocephala/assembly/hifiasm_30Gb/final
ASSEMBLY_HAP1_HAP2=$ASSEMBLY_DIR/Pm_hap12_20261008.fasta
ASSEMBLY_HAP1=$ASSEMBLY_DIR/Pm_hap1_20261008.fasta
ASSEMBLY_HAP2=$ASSEMBLY_DIR/Pm_hap2_20261008.fasta

# ---- Output folders (numbered in the order they are made) -------------------
WORK_DIR=$PROJECT_DIR/transcript_assembly
RUN_INFO_DIR=$WORK_DIR/00_run_info                          # scripts + versions used
INDEX_DIR=$WORK_DIR/01_hisat2_index_hap1_hap2               # HISAT2 index
INDEX_PREFIX=$INDEX_DIR/Pm_hap12_20261008
ALIGN_DIR=$WORK_DIR/02_hisat2_alignments_mapped_paired      # one BAM per sample
STRAND_DIR=$WORK_DIR/03_library_strandedness_check          # strand check table
MERGED_DIR=$WORK_DIR/04_alignments_merged_by_dpi            # replicates merged per time point
HAPLOTYPE_DIR=$WORK_DIR/05_alignments_split_by_haplotype    # merged BAMs split hap1/hap2
STRINGTIE_DIR=$WORK_DIR/06_stringtie2_transcripts           # one GTF per time point x haplotype
READS_BY_HAP_DIR=$WORK_DIR/07_reads_by_haplotype            # step-5 BAMs back to paired FASTQ
NORMALISED_DIR=$WORK_DIR/08_reads_normalised                # in-silico normalised reads
HAP_INDEX_DIR=$WORK_DIR/09_hisat2_index_per_haplotype       # one index per haplotype
HAP_ALIGN_DIR=$WORK_DIR/10_alignments_normalised_per_haplotype  # normalised reads -> own haplotype
TRINITY_DIR=$WORK_DIR/11_trinity_genome_guided              # one FASTA per time point x haplotype
LOG_DIR=$WORK_DIR/logs                                      # one log per job

# ---- Settings (from the published method) -----------------------------------
MAX_INTRON_LENGTH=3000          # HISAT2 --max-intronlen
TIMEPOINT_UNIT=dpi              # time points are named <number><unit>: 0dpi, 3dpi, 12dpi ...
STRAND_CHECK_CHROMOSOME=chr1_hap1
LIBRARY_STRAND=--rf             # confirmed by step 3: all samples RF (NEBNext Directional)
STRINGTIE_MIN_SINGLE_EXON_COVERAGE=2   # StringTie2 -s (default 4.75)
STRINGTIE_MIN_TRANSCRIPT_LENGTH=50     # StringTie2 -m (default 200)
NORM_MIN_COV=5                        # insilico_read_normalization --min_cov  (Rita's setting)
NORM_MAX_COV=50                       # insilico_read_normalization --max_cov  (Rita's setting)
TRINITY_MAX_INTRON=3000               # Trinity --genome_guided_max_intron (same as HISAT2)
TRINITY_MAX_MEMORY=80G                # Trinity --max_memory (Rita's setting)
TRINITY_LIBRARY_TYPE=RF               # --SS_lib_type for normalisation and Trinity (step 3: RF)

# ---- Software (Gadi if89 builds, by full path) ------------------------------
HISAT2=/g/data/if89/apps/hisat2/2.2.1/bin/hisat2
HISAT2_BUILD=/g/data/if89/apps/hisat2/2.2.1/bin/hisat2-build   # run with python3 on Gadi
SAMTOOLS=/g/data/if89/apps/samtools/1.18/bin/samtools
STRINGTIE=/g/data/if89/apps/stringtie/2.2.3/stringtie         # this if89 build has no bin/ folder
# Trinity 2.9.1 and everything it calls, from Gadi modules (no conda). Tested on a
# login node: python = 3.10.4 with numpy 1.22; Trinity's python helpers run.
TRINITY_MODULES="trinity/2.12.0 bowtie2/2.3.5.1 jellyfish/2.3.0 salmon/1.1.0 java/jdk-8.40 python3/3.10.4 python3-as-python"
TRINITY_UTIL=/apps/trinity/2.12.0/util                 # insilico_read_normalization.pl lives here

# Load those modules (used by steps 8 and 11, and by the checks in run_steps_07_to_11.sh)
load_trinity_modules() {
    set +u                                             # module scripts can trip over "set -u"
    if [[ "$(type -t module)" != "function" && -f /opt/Modules/v4.3.0/init/bash ]]; then
        source /opt/Modules/v4.3.0/init/bash
    fi
    module use /g/data/if89/apps/modulefiles
    module load $TRINITY_MODULES
    set -u
    export PATH=$(dirname "$SAMTOOLS"):$PATH           # samtools 1.18 (if89), used by Trinity
}
