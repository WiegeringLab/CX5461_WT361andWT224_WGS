#!/bin/bash

set -euo pipefail

export PATH="$HOME/bin:$PATH"

BAMDIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.BamData"
OUTDIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.2.groupQC/output/ko361"
EXTRACTDIR="${OUTDIR}/extracted"

mkdir -p "${EXTRACTDIR}"

echo "==="
echo "  Somalier PCA — Ko361"
echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==="

SAMPLES=(
  "Ko361_CTR_9"  "Ko361_CTR_10"  "Ko361_CTR_11"  "Ko361_CTR_12"
  "Ko361_CX_13"  "Ko361_CX_14"  "Ko361_CX_15"  "Ko361_CX_16"
)

# ---- Phase 1: Extract ----
echo ""
echo "=== Somalier: Extract ==="
for sample in "${SAMPLES[@]}"; do
    bam="${BAMDIR}/${sample}.merged.bam"
    out="${EXTRACTDIR}/${sample}.somalier"
    if [[ -f "${out}" ]]; then
        echo "  [SKIP] ${sample} (already extracted)"
    else
        echo "  [$(date '+%H:%M:%S')] Extracting ${sample} ..."
        somalier extract -d "${EXTRACTDIR}" -f /data/references/hg38_reference/hg38.fa \
            --sites /data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.2.groupQC/output/sites.hg38.vcf.gz "${bam}"
    fi
done

# ---- Phase 2: Relate ----
echo ""
echo "=== Somalier: Relate ==="
somalier relate -o "${OUTDIR}/ko361" "${EXTRACTDIR}"/*.somalier

echo ""
echo "==="
echo "  Somalier extract + relate complete — Ko361"
echo "  Output: ${OUTDIR}/"
echo "  Run:  Rscript output/plot_pca.R Ko361 ${OUTDIR}"
echo "  Finished: $(date '+%Y-%m-%d %H:%M:%S')"