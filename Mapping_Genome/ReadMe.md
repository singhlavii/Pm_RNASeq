## Mapping reads to Genome using HISAT2 ##

I used Claude (Opus 5.5) to help me set up scripts in a way where I could compile different jobs and run from one script. This way I could rerun from specific jobs. I specified parameters and cross checked the scripts Claude generated. 

For this analysis, I have a ```maprate_config.sh``` file that specifies all folder locations and softwares. The script ```submit_maprate.sh``` is what you have to submit. It runs three different smaller scripts as shown below.

### 1. ```maprate_index.pbs```
This builds the HISAT2 index for input for mapping.

### 2. ```maprate_map.pbs```
This aligns the reads to the index. The alignments are discarded but the summaries are kept. This was because I just wanted to count for now. 

### 3. ```maprate_summary.pbs```
This builds the summary report and runs Multiqc
