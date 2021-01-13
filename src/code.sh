#!/bin/bash

# Output each line as it is executed (-x) and don't stop if any non zero exit codes are seen (+e)
set -x +e
mark-section "download inputs"

successful_app_run=0

# Download credentials from 001_authentication
if [[ "$credentials" == "STG" ]]; then
    dx cat project-FQqXfYQ0Z0gqx7XG9Z2b4K43:congenica_env_STG > env_file
elif [[ "$credentials" == "Viapath" ]]; then
    dx cat project-FQqXfYQ0Z0gqx7XG9Z2b4K43:congenica_env_Viapath > env_file
fi

# download all inputs
dx-download-all-inputs --parallel

mark-section "setting up congenica upload client docker image"
# docker load
docker load -i '/home/dnanexus/congenica-client-2.2.0.0_3.tgz' 

mark-section "setting up docker run command"
opts=""
# if [ "$resume" == true ]; then
# 	opts="$opts --resume" 
# fi

mark-section "determine run specific variables"
# get congenica project - this is an string input
echo "congenica project = " $congenica_project

# make output folders for log file and ir_file
mkdir -p ~/out/logfile/congenica_logs/ ~/out/ir_file/congenica_logs

# Use case 1 - upload singleton (affected) samples without hpo terms
# in this case an ir.csv file is not provided and it's created on the fly
mark-section "Build ir.csv file"

# extract the sample name to match that in the vcf by taking everything before "_R1" eg (NGS282rpt_16_136819_NA12878_F_WES47_Pan493_S16from NGS282rpt_16_136819_NA12878_F_WES47_Pan493_S16_R1_001.refined.vcf.gz)
samplename=$(python -c "basename='$vcf_prefix'; print basename.split('_R1')[0].split('.vcf')[0]")
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
# look if sample name (created above) is present in the bamfile path.
if [[ "$bam_path" == *$samplename* ]]
then
    bamfile=$bam_path
    echo "found matching BAM"
fi

# make a copy of the packaged ir.csv template file containing header
#check which ir.csv file to use
if [[ "$IR_template" == "priority" ]]; then
    cp ~/priority_ir_file.csv ~/out/ir_file/congenica_logs/$samplename.csv
    # write the sample details to the ir csv file
    echo "$samplename,$sex,,affected,1,,,,,,,,$bamfile,,,,$vcf_path,," >> ~/out/ir_file/congenica_logs/$samplename.csv
elif [[ "$IR_template" == "non-priority" ]]; then
    cp ~/non_priority_ir_file.csv ~/out/ir_file/congenica_logs/$samplename.csv
    # write the sample details to the ir csv file
    echo "$samplename,$sex,,affected,1,,,,,,,,$bamfile,,,,$vcf_path," >> ~/out/ir_file/congenica_logs/$samplename.csv
fi

# cat the ir.csv file so it can be seen in the logs for easy troubleshooting (is also an output but will not be output if job fails)
cat ~/out/ir_file/congenica_logs/$samplename.csv


mark-section "upload using docker image"
# docker run - mount the home directory as a share, use the env_file, ir_file.csv, $congenica_project and $analysis_name values determined above. 
# Write log direct into output folder
docker run -v /home/dnanexus/:/home/dnanexus/ --env-file ~/env_file congenica-client:2.2.0.0_3 --ir ~/out/ir_file/congenica_logs/$samplename.csv --project $congenica_project --name $analysis_name --log ~/out/ir_file/congenica_logs/"$analysis_name"_upload.log $opts
docker_status=$?
if [ $docker_status -ne 0 ]
then
    successful_app_run=$docker_status
    cat /home/dnanexus/out/logfile/congenica_logs/"$analysis_name"_upload.log
fi 

# cat the ir.csv file so it can be seen in the logs for easy troubleshooting (is also an output but will not be output if job fails)
cat ~/out/ir_file/congenica_logs/$analysis_name.csv

mark-section "Upload output"
# to do dx upload need to reset worker variable
unset DX_WORKSPACE_ID
# set the project the worker will upload to
dx cd $DX_PROJECT_CONTEXT_ID:
ls ~/out/ir_file/congenica_logs
# make folder for output - use -p so doesn't fail if file already exists
dx mkdir -p congenica_logs
# run dx upload command to the desired location - upload all files in the congenica_logs output folder 
dx upload --brief --path "$DX_PROJECT_CONTEXT_ID:/congenica_logs/" ~/out/ir_file/congenica_logs/*

mark-section "determine if app should complete successfully or fail"
if [ $successful_app_run -eq 0 ]
then
mark-success
exit 0
else
exit 1
fi
