#!/bin/bash
#===============================================================================
# Container: /data/dockstore-cgpwgs_2.1.1.sif
# Each sample: 2 flowcell-lanes × paired-end, should produce 4 fastq.gz files
#
# Output: /data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.BamData/
#===============================================================================

set -euo pipefail

export APPTAINER_BINDPATH="/data:/data"

CONTAINER="/data/dockstore-cgpwgs_2.1.1.sif"
REF_FA="/data/references/hg38_reference/hg38.fa"
RAWDIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/01.RawData"
OUTDIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.BamData"
LOGDIR="${OUTDIR}/logs"
TMPDIR="${OUTDIR}/tmp"

# Multithreds
BWA_THREADS=8      
SORT_THREADS=2       
MAX_PARALLEL_BWA=3   

mkdir -p "${OUTDIR}" "${LOGDIR}" "${TMPDIR}"


align_lane() {
    local sample=$1        
    local flowcell=$2     
    local lane=$3         
    local r1=$4         
    local r2=$5          

    local rg_id="${flowcell}.${lane}"
    local rg_sm="${sample}"
    local rg_pu="${flowcell}.${lane}"
    local rg_lb="${sample}"
    local rg_pl="ILLUMINA"

    local out_prefix="${OUTDIR}/${sample}_${flowcell}_${lane}"
    local sorted_bam="${out_prefix}.sorted.bam"
    local log_file="${LOGDIR}/${sample}_${flowcell}_${lane}.log"

    echo "[$(date '+%H:%M:%S')] BWA: ${sample}  ${rg_id}" | tee -a "${log_file}"

    apptainer exec --bind /data:/data "${CONTAINER}" \
        bwa mem -t "${BWA_THREADS}" -M \
        -R "@RG\tID:${rg_id}\tSM:${rg_sm}\tPU:${rg_pu}\tLB:${rg_lb}\tPL:${rg_pl}" \
        "${REF_FA}" "${r1}" "${r2}" \
        2>> "${log_file}" \
        | apptainer exec --bind /data:/data "${CONTAINER}" samtools sort -@ "${SORT_THREADS}" -m 16G -o "${sorted_bam}" - \
        2>> "${log_file}"

    apptainer exec --bind /data:/data "${CONTAINER}" samtools index "${sorted_bam}" 2>> "${log_file}"

    echo "[$(date '+%H:%M:%S')] Done: ${sorted_bam}" | tee -a "${log_file}"
}

# Add tag in log files
echo "  BWA-MEM Alignment Pipeline"
echo "  Reference:  ${REF_FA}"
echo "  Container:  ${CONTAINER}"
echo "  Started:    $(date '+%Y-%m-%d %H:%M:%S')"

mapfile -t sample_dirs < <(ls -d "${RAWDIR}"/*/ | grep -v '^$')
echo "Found ${#sample_dirs[@]} sample directories"

# Phase 1a: scan all samples and build a global job queue

declare -A LANE_BAMS

JOB_QUEUE=()
# cleanup
TOTAL_JOBS=0
SKIP_COUNT=0

for sample_dir in "${sample_dirs[@]}"; do
    sample=$(basename "${sample_dir}")
    echo ""
    echo "=== Scanning: ${sample} ==="

    declare -A lane_pairs

    while IFS= read -r -d '' fq; do
        fname=$(basename "${fq}")
        base="${fname%.fq.gz}"
        read_num="${base##*_}"
        base="${base%_*}"
        lane_field="${base##*_}"
        base="${base%_*}"
        flowcell="${base##*_}"
        key="${flowcell}_${lane_field}"
        if [[ "${read_num}" == "1" ]]; then
            lane_pairs["${key}"]="${fq} ${lane_pairs[${key}]:-}"
        else
            lane_pairs["${key}"]="${lane_pairs[${key}]:-} ${fq}"
        fi
    done < <(find "${sample_dir}" -name "*.fq.gz" -type f -print0)

    lane_bams=()

    for key in "${!lane_pairs[@]}"; do
        read -r r1 r2 <<< "${lane_pairs[$key]}"
        flowcell="${key%_*}"
        lane_name="${key##*_}"
        sorted_bam="${OUTDIR}/${sample}_${flowcell}_${lane_name}.sorted.bam"
        lane_bams+=("${sorted_bam}")

        if [[ -f "${sorted_bam}" && -f "${sorted_bam}.bai" ]]; then
            echo "  Lane: ${key}  SKIP (already completed)"
            SKIP_COUNT=$((SKIP_COUNT + 1))
            TOTAL_JOBS=$((TOTAL_JOBS + 1))
            continue
        fi

        echo "  Lane: ${key}  TODO  R1=$(basename "${r1}")  R2=$(basename "${r2}")"

        # Add to global queue: sample|flowcell|lane|r1|r2|sorted_bam
        JOB_QUEUE+=("${sample}|${flowcell}|${lane_name}|${r1}|${r2}|${sorted_bam}")
        TOTAL_JOBS=$((TOTAL_JOBS + 1))
    done

    LANE_BAMS["${sample}"]="${lane_bams[*]}"
    unset lane_pairs
done

# Write the job to log file
echo ""
echo "============================================"
echo "  Phase 1: Global alignment queue"
echo "  Total lanes:     ${TOTAL_JOBS}"
echo "  Already done:    ${SKIP_COUNT}"
echo "  To align:        ${#JOB_QUEUE[@]}"
echo "============================================"

# Phase 1b: process global queue with cross-sample parallelism

#cleanup
running=0
done_count=0

for job in "${JOB_QUEUE[@]}"; do
    IFS='|' read -r job_sample job_flowcell job_lane job_r1 job_r2 job_bam <<< "${job}"

    align_lane "${job_sample}" "${job_flowcell}" "${job_lane}" "${job_r1}" "${job_r2}" &

    running=$((running + 1))
    done_count=$((done_count + 1))

    if [[ ${running} -ge ${MAX_PARALLEL_BWA} ]]; then
        wait -n   
        running=$((running - 1))
    fi
done

wait
echo ""
echo "  All ${done_count} lanes completed."

# Phase 2: merge lanes per sample

for sample_dir in "${sample_dirs[@]}"; do
    sample=$(basename "${sample_dir}")
    read -ra bams <<< "${LANE_BAMS[${sample}]}"
    merged_bam="${OUTDIR}/${sample}.merged.bam"

    # Checkpoint: skip if merged BAM already exists
    if [[ -f "${merged_bam}" && -f "${merged_bam}.bai" ]]; then
        echo "[$(date '+%H:%M:%S')] Merged: ${sample}  SKIP (already completed)"
        continue
    fi

    echo "[$(date '+%H:%M:%S')] Merging ${sample}: ${#bams[@]} lanes"

    if [[ ${#bams[@]} -eq 1 ]]; then
    
        cp "${bams[0]}" "${merged_bam}"
        cp "${bams[0]}.bai" "${merged_bam}.bai"
    else
        apptainer exec --bind /data:/data "${CONTAINER}" samtools merge -@ 8 -f "${merged_bam}" "${bams[@]}"
        apptainer exec --bind /data:/data "${CONTAINER}" samtools index "${merged_bam}"
    fi
    

    echo "[$(date '+%H:%M:%S')] Merged: ${merged_bam}"
done

echo ""
echo "============================================"
echo "  Alignment complete"
echo "  Output: ${OUTDIR}/*.merged.bam"
echo "  Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
