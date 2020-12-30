# Congenica upload v1.1

## What does this app do?

This app uploads samples to the Congenica analysis platform. This uses a dockerised upload client provided by Congenica.

## What are typical use cases for this app?

Following the completion of the bioinformatic workflow, variant calls are uploaded for annotation and prioritisation in the Congenica analysis platform.
This app currently supports the following scenarios:

1) Upload singleton (affected) sample without hpo terms - in this case an ir.csv file is not provided (it's created on the fly).

## What inputs are required for this app to run?

This app requires the following inputs:

- **VCF file** - One single sample VCF file.
- **Project ID** of Congenica project to upload samples
- **credentials** - Which credentials file to use (options are Viapath or STG) - either `congenica_env_Viapath` or `congenica_env_STG` are downloaded from 001_Authentication.

Optional inputs

- **BAM file(s)** (`*.bam`). Only BAM files with an associated VCF file will be imported.  
- An **analysis name** - This analysis name is displayed in Congenica. By default this is the samplename.

## How does this app work?

The inputs and credentials files are downloaded.
The docker image provided by Congenica is used to upload samples and files to the platform. The upload client performs a number of checks, such as comparison of samplename within the ir.csv file and the samplename in the VCF header. The upload agent requires an analysis id and ir.csv file.

The IR.csv file is required by the upload client to link files to each analysis and to add meta data such as sex and family structure.
This file is created by parsing the VCF file name and extracting the samplename, sex and capturing paths to VCF and BAM files (if provided).
The sex is identified using the single letter sex in the samplename. If it is neither "F" or "M" it is treated as unknown. This is case sensitive.
If not provided, the analysis id is taken from the samplename

The Congenica upload client produces a log file. This is uploaded from the job (but not as an output in order to see why the upload failed). If any uploads are unsucessful the app will fail.

## What does this app output

The upload client produces a log file ($analysis_name_upload.log).
The completed ir.csv is also output (named $analysis_name_ir.csv) .
These log files are output to /Congenica_logs/

## This app was made by Viapath Genome Informatics
