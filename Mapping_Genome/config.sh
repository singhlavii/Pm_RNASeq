# =============================================================================
# config.sh - paths and settings shared by all the Gadi scripts.
# Change things here, not in the individual scripts.
# =============================================================================

NCI_PROJECT=xf3                                   # project charged for jobs

BASE=/g/data/xf3/ls9057/Pmelanocephala/RNAseq            # project folder

RAW_DIR=$BASE/raw_fastq                           # renamed links to the raw reads
TRIM_DIR=$BASE/trimmed_fastq                      # trimmed reads (big: ~300 GB)
#TRIM_DIR=/scratch/xf3/ls9057/Pmelanocephala/RNAseq/trimmed_fastq   # alternative: scratch
QC_RAW_DIR=$BASE/fastp/raw                        # fastp reports, raw reads
QC_TRIM_DIR=$BASE/fastp/trimmed                   # fastp reports, trimmed reads
MULTIQC_DIR=$BASE/multiqc                         # combined reports
LOG_DIR=$BASE/logs                                # job logs

# ---- Software (shared xf3 conda environments) ---------------------------------
FASTP=/g/data/xf3/miniconda/envs/fastp_1.4.0/bin/fastp
MULTIQC=/g/data/xf3/miniconda/envs/multiqc_1.35/bin/multiqc
