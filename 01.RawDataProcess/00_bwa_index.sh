#!/bin/bash
set -euo pipefail
export APPTAINER_BINDPATH="/data:/data"

LOG="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/scripts/bwa_index.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting BWA index for hg38..." | tee "${LOG}"
apptainer exec /data/dockstore-cgpwgs_2.1.1.sif \
    bwa index /data/references/hg38_reference/hg38.fa 2>&1 | tee -a "${LOG}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] BWA index complete." | tee -a "${LOG}"
