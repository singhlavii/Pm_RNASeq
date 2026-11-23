## Run record ##




Summary generated with Claude, Opus 5.5

```
Transcript assembly, P. melanocephala Pm_hap12_20261008 (hap1+hap2), 24 stranded PE libraries (6 dpi x 4 reps), Nov 2026, NCI Gadi.

HISAT2 2.2.1: --max-intronlen 3000 --dta; kept mapped proper pairs (samtools 1.18 -F 4 -f 2)
Library strandedness: RF
Merged 4 reps per dpi, split by haplotype
StringTie 2.2.3: -s 2 -m 50 --rf
Trinity normalisation: --min_cov 5 --max_cov 50 --pairs_together --SS_lib_type RF
Normalised reads realigned to own haplotype (HISAT2, same settings)
Trinity 2.12.0 genome-guided: --genome_guided_max_intron 3000 --jaccard_clip --SS_lib_type RF (Gadi's 2.9.1 broken: seqtk-trinity segfault)
```
