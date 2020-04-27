#!/bin/bash

#deals with issue where intermediates of viral RNA replication
#interfere with consensus calling from .bam file produced by ion torrent tmap.
#extract reads from tmap bam, align with hisat2, index bam, cleanup files.
#requirements - samtools, hisat2, sarscov2 reference genome ('2019-nCoV.fa')
#also need to to index the reference genome per hisat2 instructions
# need to set correct path to hisat2 if not in your environment path. I call it directly below.
# run script in a directory containing tmap-aligned bams and the hisat2 build index for 2019-nCoV


for i in *.bam
do
echo $i
        echo "extracting sequences as fastq" $i
        samtools fastq $i > "${i%.*}.fastq"
        echo "aligning with hisat"
        /home/galaxy/hisat2/hisat2 -p 4 -x 2019-nCoV -U "${i%.*}.fastq" -S "${i%.*}.sam"
        echo "converting sam to bam"
        samtools view -b  "${i%.*}.sam" >  "${i%.*}.hisat-unsorted.bam"
        echo  "sorting bam"
        samtools sort "${i%.*}.hisat-unsorted.bam" -o "${i%.*}.hisat.bam"
        echo "indexing bam"
        samtools index "${i%.*}.hisat.bam"
        mkdir output
        mv *.hisat.ba* output
        rm -f *.fastq
        rm -f *.sam
        rm -f *.hisat-unsorted.bam
        mkdir originals
        mv $i originals

