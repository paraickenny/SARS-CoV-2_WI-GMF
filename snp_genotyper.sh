#!/bin/bash
# takes positions from an imported bed file and outputs the nucleotide at that position in the SARS-CoV-2 genome

for i in *.bam
do
        echo $i

        samtools mpileup -uvDV -l snps.bed  -f 2019-nCoV.fa $i | bcftools call -c - | grep 2019-

        echo

done
