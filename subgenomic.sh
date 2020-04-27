#!/bin/bash

# bam files produced using the thermo fisher ion torrent SARS-CoV-2 community panel include subgenomic transcripts
# which can be visualized on IGV as apparent mismatches produced by the non-splice aware aligner, tmap
# To identify samples containing a substantial amount of subgenomic transcripts, run the following script in a folder of bam files.
# Script outputs the filename followed by the samtools sequencing depth at positions 68 and 88.
# Position 68 includes all reads aligning at this position (both genomic and subgenomic)
# Position 88 will be softclipped for all subgenomic transcripts. 
# Accordingly, samtools depth at 88 will only include genomic reads
# the difference (or fold change) between the apparent depths at 68 and 88 reflects the level of subgenomic reads in the sample.

echo "Filename, Depth at 68, Depth at 88"
for i in *.bam
do
        a=$(samtools depth -a $i -r 2019-nCoV:68-68 | awk '{print $3}')
        b=$(samtools depth -a $i -r 2019-nCoV:88-88 | awk '{print $3}')

        echo $i, $a, $b
done
