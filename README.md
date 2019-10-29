# Sapientia upload v1.0
## What does this app do?
This app uploads samples to Congenica's Sapientia analysis platform. This uses a dockerised upload client provided by Congenica.

## What are typical use cases for this app?
Following the completion of the bioinformatic workflow, variant calls are uploaded for annotation and prioritisation in the Sapientia analysis platform.
This app supports two seperate workflows:
1) Upload singleton (affected) samples without hpo terms - in this case an ir.csv file is not provided (it's created on the fly) and each sample is uploaded individually.
2) Upload of one or more samples using a provided ir.csv file. The required fields (file paths) are filled in and all samples are uploaded in a single upload. This can be used for trios/related samples or where gene panels or HPO terms are required.


## What inputs are required for this app to run?
This app requires the following inputs:
- **VCF file** - one or more VCFs can be provided
- **Project ID** of Sapientia project to upload samples

Optional inputs
- **BAM file(s)** (`*.bam`). Only BAM files with an associated VCF file will be imported.  
- An **analysis name** - This analysis name is displayed in Sapientia. By default this is taken from the name of the NGS run.
- An **ir.csv** - This file describes all the information for one or more samples, including hpo terms, proband, family structure.
If ir.csv file is provided an analysis name is required.

The app downloads the sapientia credentials (`sapientia_env`) from 001_Authentication.

## How does this app work?
The inputs and credentials files are downloaded.
The docker image provided by Congenica is used to upload samples and files to the platform. The upload client performs a number of checks, such as comparison of samplename and the samplename in the VCF file. This requires an analysis id and ir.csv file.

The IR.csv file is required by the upload client to link files to each analysis and to add meta data such as sex and family structure.
If not provided this file is created by looping through all VCF inputs extracting the samplename, sex, VCF and BAM files (if provided).
The sex is identified using the single letter sex in the samplename. If it is neither "F" or "M" it is treated as unknown. This is case sensitive.
One upload is performed per sample and if, not provided, the analysis id is taken from the samplename

If the IR.csv file is provided the file paths are filled in. Where the ir.csv file is provided the analysis ID is also required
One upload is done per run.

The congenica upload client produces one log file per upload. This is uploaded (but not as an output) in order to see why the upload failed. If any uploads are unsucessful the app will fail.


## What does this app output?
The upload client produces a log file ($analysis_name_upload.log) per upload. 
 
The log files are output to /sapientia_logs/

The completed ir.csv is also output (named $analysis_name_ir.csv) to the same folder.


## This app was made by Viapath Genome Informatics 
