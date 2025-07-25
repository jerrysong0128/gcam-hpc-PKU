#!/bin/bash 

# This is the main script used for running GCAM on the Evergreen cluster
# It is adapted from the NERSC version!

source ./gcam-hpc-tools/gcam_workspace.setup

if [ -z "$GCAM_WORKSPACE" ]; then
    echo "NOTICE: Please set GCAM_WORKSPACE to the absolute path of your gcam-hpc-PKU repo"
    echo "Example: export GCAM_WORKSPACE=/path/to/your/gcam-workspace"
fi
export GCAMDIR=${GCAM_WORKSPACE}/gcam-core
export SCRATCHDIR=${GCAM_WORKSPACE}/gcam-scratch


EXPECTED_ARGS=2

RUN_SCRIPT=./gcam-hpc-tools/run-tools/run_model.sh

PBS_TEMPLATEFILE=./gcam-hpc-tools/run-tools/run-template/gcam_template_WM2.slurm
PBS_BATCHFILE=./gcam-hpc-tools/run-tools/run-template/gcam.slurm



if [ $# -eq $EXPECTED_ARGS ] ; then
	echo "This is $0"
else
	echo "Usage: <script name> <template config file> <batch file>"
	exit 
fi

# --------------------------------------------------------------------------------------------
# 1. Copy everything over to scratch directory and work there
# --------------------------------------------------------------------------------------------


# skip sync of files (possibly would want to do this from HOME to EMSL_HOME?)
RUN_DIR_NAME=
#WORKSPACE_DIR_NAME=/sfs/qumulo/qhome/${COMP_ID}/gcam_dac_high_elec
INPUT_OPTIONS="--include=*.xml --include=Hist_to_2008_Annual.csv --exclude=.svn --exclude=*.*"

#otherwise will append
#jf-- commented out first line bc it was throwing errors
#mv -f ${GCAMDIR}/${RUN_DIR_NAME}/output/queryoutall*.csv ${GCAMDIR}/${RUN_DIR_NAME}/output/queries/
#cd ${GCAMDIR}/${RUN_DIR_NAME}

# --------------------------------------------------------------------------------------------
# 2. Generate the required permutations of the base configuration file
# --------------------------------------------------------------------------------------------
        
template_path=`dirname $1`
template_root=`basename $1 | cut -f 1 -d.`
echo $template_path
echo $template_root

echo "Generate permutations (y/n)?"
read generate
if [[ $generate = 'y' ]]; then
        echo "Generating..."
        ./gcam-hpc-tools/run-tools/permutator.sh $1 $2
        if [[ $? -lt 0 ]]; then
                exit;
        fi
fi

# --------------------------------------------------------------------------------------------
# 3. Figure out how many jobs will be run and generate the gcam.pbs batch file
# --------------------------------------------------------------------------------------------

first_task=0

echo "Number of SIMULTANEOUS RUNS to run (normally same as total runs)?"
read num_tasks
ntasks_total=$((8 * num_tasks))

let "last_task=$num_tasks - 1"

let "tasks=$last_task - $first_task + 1"

sed -e "s/NUM_TASKS/${num_tasks}/g" -e "s/NTASKS_TOTAL/${ntasks_total}/g" "$PBS_TEMPLATEFILE" \
> "$PBS_BATCHFILE"
	
for (( i=0; i<$num_tasks; i++ )); do
    echo "srun -n 1 ./gcam-hpc-tools/run-tools/mpi_wrapper.exe ${template_path}/${template_root} $i &" >> $PBS_BATCHFILE
done
echo "wait" >> $PBS_BATCHFILE

# --------------------------------------------------------------------------------------------
# 4  Go ahead and run!
# --------------------------------------------------------------------------------------------

echo "Run $tasks tasks on cluster (y/n)?"
read run

if [[ $run = 'y' ]]; then
	echo "Syncing input directory to scratch (only changed files)..."
	rsync -av --delete "${GCAMDIR}/input/" "${SCRATCHDIR}/input/"
	echo "Done syncing input directory"	

	echo "Creating empty output and error directories in scratch directory..."
    
	if [[ -d ${SCRATCHDIR/output} ]]; then
        rm -rf ${SCRATCHDIR}/output
		echo "Removed existing scratch output folder"
    fi
    mkdir ${SCRATCHDIR}/output

	echo "Copying queries directory to scratch output..."
	rm -rf ${SCRATCHDIR}/output/queries	 	# just in case
	cp -fR ${GCAMDIR}/output/queries ${SCRATCHDIR}/output/queries
    echo "Done copying queries directory"

	if [[ -d ${SCRATCHDIR/errors} ]]; then
        rm -rf ${SCRATCHDIR}/errors
		echo "Removed existing scratch errors folder"
    fi
    mkdir ${SCRATCHDIR}/errors
	
    echo "Done creating scratch directories."


	job=`sbatch $PBS_BATCHFILE`
	echo "We are off and running with job $job"

fi

#./watch_pbs.sh


exit


# --------------------------------------------------------------------------------------------
# 5. Cleanup
# --------------------------------------------------------------------------------------------

# Delete the configuration files for tasks we're not running
echo "All done.  Delete generated configuration files?"
read del
if [[ $del -eq 'y' ]]; then
	t=0
	while [ $t -lt $first_task ];
	do
		echo "Removing {template_root}_${t}.xml"
		rm ${template_path}/${template_root}_${t}.xml
		let "t += 1"
	done
fi

