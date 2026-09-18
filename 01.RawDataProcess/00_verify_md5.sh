#!/bin/bash
#===============================================================================
# MD5 verification script
# Compares MD5 checksums of all .fq.gz files against expected values
#===============================================================================

set -euo pipefail

BASE_DIR="/data/HannaRevisionSeq/X208SC26050186-Z01-F001"
MD5_MASTER="${BASE_DIR}/MD5.txt"
LOG_FILE="${BASE_DIR}/md5_verification_result.txt"
TEMP_EXPECTED="${BASE_DIR}/.md5_expected.txt"
TEMP_ACTUAL="${BASE_DIR}/.md5_actual.txt"

echo "  MD5 Verification Report" | tee -a "${LOG_FILE}"
echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

# Step 1: Parse expected MD5 values from master file, and selectonly .fq.gz entries
echo "--- Reading expected MD5 values from MD5.txt ---" | tee -a "${LOG_FILE}"

grep '\.fq\.gz$' "${MD5_MASTER}" | while read -r expected_md5 rel_path; do
    echo "${expected_md5}  ${rel_path}"
done > "${TEMP_EXPECTED}"

total_files=$(wc -l < "${TEMP_EXPECTED}")
echo "  Expected files: ${total_files}" | tee -a "${LOG_FILE}"

# Step 2: Compute the MD5 values for each .fq.gz file
echo "" | tee -a "${LOG_FILE}"
echo "--- Computing MD5 checksums (this may take a while) ---" | tee -a "${LOG_FILE}"

> "${TEMP_ACTUAL}"

# In parallel
count=0
while IFS= read -r line; do
    expected_md5=$(echo "$line" | awk '{print $1}')
    rel_path=$(echo "$line" | awk '{print $2}')
    abs_path="${BASE_DIR}/${rel_path}"

    if [[ -f "${abs_path}" ]]; then
        actual_md5=$(md5sum "${abs_path}" | awk '{print $1}')
        echo "${actual_md5}  ${rel_path}" >> "${TEMP_ACTUAL}"
        count=$((count + 1))
        echo "  [${count}/${total_files}] ${rel_path}" | tee -a "${LOG_FILE}"
    else
        echo "  [${count}/${total_files}] MISSING: ${rel_path}" | tee -a "${LOG_FILE}"
        echo "MISSING_FILE  ${rel_path}" >> "${TEMP_ACTUAL}"
    fi
done < "${TEMP_EXPECTED}"

echo "" | tee -a "${LOG_FILE}"

# Step 3: Compare the expected and actual MD5 values
echo "============================================" | tee -a "${LOG_FILE}"
echo "  Comparison Results" | tee -a "${LOG_FILE}"
echo "============================================" | tee -a "${LOG_FILE}"

pass_count=0
fail_count=0
missing_count=0

while IFS= read -r expected_line; do
    expected_md5=$(echo "$expected_line" | awk '{print $1}')
    rel_path=$(echo "$expected_line" | awk '{print $2}')

    actual_line=$(grep -F "  ${rel_path}" "${TEMP_ACTUAL}" || true)

    if [[ -z "${actual_line}" ]]; then
        echo "  MISSING: ${rel_path}" | tee -a "${LOG_FILE}"
        missing_count=$((missing_count + 1))
    else
        actual_md5=$(echo "${actual_line}" | awk '{print $1}')
        if [[ "${expected_md5}" == "${actual_md5}" ]]; then
            pass_count=$((pass_count + 1))
        else
            fail_count=$((fail_count + 1))
            echo "  FAIL: ${rel_path}" | tee -a "${LOG_FILE}"
            echo "    Expected: ${expected_md5}" | tee -a "${LOG_FILE}"
            echo "    Actual:   ${actual_md5}" | tee -a "${LOG_FILE}"
        fi
    fi
done < "${TEMP_EXPECTED}"

# Step 4: Summary and output
echo "" | tee -a "${LOG_FILE}"
echo "============================================" | tee -a "${LOG_FILE}"
echo "  Summary" | tee -a "${LOG_FILE}"
echo "============================================" | tee -a "${LOG_FILE}"
echo "  Total expected:  ${total_files}" | tee -a "${LOG_FILE}"
echo "  PASSED:          ${pass_count}" | tee -a "${LOG_FILE}"
echo "  FAILED:          ${fail_count}" | tee -a "${LOG_FILE}"
echo "  MISSING:         ${missing_count}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
echo "  Finished: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "${LOG_FILE}"

# Cleanup
rm -f "${TEMP_EXPECTED}" "${TEMP_ACTUAL}"

if [[ ${fail_count} -eq 0 && ${missing_count} -eq 0 ]]; then
    echo "" | tee -a "${LOG_FILE}"
    echo "  RESULT: All ${pass_count} files passed MD5 verification." | tee -a "${LOG_FILE}"
    exit 0
else
    exit 1
fi
