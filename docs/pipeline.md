# Pipeline structure

![](../images/gabi_workflow.png)

Now, that looks very complex - and indeed it is. But we can break it down into a few key steps:

- Perform quality control of the read data, and merge libraries across lanes
- Group read data by sample id and check which assembly tool is appropriate based on the types of sequencing data we have available
- Perform taxonomic profiling on one set of reads per sample id, preferably Illumina (so we know which species this is from)
- Assemble reads with the optimal tool
- Perform quality checks on the assembly
- Perform MLST typing on the assembly, if we know which species this is and if we have a pre-configured database for that species
- Annotate gene models in our assembled genome
- Predict antimicrobial resistance genes from our annotation
- Make a pretty QC report
