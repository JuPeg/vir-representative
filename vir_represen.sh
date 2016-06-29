#!/bin/sh

# Retrieve from NCBI, sort, cluster and create viral sequences database
# retrieve_fasta_from_NCBI.py, psi-cd-hit-est.pl and usearch must be alias defined. The script should be sourced (. script.sh).

mkdir files
cd files/

function nucc {

    # default parameters:
    queryString="txid10239[Organism] NOT txid131567[Organism] NOT phage[All Fields] NOT patent[All Fields] NOT unverified[Title] NOT chimeric[Title] NOT vector[Title] NOT method[Title] NOT \"uncultured virus\"[Organism]"
    dbname="nuccore"
    threshold=20000
    id="0.9"

    # file names:
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
    retrieve_fasta -i "$queryString AND refseq[Filter]" -d $dbname -o $outfilename"_"RS -l $outfilename"_"RS.log &
    pids[1]=$!

    #Retrieve not RefSeq sequences
    printf "Retrieve not-RefSeq sequences\n"
    retrieve_fasta -i "$queryString NOT refseq[Filter]" -d $dbname -o $outfilename"_"NOTRS -l $outfilename"_"NOTRS.log &
    pids[2]=$!

    for pid in ${pids[*]};
        do wait $pid;
    done;

    printf "Nuccore - Sequences retrieved from NCBI at: "
    date "+%Y-%m-%d %H:%M:%S"
    #Merge, sort, filter by length
    printf "Nuccore - Merge, sort and filter\n"
    cat $outfilename"_"RS $outfilename"_"NOTRS | awk '/^>/ {printf("\t%i\n%s\t",len, $0);len=0;next; } { printf("%s",$0); len+=length($0) } END {printf("\t%s",len);}' | sort -r -s -k3 -n | awk -v T=$threshold '{if($3>T){ printf("%s\n%s\n",$1,$2) > "'''$longfile'''"; }else { printf("%s\n%s\n",$1,$2) > "'''$shortfile'''"} }'
    date "+%Y-%m-%d %H:%M:%S"

    #PSI-CD-HIT
    printf "Nuccore - Psi-cd-hit\n"
    psicdhit -i $longfile -o $longout -c $id -prog megablast &
    pids[1]=$!

    #USEARCH
    printf "Nuccore - Usearch\n"
    usearch -cluster_smallmem $shortfile -id $id -sortedby length -uc $uc -centroids $centroids &
    pids[2]=$!

    for pid in ${pids[*]};
        do wait $pid;
    done;

    printf "Nuccore - Finished clustering at: "
    date "+%Y-%m-%d %H:%M:%S"
    #Representative sequences:
    printf "Nuccore - Representative sequences in file %s/%s\n" $(pwd) $representatives
    cat $longout $centroids > $representatives
    printf "\nNuccore - Process finished at "
    date "+%Y-%m-%d %H:%M:%S"

}

function prot {

    # default parameters:
    queryString="txid10239[Organism] NOT txid131567[Organism] NOT phage[All Fields] NOT unverified[Title] NOT (\"virus like particle\"[All Fields] OR \"virus like particles\"[All Fields]) NOT chimeric[Title] NOT vector[Title] NOT method[Title] AND 30:10000[Sequence length]"
    dbname="protein"
    id="0.9"

    # file names:
    outfilename="retrievedNCBI_proteins"
    outrepr="prot_representative.fasta"
    uc="prot_representative.uc"
    centroids="prot_representative.fasta"

    printf "Starting at "
    date "+%Y-%m-%d %H:%M:%S"

    #Retrieve sequences
    printf "Retrieve protein sequences\n"
    retrieve_fasta -i "$queryString" -d $dbname -o $outfilename -l $outfilename.log

    printf "Protein - Sequences retrieved from NCBI at: "
    date "+%Y-%m-%d %H:%M:%S"

    #Sort
    printf "Protein - Sort\n"
    usearch -sortbylength $outfilename -fastaout $outrepr
    date "+%Y-%m-%d %H:%M:%S"

    #USEARCH
    printf "Protein - search\n"
    usearch -cluster_smallmem $outrepr -id $id -sortedby length -uc $uc -centroids $centroids

    printf "Finished clustering at: "
    date "+%Y-%m-%d %H:%M:%S"

}

prot &
nucc


cd ..
