getwd()
setwd("/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.2.groupQC/output/ng224/")
getwd()

if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install("MutationalPatterns")
BiocManager::install("BSgenome.Hsapiens.UCSC.hg38")
library(fgsea)
BiocManager::install("fgsea")

cell_line <- "ko361"
cell_line <- "ng224"

library(data.table)
library(ggplot2)

#Read Somalier output
samples_file <- paste0(cell_line,".samples.tsv")
pairs_file <- paste0(cell_line,".pairs.tsv")

samples_dt <- fread(samples_file)
pairs_dt <- fread(pairs_file)

# PCA on genotype features
# Use non-zero variance columns as PCA features
feat_cols <- c("n_hom_ref", "n_het", "n_hom_alt", "n_unknown", "gt_depth_mean")
available <- intersect(feat_cols, names(samples_dt))
mat <- as.matrix(samples_dt[, ..available])
v <- apply(mat, 2, var)
mat <- mat[, v > 0, drop = FALSE]
rownames(mat) <- samples_dt$sample_id

pca <- prcomp(mat, scale. = TRUE)

pca_dt <- data.table(
  sample_id = rownames(pca$x),
  PC1 = pca$x[, 1],
  PC2 = pca$x[, 2],
  group = ifelse(grepl("CTR", rownames(pca$x)), "CTR (DMSO)", "CX (CX-5461)")
)

# ---- Plot ----
pve <- round(summary(pca)$importance[2, 1:2] * 100, 1)

p <- ggplot(pca_dt, aes(x = PC1, y = PC2, color = group, label = sample_id)) +
  geom_point(size = 4, alpha = 0.85) +
  geom_text(vjust = -1, size = 3) +
  scale_color_manual(values = c("CTR (DMSO)" = "#377EB8", "CX (CX-5461)" = "#E41A1C")) +
  labs(title = paste(cell_line, "-- SNP-based PCA (Somalier)"),
       subtitle = paste0("PC1 (", pve[1], "%)  |  PC2 (", pve[2], "%)"),
       x = "PC1", y = "PC2", color = "Group") +
  theme_minimal(base_size = 13)

p

colnames(pairs_dt)