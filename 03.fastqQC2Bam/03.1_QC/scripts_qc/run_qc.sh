#!/bin/bash
set -euo pipefail
export APPTAINER_BINDPATH="/data:/data"

CONTAINER="/data/dockstore-cgpwgs_2.1.1.sif"
BAMDIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.BamData"
QCDIR="${BAMDIR}/qc"
LOGFILE="${QCDIR}/qc_summary.log"
HTMLFILE="${QCDIR}/qc_report.html"

echo "============================================" | tee "${LOGFILE}"
echo "  BAM QC Report — $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "${LOGFILE}"
echo "============================================" | tee -a "${LOGFILE}"

# Run flagstat & idxstats
for bam in "${BAMDIR}"/*.merged.bam; do
    sample=$(basename "${bam}" .merged.bam)
    echo "" | tee -a "${LOGFILE}"
    echo "=== ${sample} ===" | tee -a "${LOGFILE}"

    apptainer exec "${CONTAINER}" samtools flagstat -@ 4 "${bam}" > "${QCDIR}/${sample}_flagstat.txt" 2>> "${LOGFILE}"
    apptainer exec "${CONTAINER}" samtools idxstats -@ 4 "${bam}" > "${QCDIR}/${sample}_idxstats.txt" 2>> "${LOGFILE}"

    # send and mergeto log
    total=$(head -1 "${QCDIR}/${sample}_flagstat.txt" | awk '{print $1}')
    mapped=$(grep "mapped (" "${QCDIR}/${sample}_flagstat.txt" | head -1 | awk '{print $1}')
    pct=$(grep "mapped (" "${QCDIR}/${sample}_flagstat.txt" | head -1 | grep -oP '\(\K[^)]+' | head -1)
    paired=$(grep "properly paired" "${QCDIR}/${sample}_flagstat.txt" | awk '{print $1}')
    paired_pct=$(grep "properly paired" "${QCDIR}/${sample}_flagstat.txt" | grep -oP '\(\K[^)]+' | head -1)
    echo "  Total reads:    ${total}" | tee -a "${LOGFILE}"
    echo "  Mapped:         ${mapped} (${pct})" | tee -a "${LOGFILE}"
    echo "  Properly paired: ${paired} (${paired_pct})" | tee -a "${LOGFILE}"
done

echo "" | tee -a "${LOGFILE}"
echo "============================================" | tee -a "${LOGFILE}"
echo "  QC complete: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "${LOGFILE}"
echo "============================================" | tee -a "${LOGFILE}"
