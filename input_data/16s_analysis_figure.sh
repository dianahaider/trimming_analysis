#0.0 Download data and clone git repos with pipeline
conda env create -f environment.yml

git clone https://github.com/jcmcnch/eASV-pipeline-for-515Y-926R.git
#change the qiime version from the pipeline to your current qiime2 version
find . -type f | xargs perl -pi -e 's/qiime2-2019.4/qiime2-2020.11/g'

chmod a+x eASV-pipeline-for-515Y-926R/./ #makes files executable
source eASV-pipeline-for-515Y-926R/DADA2-pipeline/00-trimming-sorting-scripts/00-run-cutadapt.sh
conda env create -f eASV-pipeline-for-515Y-926R/env/bbmap.yaml #removed some packages that failed
source eASV-pipeline-for-515Y-926R/DADA2-pipeline/00-trimming-sorting-scripts/01-sort-16S-18S-bbsplit.sh #make sure you change the paths for the in-silico, and for the bbsplit db, this step is long

#1.0 Running all trim lengths
#FOR PROKARYOTES
cd 02-PROKs
source ~/MOCK_ANALYSIS/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-prok-scripts/P00-create-manifest.sh
source ~/MOCK_ANALYSIS/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-prok-scripts/P01-import.sh

for flen in {30..300..10} ##outer loop
do
	for rlen in {0..300..10} ##inner loop
	do
		mkdir -p all_trims/"F"$flen"R"$rlen
		conda activate qiime2-2020.111 ##activate environment for trimming
		~/MOCK_ANALYSIS/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-prok-scripts/P03-DADA2.sh $flen $rlen
		mv 03-DADA2d all_trims/"F"$flen"R"$rlen
	done
done
echo 'Generated all 16S trim combinations'

#FOR EUKARYOTES
cd ~/MOCK_ANALYSIS/02-EUKs
source ~/MOCK_ANALYSIS/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-euk-scripts/E00-create-manifest-viz.sh
source ~/MOCK_ANALYSIS/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-euk-scripts/E01-import.sh

for flen in {0..300..10} ##outer loop
do
	for rlen in {0..300..10} ##inner loop
	do
		mkdir -p all_trims/"F"$flen"R"$rlen
		conda activate bbmap-env ##activate environment for trimming
		~/mocks-to-share-with-Diana/diana_18s/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-euk-scripts/E03-bbduk-cut-reads.sh $flen $rlen
		mv 03-size-selected all_trims/"F"$flen"R"$rlen
		cd all_trims/"F"$flen"R"$rlen
		~/mocks-to-share-with-Diana/diana_18s/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-euk-scripts/E04-fuse-EUKs-withoutNs.sh
		~/mocks-to-share-with-Diana/diana_18s/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-euk-scripts/E05-create-manifest-concat.sh
		conda activate qiime2-2020.111
		~/mocks-to-share-with-Diana/diana_18s/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-euk-scripts/E06-import-concat.sh
		~/mocks-to-share-with-Diana/diana_18s/eASV-pipeline-for-515Y-926R/DADA2-pipeline/01-euk-scripts/E08-DADA2.sh
		cd ..
		cd ..
	done
done
echo 'Generated all 18S trim combinations'

#2.0 Assign taxonomy to each table
#2.1 find all the representative sequences from all trim lengths
find ~MOCK_ANALYSIS -name 'representative_sequences.qza' >all_rep_seqs.txt
echo 'Found both 16S and 18S representative sequences'

#2.2 run taxonomy for all of them
while read in; do
   qiime feature-classifier classify-sklearn \
    --i-reads "$in" \
    --i-classifier ~/Documents/escuela/phd/plugin_paper/mock_code/18S/silva-138-99-nb-classifier.qza \
    --output-dir "$in"-taxa --verbose; done < all_rep_seqs.txt
echo 'Generated all taxonomy'

#2.3 batch unzip de classification.qza and let result stay in parent folder
find . -name 'classification.qza' -exec sh -c 'unzip -d "${1%.*}" "$1"' _ {} \;

python3 move_rename.py alltrims #rename all taxonomy.tsv by their trimlengths
mv -i F*R*.tsv all_taxonomies/ #puts all tsvs in new directory with correct names

python adapt_metadata(all_merged, manifest, metadata)

#add the
find ~/Documents/escuela/phd/plugin_paper/mock_code/16S/02-PROKs/alltrims/all_taxonomies -name 'F*R*.tsv' > all_taxonomies.txt

#run Bacaros at different levels

git clone https://github.com/alexmanuele/Bacaros_Beta.git

for i in {1..7..1}
do
	python run_beta.py --input ~/Documents/escuela/phd/plugin_paper/mock_code/16S/02-PROKs/alltrims/all_taxonomies.txt --metric t --l $i --output results-$i
done



conda deactivate



#