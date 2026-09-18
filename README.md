# CX5461_WT361andWT224_WGS

Scripts for **Step 1** of the WGS analysis pipeline: raw data integrity verification,
reference indexing, and BWA-MEM alignment with per-sample lane merging.

## Study context

- **Cell lines**: Ko361, NG224
- **Conditions**: DMSO control (CTR) and CX-5461 treatment (CX), 4 biological replicates each
- **Samples**: 16 total (2 cell lines x 2 conditions x 4 replicates)
- **Sequencing**: Illumina paired-end WGS, each sample spread over 2 flowcell lanes
- **Reference**: GRCh38 / hg38

## Requirements

| Item | Value |
|------|-------|
| BWA-MEM | 0.7.17-r1188 |
| SAMtools | (bundled in the container below) |
| Container | `/data/dockstore-cgpwgs_2.1.1.sif` (Apptainer / Singularity) |
| Reference | `/data/references/hg38_reference/hg38.fa` |

All tools are invoked through the container, so no local installation of BWA or
SAMtools is required beyond Apptainer itself. The container path is hard-coded in
the scripts and needs to be adjusted for a different environment.

## Input layout

Each sample lives in its own directory under `01.RawData/`, and each flowcell lane
contributes one paired-end pair of gzipped FASTQ files:

```
01.RawData/
└── <sample_name>/
    ├── <sample_name>_<flowcell>_<lane>_1.fq.gz
    └── <sample_name>_<flowcell>_<lane>_2.fq.gz
    ...
```

The lane and flowcell identifiers are parsed from the file names, so that naming
pattern must be preserved.

## Scripts

Run them in this order.

### 1. `00_verify_md5.sh` — raw data integrity check

Reads the expected checksums from `MD5.txt`, recomputes the MD5 of every `.fq.gz`
file it lists, and compares the two. Results are written to
`md5_verification_result.txt`.

Exits `0` only if every file passes; exits `1` if any file fails or is missing.

Run this **before** alignment. A truncated or corrupted FASTQ will otherwise
produce silently wrong alignments.

### 2. `00_bwa_index.sh` — reference indexing

Builds the BWA index for the hg38 reference. One-off step; only needs to be
re-run if the reference FASTA changes. Logs to `scripts/bwa_index.log`.

### 3. `01_bwa_alignment.sh` — alignment and lane merging

Three phases:

| Phase | What it does |
|-------|--------------|
| 1 | Scans every sample directory, pairs up R1/R2 per flowcell lane, and builds one global job queue across all samples |
| 1b | Runs the queue with `MAX_PARALLEL_BWA` alignment jobs in flight |
| 2 | Merges the per-lane BAMs of each sample into `<sample>.merged.bam`, with index |

Each lane is aligned with BWA-MEM (read group tagged `ID`/`SM`/`PU`/`LB`/`PL`),
piped into `samtools sort`, then indexed.

The alignment step is **resumable**: a lane whose `.sorted.bam` and `.bai` already
exist is skipped, and so is a sample whose `.merged.bam` already exists. If the run
is interrupted, just start it again.

### Tunable parameters

Set at the top of `01_bwa_alignment.sh`:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `BWA_THREADS` | 8 | Threads per BWA-MEM job |
| `SORT_THREADS` | 2 | Threads per `samtools sort` |
| `MAX_PARALLEL_BWA` | 3 | Concurrent alignment jobs |

## Output

```
03.BamData/
├── <sample>_<flowcell>_<lane>.sorted.bam      # per-lane, aligned + sorted
├── <sample>_<flowcell>_<lane>.sorted.bam.bai
├── <sample>.merged.bam                        # per-sample, lanes merged
├── <sample>.merged.bam.bai
├── logs/                                      # per-lane logs
└── tmp/
```

The merged BAMs are the input to the downstream duplicate-marking, QC, and
mutation-calling steps.
