#!/bin/bash

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail
mark-section "download inputs"
#Download sapientia credintials from 001_authentication
dx cat project-FQqXfYQ0Z0gqx7XG9Z2b4K43:sapientia_env > env_file

# download all inputs
dx-download-all-inputs --parallel

mark-section "determine run specific variables"
# If analysis name was not specified (default = "") then use the project name
if [[ "$analysis_name" == "" ]]
    then
    # build name from project name - This is the name of the run project (003_runfolder_library_number)
    # use dx describe --name to extract the project name from the variable which holds the project id and remove 002_ or 003_ from the start
    analysis_name=$(dx describe --name "$DX_PROJECT_CONTEXT_ID" | sed 's/00[23]_//')
    echo "analysis name created from project name: " $analysis_name
else
    echo "analysis_name provided - " $analysis_name
fi

# get project - this is an string input
echo "sapientia project = " $sapientia_project

# make output folders for log file and ir_file
mkdir -p ~/out/logfile/sapientia_logs/ ~/out/ir_file/sapientia_logs

# build ir file
# need to populate sample name, sex, bamfile and vcf file paths for each vcf
mark-section "build ir file"

for vcf in $VCF_path
do
    # extract the sample name to match that in the vcf by taking everything before .vcf (NGS282rpt_16_136819_NA12878_F_WES47_Pan493_S16)
    samplename=$(echo $(basename $vcf) | cut -d"." -f1)
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
    # for this vcf look to see if there is a BAM file.
    for bam in $BAM_path
    do
        # look if sample name (created above) is present in the bamfile name. If so take the bam path
        if [[ $samplename =~ $bam ]]
        then
            bamfile=$bam
        else
            bamfile=""
        fi
    done
    # write the sample details to the ir csv file
    echo "$samplename,$sex,,affected,1,,,,,,,,$bamfile,,,,$vcf," >> ~/ir_file.csv
done

# cat the file so it can be seen in the logs for easy troubleshooting (is also an output)
cat ~/ir_file.csv

mark-section "upload using docker image"
# Use congenica upload client docker image
# docker load
docker load -i '/home/dnanexus/congenica-client.2.1.0.0_1.tar.gz' 

# docker run - mount the home directory as a share, use the env_file,ir_file.csv, $sapientia_project and analysis_name values determined above. Write log direct into output folder
# redirect the stdout into a second log file
docker run -v /home/dnanexus/:/home/dnanexus/ --env-file ~/env_file congenica-client:2.1.0.0_1 --ir ~/ir_file.csv --project $sapientia_project --name $analysis_name --log /home/dnanexus/out/logfile/sapientia_logs/"$analysis_name"_upload.log | tee /home/dnanexus/out/logfile/sapientia_logs/"$analysis_name"_client_stdout.log

mark-section "prepare outputs"
# rename and move the ir to the output folder
mv ~/ir_file.csv ~/out/ir_file/sapientia_logs/"$analysis_name"_ir.csv

# Send output back to DNAnexus project
mark-section "Upload output"
dx-upload-all-outputs --parallel

mark-success