#!/bin/bash


#deals with issue where intermediates of viral RNA replication
#interfere with consensus calling from .bam file produced by ion torrent tmap.
#extract reads from tmap bam, align with hisat, index hisat bam, cleanup files.
#requirements - samtools, hisat2, sarscov2 reference genome ('2019-nCoV.fa')
#also need to to index the reference genome per hisat2 instructions
# need to set correct path to hisat2 if not in your environment path. I call it directly below.

# make sure that the targetlist.sh file is executable

chmod +x targetlist.sh

./targetlist.sh

for i in *.bam
do
echo $i
        echo "extracting sequences as fastq" $i
        samtools fastq $i > "${i%.*}.fastq"
        echo "aliging with hisat"
        /home/galaxy/hisat2/hisat2 -p 4 -x 2019-nCoV -U "${i%.*}.fastq" -S "${i%.*}.sam"
        echo "converting sam to bam"
        samtools view -b  "${i%.*}.sam" >  "${i%.*}.hisat-unsorted.bam"
        echo  "sorting bam"
        samtools sort "${i%.*}.hisat-unsorted.bam" -o "${i%.*}.hisat.bam"
        echo "indexing bam"
        samtools index "${i%.*}.hisat.bam"
        mkdir output
        # mv *.hisat.ba* output
        rm -f *.fastq
        rm -f *.sam
        rm -f *.hisat-unsorted.bam
        mkdir originals
        mv $i originals


done



# consensus.sh script below #updated 9-17-20 for parallel processing

# may need to get it so skip indels
# need to verify how it handles minor alleles
# note samtools depth file is 1-indexed but bedtools maskfasta assumes zero-indexed so I use awk to convert


for i in *.bam

do
        echo "computing consensus for $i"

        samtools mpileup -d 250000 -uf 2019-nCoV.fa $i | bcftools call -c -V indels --ploidy 1 -Oz -o "${i%.*}.vcf" &  #ploidy 1 for haploid virus. depth parameter needs to be increased for hisat bam files try 250K
        samtools depth -a $i > "${i%.*}_samtools_depth.txt"
done


wait

echo "i block completed"

for a in *.vcf

do
        echo $a
        bcftools index -f $a


        cut -f 3 "${a%.*}_samtools_depth.txt" | sort| uniq | while read X; do awk -v X=$X '($3==X) { printf("%s\t%d\t%d\n",$1,$2,int($2)+1);}' "${a%.*}_samtools_depth.txt" | sort -k1,1 -k2,2n | /home/galaxy/bedtools merge -i - | sed "s/\$/\t${X}/" ;done | awk '$4 == 0' > "${a%.*}_temp_zerodepth_1-index.bed"

        awk  '{print $1, $2-1, $3-1, $4}' OFS='\t' "${a%.*}_temp_zerodepth_1-index.bed" > "${a%.*}_temp_zerodepth.bed"


         /home/galaxy/bedtools maskfasta -fi 2019-nCoV.fa -bed "${a%.*}_temp_zerodepth.bed" -fo "${a%.*}_temp_masked_zero.fa"


        cat "${a%.*}_temp_masked_zero.fa" | bcftools consensus  "${a%.*}.vcf" > "${a%.*}_noheader.fa"


        sed -i "s/>2019-nCoV/>$a/g" "${a%.*}_noheader.fa"   # replaces generic chromosome name with name of vcf file


        cat "${a%.*}_noheader.fa" | tr -d "\n" > "${a%.*}_noheader1.fa"      # removes all newlines


        sed -i "s/vcf/vcf\n/g" "${a%.*}_noheader1.fa"              # puts a newline after bam


        sed -i "s/>/\n>/g" "${a%.*}_noheader1.fa"                   # puts a newline before '>'


        echo  >> "${a%.*}_noheader1.fa"                            # puts a newline at end of file


        cat "${a%.*}_noheader1.fa"  >> consensus_output.txt
done



mv *.hisat.ba* output
rm -f *.bai
rm -f *hisat.vcf*
rm -f *hisat_temp*
rm -f *hisat_nohead*
rm -f *hisat_samtools*
