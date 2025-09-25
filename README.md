# Congenica upload v1.3.3

## What does this app do?

This app uploads samples to the Congenica analysis platform. This uses a dockerised upload client provided by Congenica and an Interpretation Request (IR) csv file.

## What are typical use cases for this app?

Following the completion of the bioinformatic workflow, variant calls are uploaded for annotation and prioritisation in the Congenica analysis platform.
This app currently supports the following scenarios:

1) Upload singleton (affected) sample without hpo terms.

## What inputs are required for this app to run?

### Required inputs

- **VCF file** - One single sample VCF file.
- **Project ID** - Congenica project to upload sample
- **credentials** - Which credentials file to use (options are Viapath or STG) - either `congenica_env_Viapath` or `congenica_env_STG` are downloaded from 001_Authentication.
- **IR_template** - Which template IR file to use (options are priority or non-priority)

### Optional inputs

- **analysis_name** - This analysis name is used in the first column of the IR and in congenica. It is also used to name output files and match up the BAM file. If not provided this is extracted from the filename (taking everything before _R1 from the vcf name). This is not compatible with files produced from Senteion so analysis_name must be provided in these cases.
- **BAM file(s)** (`*.bam`). Only BAM files with an associated VCF file will be imported. This is determined by the presence of the analysis_name in the BAM file name.

## How does this app work?

The inputs and credentials files are downloaded.
The docker image provided by Congenica is used to upload samples and files to the platform. The upload client performs a number of checks, such as comparison of samplename within the IR.csv file and the samplename in the VCF header. The upload agent requires an analysis id and IR.csv file.

The IR.csv file is required by the upload client to link files to each analysis and to add metadata such as sex and family structure.
This IR is based on templates within the app (template is specified as an input) and populated by parsing the VCF file name and extracting:
- the samplename (or using the analysis_name)
- The sex. Identified using the single letter sex in the vcf filename ("\_F\_" or "\_M\_"). If neither are present it is treated as unknown.

The IR also contains paths to the VCF and BAM files (BAM is optional - see optional inputs above).

The Congenica upload client produces a log file. This is uploaded from the job (but not as an output in order to see why the upload failed). If any uploads are unsucessful the app will fail.

## What does this app output

The upload client produces a log file ($analysis_name_upload.log).
The completed IR.csv is also output (named $analysis_name_ir.csv).
These log files are output to /Congenica_logs/

## This app was made by Viapath Genome Informatics
