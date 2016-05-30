#!/bin/sh

# Retrieve from NCBI, sort, cluster and create viral sequences database
# retrieve_fasta_from_NCBI.py, psi-cd-hit-est.pl and usearch must be alias defined. The script should be sourced (. script.sh).

mkdir files
cd files/

#variables:
queryString="txid10239[Organism] NOT txid131567[Organism] NOT phage[All Fields] NOT patent[All Fields] NOT unverified[Title] NOT chimeric[Title] NOT vector[Title] NOT method[Title]"
dbname="nuccore"
threshold=20000
id="0.9"

#files:
outfilename="retrievedNCBI"
shortfile="shorter.fasta"
longfile="longer.fasta"
longout="long_representative.fasta"
uc="short_representative.uc"
centroids="short_representative.fasta"
representatives="representatives.fasta"

printf "Starting at "
date "+%Y-%m-%d %H:%M:%S"

#Retrieve RefSeq sequences
printf "Retrieve RefSeq sequences\n"
retrieve_fasta -i "$queryString AND refseq[Filter]" -d $dbname -o $outfilename"_"RS -l $outfilename"_"RS.log --bins "100 900000000" &
pids[1]=$!

#Retrieve not RefSeq sequences
printf "Retrieve not-RefSeq sequences\n"
retrieve_fasta -i "$queryString NOT refseq[Filter]" -d $dbname -o $outfilename"_"NOTRS -l $outfilename"_"NOTRS.log --bins "100 250 500 750 1000 1500 2000 900000000" &
pids[2]=$!

for pid in ${pids[*]};
    do wait $pid;
done;

printf "Sequences retrieved from NCBI at: "
date "+%Y-%m-%d %H:%M:%S"
#Merge, sort, filter by length
printf "Merge, sort and filter\n"
cat $outfilename"_"RS $outfilename"_"NOTRS | awk '/^>/ {printf("\t%i\n%s\t",len, $0);len=0;next; } { printf("%s",$0); len+=length($0) } END {printf("\t%s",len);}' | sort -r -s -k3 -n | awk -v T=$threshold '{if($3>T){ printf("%s\n%s\n",$1,$2) > "'''$longfile'''"; }else { printf("%s\n%s\n",$1,$2) > "'''$shortfile'''"} }'
date "+%Y-%m-%d %H:%M:%S"

#PSI-CD-HIT
printf "Psi-cd-hit\n" 
psicdhit -i $longfile -o $longout -c $id -prog megablast &
pids[1]=$!

#USEARCH
printf "Usearch\n"
usearch -cluster_smallmem $shortfile -id $id -sortedby length -uc $uc -centroids $centroids &
pids[2]=$!

for pid in ${pids[*]};
    do wait $pid;
done;

printf "Finished clustering at: "
date "+%Y-%m-%d %H:%M:%S"
#Representative sequences:
printf "Representative sequences in file %s/%s\n" $(pwd) $representatives 
cat $longout $centroids > $representatives
printf "\nProcess finished at "
date "+%Y-%m-%d %H:%M:%S"

cd ..
