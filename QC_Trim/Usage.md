## Read QC and Trimming using FastP ##

I used Claude (Opus 5.5) to help me set up scripts in a way where I could compile different jobs and run from one script. This way I could rerun from specific jobs. I specified parameters and cross checked the scripts Claude generated. 

For this analysis, I have a ```config.sh``` file that specifies all folder locations and paths to softwares I installed such as Fastp and Multiqc. The script ```submit.sh``` is what you have to submit and specify the respective mode you want it to run on. Based on that, it will run different sets of smaller scripts. They are shown below:

#### 1. Raw Read QC

I ran Fastp on raw reads with all filtering disabled.

```
bash submit.sh qc
````

The ```qc``` mode runs two smaller scripts. ```fastp.pbs``` is run without filtering and once done, ```multiqc.pbs``` is run to compile all results. 

#### 1. Trimming and QC

I ran Fastp with differernt parameters to trim and filter reads.

```
bash submit.sh trim
````

The ```trim``` mode runs two smaller scripts. ```fastp.pbs``` is run with parameters ``` --detect_adapter_for_pe --cut_right --correction``` and once done, ```multiqc.pbs``` is run to compile all results. 

Before running, make sure all files: ```config.sh```,  ```submit.sh``` , ```fastp.pbs``` and ```multiqc.pbs``` are in one folder. 
