# CX5461_WT361andWT224_WGS

Scripts for **Step 1** of the WGS analysis pipeline: raw data integrity verification,
reference indexing, and BWA-MEM alignment with per-sample lane merging.

## Study context

- **Cell lines**: WT361, WT224
- **Conditions**: DMSO control (CTR) and CX-5461 treatment (CX), 4 biological replicates each
- **Samples**: 16 total (2 cell lines x 2 conditions x 4 replicates)
- **Sequencing**: Illumina paired-end WGS, each sample spread over 2 flowcell lanes
- **Reference**: GRCh38 / hg38

## Requirements

| Item | Version |
|------|-------|
| BWA-MEM | 0.7.17-r1188 |
| SAMtools | (bundled in the container below) |
| Container | `/data/dockstore-cgpwgs_2.1.1.sif` (Apptainer / Singularity) |
| Reference | `/data/references/hg38_reference/hg38.fa` |

All tools are invoked through the container, so no local installation of BWA or
SAMtools is required beyond Apptainer itself.
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
