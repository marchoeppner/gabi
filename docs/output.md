# Outputs 

## Reports

<details markdown=1>
<summary>Sample results</summary>

For each sample, a folder is created with results from various tools, as follows:

- amr - Predictions of antimicrobial resistance genes
  - abricate - Results from Abricate
  - amrfinderplus - Results from AMFfinderPlus
- annotation - Gene model predictions
  - prokka - Prokka annotations
- assembly - The genome assembly and related information
  - busco - Busco analysis of gene space coverage
  - quast - Quast assembly metrics
  - flye/dragonflye/shovill - the assembler output(s)
- mlst - MLST typing results
- Plamids - Identification of plasmids from the assembly
- qc - Basic read QC
  - fastqc - Quality metrics of reads
  - confindr_results - ConfindR contamination check
- taxonomy - Taxonomic profiling using raw reads
  - kraken2 - Results from Kraken2
- sample.json - A coarse summary of various sample-level results

</details>

## QC

<details markdown=1>
<summary>MultiQC</summary>

- run_name_multiqc_report.html - Sample-level summary
- Illumina - QC metrics relating to Illumina data
- Nanopore - QC metrics relating to Nanopore data
- Pacbio - QC metrics relating to Pacbio data

</details>

## Run metrics

<details markdown=1>
<summary>pipeline_info</summary>

This folder contains the pipeline run metrics

- pipeline_dag.svg - the workflow graph (only available if GraphViz is installed)
- pipeline_report.html - the (graphical) summary of all completed tasks and their resource usage
- pipeline_report.txt - a short summary of this analysis run in text format
- pipeline_timeline.html - chronological report of compute tasks and their duration
- pipeline_trace.txt - Detailed trace log of all processes and their various metrics

</details>

