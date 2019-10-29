#!/bin/bash

# Output each line as it is executed (-x) and don't stop if any non zero exit codes are seen (+e)
set -x +e
mark-section "download inputs"

successful_app_run=0

# Download sapientia credentials from 001_authentication
dx cat project-FQqXfYQ0Z0gqx7XG9Z2b4K43:sapientia_env > env_file

# download all inputs
dx-download-all-inputs --parallel

mark-section "setting up congenica upload client docker image"
# docker load
docker load -i '/home/dnanexus/congenica-client-2.2.0.0_2.tar.gz' 

mark-section "determine run specific variables"
# get project - this is an string input
echo "sapientia project = " $sapientia_project

# make output folders for log file and ir_file
mkdir -p ~/out/logfile/sapientia_logs/ ~/out/ir_file/sapientia_logs

# 2 use cases - 
# 1) upload singleton (affected) samples without hpo terms - in this case an ir.csv file is not provided and it's created on the fly for each sample and uploaded individually.
# 2) upload of WES cases (singletons or families) where HPO terms and affected status are required. In this case the ir.csv file is provided and the required fields (file paths) are filled in. There is one upload per app.

# if the ir_csv has not been provided
if [[ ! -f $ir_csv_path ]]
then
    # upload each sample
    mark-section "upload individual samples by building ir.csv file"
    # need to populate sample name, sex, bamfile and vcf file paths for each vcf
    for vcf in ${vcfs_path[@]}
    do
        #  Build ir.csv file for this sample        
        mark-section "Building ir.csv"
        
        # extract the sample name to match that in the vcf by taking everything before .vcf (NGS282rpt_16_136819_NA12878_F_WES47_Pan493_S16)
        vcf_basename=$(basename $vcf)
        samplename=$(python -c "basename='$vcf_basename'; print basename.split('_R1')[0]")
        echo $samplename
        if [[ $analysis_name == "" ]]
        then 
            analysis_name=$samplename
        fi
        # extract 5th item (single character sex) and extrapolate into full word. If not "M" or "F" set as unknown
        sex_singlechar=$(echo $(basename $vcf) | cut -d"_" -f5); 
        if [[ $sex_singlechar == "F" ]]
            then 
                sex="female"
        elif [[ $sex_singlechar == "M" ]]
            then 
                sex="male"
        else 
            sex="unknown"
        fi
        mark-section "matching up BAM files"
        #create variable to hold bamfile name - starts off empty. Once match has been made it will stop searching.
        bamfile=""
        # for this vcf look to see if there is a BAM file.
        for bam in ${bams_path[@]}
        do
            echo "looking for samplename $samplename in bamfile path $bam"
            # look if sample name (created above) is present in the bamfile path.
            if [[ "$bam" == *$samplename* ]]
            then
                bamfile=$bam
                echo "found matching BAM"
            fi
        done
        # make a copy of the ir.csv file containing header
        cp ~/ir_file.csv ~/out/ir_file/sapientia_logs/$samplename.csv
        # write the sample details to the ir csv file
        echo "$samplename,$sex,,affected,1,,,,,,,,$bamfile,,,,$vcf," >> ~/out/ir_file/sapientia_logs/$samplename.csv

        # cat the ir.csv file so it can be seen in the logs for easy troubleshooting (is also an output but will not be output if job fails)
        cat ~/out/ir_file/sapientia_logs/$samplename.csv

        mark-section "upload using docker image"
        # docker run - mount the home directory as a share, use the env_file, ir_file.csv, $sapientia_project and $analysis_name values determined above. 
        # Write log direct into output folder
        docker run -v /home/dnanexus/:/home/dnanexus/ --env-file ~/env_file congenica-client:2.2.0.0_2 --ir ~/out/ir_file/sapientia_logs/$samplename.csv --project $sapientia_project --name $analysis_name --log ~/out/ir_file/sapientia_logs/"$analysis_name"_upload.log
        docker_status=$?
        if [ $docker_status -ne 0 ]
        then
            successful_app_run=$docker_status
            cat /home/dnanexus/out/logfile/sapientia_logs/"$analysis_name"_upload.log
        fi 
    done
# if ir_csv file has been provided
else
    mark-section "upload samples using provided ir.csv file"
    # need to populate filepaths for each sample
    # loop through provided ir.csv one line at a time
    while read line
    do 
        # capture the samplename, from first field of the line
        vcf_basename=$(basename $vcf)
        samplename=$(python -c "basename='$vcf_basename'; print basename.split('_R1')[0]")
        # set up variables to hold filepaths
        vcffile=""
        bamfile=""
        # loop through all input vcfs
        for vcf in ${vcfs_path[@]}
        do
            # if the samplename is in the filename capture the filepath
            if [[ "$vcf" == *$samplename* ]]
            then
                vcffile=$vcf
            fi
        done
        echo $vcffile
        # loop through all input bams
        for bam in ${bams_path[@]}
        do
            if [[ "$bam" == *$samplename* ]]
            then
                # if the samplename is in the filename capture the filepath
                bamfile=$bam
            fi
        done

        # if it's the header of the ir.csv write the line to a new file
        if [[ "$samplename" == "name" ]]
        then
            echo $line > ~/out/ir_file/sapientia_logs/$analysis_name.csv
        else
            # test to ensure vcf file has been detected
            if [[ "$vcffile" = "" ]]
            then
                echo "vcf file not detected for samplename " $samplename
                exit 1
            fi
            # if it's not header write line but replace placeholders withfilepaths
            if [[ $bamfile -ne "" ]]
            then 
                echo  $line | sed "s+bam_path++" | sed "s+vcf_path+$vcffile+" >> ~/out/ir_file/sapientia_logs/$analysis_name.csv
            else
                echo  $line | sed "s+bam_path+$bamfile+" | sed "s+vcf_path+$vcffile+" >> ~/out/ir_file/sapientia_logs/$analysis_name.csv
            fi
        fi
    # pass the provided ir.csv file into the above if loop
    done < $ir_csv_path

    
    # cat the ir.csv file so it can be seen in the logs for easy troubleshooting (is also an output but will not be output if job fails)
    cat ~/out/ir_file/sapientia_logs/$analysis_name.csv

    mark-section "upload using docker image"
    # docker run - mount the home directory as a share, use the env_file, ir_file.csv, $sapientia_project and $analysis_name values determined above. 
    # Write log direct into output folder
    docker run -v /home/dnanexus/:/home/dnanexus/ --env-file ~/env_file congenica-client:2.2.0.0_2 --ir ~/out/ir_file/sapientia_logs/$analysis_name.csv --project $sapientia_project --name $analysis_name --log ~/out/ir_file/sapientia_logs/"$analysis_name"_upload.log
    docker_status=$?
    if [ $docker_status -ne 0 ]
    then
        cat /home/dnanexus/out/logfile/sapientia_logs/"$analysis_name"_upload.log
        successful_app_run=$docker_status
    fi
fi 

mark-section "Upload output"
# to do dx upload need to reset worker variable
unset DX_WORKSPACE_ID
# set the project the worker will upload to
dx cd $DX_PROJECT_CONTEXT_ID:
ls ~/out/ir_file/sapientia_logs
# make folder for output - use -p so doesn't fail if file already exists
dx -p mkdir sapientia_logs
# run dx uplaod command to the desired location - upload all files in the sapientia_logs output folder 
dx upload --brief --path "$DX_PROJECT_CONTEXT_ID:/sapientia_logs/" ~/out/ir_file/sapientia_logs/*

mark-section "determine if app should complete successfully or fail"
if [ $successful_app_run -eq 0 ]
then
mark-success
exit 0
else
exit 1
fi
