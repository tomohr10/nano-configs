
# Usage: ./runT2BRun2.sh <2018|2017|2016preVFP|2016postVFP> [--dryrun]
#            [--prepare-recovery-task|--submit-recovery-task [--force]]
#            [--switch-to-filebased]
#            [--blacklist=T2_US_Florida[,...]] [--only=REGEX]

DRYRUN=""
PREPARE_RECOVERY_TASK=""
SUBMIT_RECOVERY_TASK=""
RECOVERY_PREFIX=""
SWITH_TO_FILEBASED=""
FORCE=""
CRAB_OPTIONS=()
ONLY=""

args=()
for arg in "$@"; do
    if [[ "$arg" == "--dryrun" ]]; then
        DRYRUN="--dryrun"
    fi
    if [[ "$arg" == "--prepare-recovery-task" ]]; then
        PREPARE_RECOVERY_TASK="--prepare-recovery-task"
        RECOVERY_PREFIX="--recovery-task-suffix _filebased_v3"
    fi
    if [[ "$arg" == "--submit-recovery-task" ]]; then
        SUBMIT_RECOVERY_TASK="--submit-recovery-task"
        RECOVERY_PREFIX="--recovery-task-suffix _filebased_v3"
    fi
    if [[ "$arg" == "--switch-to-filebased" ]]; then
        SWITH_TO_FILEBASED="--switch-to-filebased"
    fi
    if [[ "$arg" == --only=* ]]; then
        ONLY="${arg#--only=}"
        continue
    fi
    if [[ "$arg" == --blacklist=* ]]; then
        CRAB_OPTIONS=(--options "siteblacklist=${arg#--blacklist=}")
        continue
    fi
    if [[ "$arg" == "--force" && -n "$RECOVERY_PREFIX" ]]; then
        FORCE="--yes"
    else
        args+=("$arg")
    fi
done
set -- "${args[@]}"

YEAR=$1
case ${YEAR} in
    2018*)       YEAR=2018;        PSET_TAG=2018UL ;;
    2017*)       YEAR=2017;        PSET_TAG=2017UL ;;
    2016preVFP)  PSET_TAG=2016ULpreVFP ;;
    2016postVFP) PSET_TAG=2016ULpostVFP ;;
    *)
        echo "Unknown year '${YEAR}'. Use 2018, 2017, 2016preVFP or 2016postVFP."
        exit 1
        ;;
esac
# 2018 keeps its historic work-area names
WA_SUFFIX=${YEAR}v15

python3 sampleGeneration.py ${YEAR} --user $USER --skip-check || exit 1

# --only=REGEX: submit only the datasets matching REGEX (e.g. for a first test
# task), the others are commented out in the generated confs
if [[ -n "${ONLY}" ]]; then
    for CONF in mc/mc_${YEAR}.conf data/data_${YEAR}.conf; do
        awk -v re="${ONLY}" '/^\// && $0 !~ re {print "# " $0; next} {print}' ${CONF} > ${CONF}.tmp \
            && mv ${CONF}.tmp ${CONF}
        echo "--- --only: $(grep -c '^/' ${CONF}) active dataset(s) in ${CONF}"
    done
fi

for TYPE in data mc; do
    if [[ ${TYPE} == data ]]; then
        SPLIT=(-s EventAwareLumiBased -n 100000)
    else
        SPLIT=(-s FileBased -n 2)
    fi
    CONF=${TYPE}/${TYPE}_${YEAR}.conf
    if ! grep -q '^/' ${CONF} 2>/dev/null; then
        echo "--- No ${TYPE} datasets for ${USER} in ${CONF}, skipping"
        continue
    fi
    python3 crab.py \
        -p ${TYPE}_${PSET_TAG}_NANO.py \
        --site T2_BE_IIHE \
        -o /store/group/CustomNanoAODv15/NanoTuples/${YEAR}/${TYPE} \
        -t NanoTuples-uParTv3-parTlepID-NanoAODv15 \
        -i ${CONF} \
        -e exe_ULv15_nosel.sh \
        --num-cores 2 \
        "${SPLIT[@]}" \
        --work-area crab_projects/crab_projects_${TYPE}_${WA_SUFFIX} \
        --input-files inputs \
        --max-memory 4500 \
        --max-job-runtime 2750 \
        "${CRAB_OPTIONS[@]}" \
        $DRYRUN \
        $PREPARE_RECOVERY_TASK \
        $SUBMIT_RECOVERY_TASK \
        $RECOVERY_PREFIX $FORCE \
        $SWITH_TO_FILEBASED
done
