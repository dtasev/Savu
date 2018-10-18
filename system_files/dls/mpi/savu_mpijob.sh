version=$1
shift 1
module load savu/$version

savupath=$1
datafile=$2
processfile=$3
outfile=$4
nCPUs=$5
nGPUs=$6
delete=$7
shift 7

export PYTHONPATH=$savupath:$PYTHONPATH
filename=$savupath/savu/tomo_recon.py

UNIQHOSTS=${TMPDIR}/machines-u
awk '{print $1 }' ${PE_HOSTFILE} | uniq > ${UNIQHOSTS}
uniqslots=$(wc -l <${UNIQHOSTS})
echo "number of uniq hosts: ${uniqslots}"
echo "running on these hosts:"
cat ${UNIQHOSTS}

# Adding slots flag to each unique host to replace
# multiple entries in file.
typeset TMP_FILE=$( mktemp )
touch "${TMP_FILE}"
cp -p ${UNIQHOSTS} "${TMP_FILE}"
sed -e "s/$/ slots=${nCPUs}/" -i ${TMP_FILE}

processes=`bc <<< "$((uniqslots*nCPUs))"`

for i in $(seq 0 $((nGPUs-1))); do GPUs+="GPU$i " ; done
for i in $(seq 0 $((nCPUs-1-nGPUs))); do CPUs+="CPU$i " ; done
CPUs=$(echo $GPUs$CPUs | tr ' ' ,)
echo $CPUs

echo "Processes running are : ${processes}"

if [ ! $delete == false ]; then
  delete=`readlink -f $delete`
  echo "***Deleting the intermediate folder" $delete "at the end of this run"
fi

mpirun -np ${processes} \
       -mca btl sm,self,openib \
       -x LD_LIBRARY_PATH \
       --hostfile ${TMP_FILE} \
       python $filename $datafile $processfile $outfile -n $CPUs -v $@

if [ ! $delete == false ]; then
  cd /dls/tmp/savu
  cp $delete/savu.o* $delete/../
  rm -rf $delete
fi

