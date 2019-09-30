# Sapientia upload v1.0
## What does this app do?
This app uploads samples to Congenica's Sapientia analysis platform. This uses a dockerised upload client provided by Congenica.

## What are typical use cases for this app?
Following the completion of the bioinformatic workflow, the variant calls are uploaded for annotation and prioritisation in the Sapientia analysis platform.
This app takes an array of VCFs, associated BAM files (optional), and uploads them to the specified project.

## What inputs are required for this app to run?
This app requires the following inputs:

- **VCF file** - one or more VCFs can be provided
- **BAM file(s)** (`*.bam`). Only BAM files with an associated VCF file will be imported.  
- **Project ID** of Sapientia project to upload samples

Optional inputs
- An **analysis name** - This analysis name is displayed in Sapientia. By default this is taken from the name of the NGS run.

The app downloads the sapientia credentials (`sapientia_env`) from 001_Authentication.

## How does this app work?
The inputs and credentials files are downloaded.
If not provided, the analysis ID is taken from the name of the project in which the job is running.
The IR.csv file is required by the upload client to link files to each analysis and to add meta data such as sex and family structure (currently, only singleton analysis is supported). This file is created by looping through all VCF inputs extracting the samplename, sex, VCF and BAM files (if provided).
The sex is identified using the single letter sex in the samplename. If it is neither "F" or "M" it is treated as unknown. This is case sensitive.
The docker image provided by Congenica is used to upload samples and files to the platform.

The upload client performs a number of checks, such as comparison of samplename and the samplename in the VCF file.

If any errors are seen (hopefully) the app will fail.


## What does this app output?
The upload client produces a log file ($analysis_name_upload.log). This (should) record the success or failure of the upload.
The stdout of the docker app is also recorded in $analysis_name_client_stdout.log (hopefully this is not required if all relevant logs are recorded in the above file)

The log files are output to /sapientia_logs/

The ir.csv is also output (named $analysis_name_ir.csv) to the same folder.


## Limitations
Currently, this only supports singleton analysis. Family structure/non-affected individuals will be treated as probands.

## This app was made by Viapath Genome Informatics 
