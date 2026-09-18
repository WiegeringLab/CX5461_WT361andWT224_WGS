Library(ggplot2)

qc_dir  <- "/data/HannaRevisionSeq/X208SC26050186-Z01-F001/03.BamData/qc"
logfile <- file.path(qc_dir, "qc_summary.log")
out_dir <- file.path(qc_dir, "r_plots")

samples  <- grep("^=== .+ ===$", lines, value = TRUE)
samples  <- sub("^=== ", "", samples)
samples  <- sub(" ===$", "", samples)

mapped_lines <- grep("^  Mapped:", lines, value = TRUE)
mapped_pct   <- as.numeric(sub(".*\\(([0-9.]+)% : N/A\\)", "\\1", mapped_lines))

paired_lines <- grep("^  Properly paired:", lines, value = TRUE)
paired_pct   <- as.numeric(sub(".*\\(([0-9.]+)% : N/A\\)", "\\1", paired_lines))

df <- data.frame(
  sample       = samples,
  ProperlyPaired = paired_pct,
  MappedOther  = mapped_pct - paired_pct,
  stringsAsFactors = FALSE
)

# Reshape dataframe to long
df_long <- reshape(df, direction = "long",
                   varying = c("ProperlyPaired", "MappedOther"),
                   v.names = "pct", timevar = "metric",
                   times = c("ProperlyPaired", "MappedOther"),
                   idvar = "sample")

df_long$metric <- factor(df_long$metric,
                         levels = c("MappedOther", "ProperlyPaired"))
df_long$group  <- ifelse(grepl("^Ko361", df_long$sample), "Ko361", "NG224")
df_long$sample <- factor(df_long$sample,
                         levels = sort(unique(df_long$sample)))

# Plot
make_plot <- function(data, group_name) {
  pal <- c("MappedOther" = "deepskyblue2", "ProperlyPaired" = "darkorange1")
  labels <- c("MappedOther" = "Mapped (other)", "ProperlyPaired" = "Properly paired")

  p <- ggplot(data, aes(x = sample, y = pct, fill = metric)) +
    geom_col(width = 0.7) +
    scale_fill_manual(values = pal, labels = labels) +
    scale_y_continuous(
      limits = c(0, 105),
      expand = c(0, 0),
      breaks = seq(0, 100, 20)
    ) +
    labs(
      title = paste0(group_name, " — Mapped & Properly Paired"),
      x     = "",
      y     = "Percentage (%)",
      fill  = "Metric"
    ) +
    theme_bw(base_size = 13) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1, size = 9),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank()
    )

  out_path <- file.path(out_dir, paste0(group_name, "_mapped_paired_barplot.png"))
  ggsave(out_path, p, width = max(7, nrow(data) / 2 * 0.8), height = 6, dpi = 150)
  message("Saved: ", out_path)
}

# Generate plot in one go
make_plot(subset(df_long, group == "Ko361"), "Ko361")
make_plot(subset(df_long, group == "NG224"), "NG224")
