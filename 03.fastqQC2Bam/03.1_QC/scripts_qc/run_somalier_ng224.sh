#!/bin/bash

set -euo pipefail

export PATH="$HOME/bin:$PATH"

BAMDIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.BamData"
OUTDIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.2.groupQC/output/ng224"
EXTRACTDIR="${OUTDIR}/extracted"
THREADS=8

mkdir -p "${EXTRACTDIR}"

echo "==="
echo "  Somalier PCA — NG224"
echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==="

SAMPLES=(
  "NG224_CTR_1"  "NG224_CTR_2"  "NG224_CTR_3"  "NG224_CTR_4"
  "NG224_CX_5"   "NG224_CX_6"   "NG224_CX_7"   "NG224_CX_8"
)

# ---- Step 1: Extract Somalier sites from each BAM ----
echo ""
echo "=== Phase 1: Extract ==="
for sample in "${SAMPLES[@]}"; do
    bam="${BAMDIR}/${sample}.merged.bam"
    out="${EXTRACTDIR}/${sample}.somalier"
    if [[ -f "${out}" ]]; then
        echo "  [SKIP] ${sample} (already extracted)"
    else
        echo "  [$(date '+%H:%M:%S')] Extracting ${sample} ..."
        # First sample creates sites.vcf.gz; subsequent samples reuse it
        somalier extract -d "${EXTRACTDIR}" -f /data/references/hg38_reference/hg38.fa \
            --sites /data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.2.groupQC/output/sites.hg38.vcf.gz "${bam}"
    fi
done

# ---- Step 2: Relate — compute pairwise relatedness + PCA ----
echo ""
echo "=== Phase 2: Relate (PCA) ==="
somalier relate -o "${OUTDIR}/ng224" "${EXTRACTDIR}"/*.somalier

echo ""
echo "==="
echo "  Somalier extract + relate complete — NG224"
echo "  Output: ${OUTDIR}/"
echo "  Run:  Rscript output/plot_pca.R NG224 ${OUTDIR}"
echo "  Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==="
