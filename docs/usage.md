# Usage information

Please fist check out our [installation guide](installation.md), if you haven't already done so. 

[Running the pipeline](#running-the-pipeline)

[Choosing assembly method](#choosing-an-assembly-method)

[Options](#options)

[Expert options](#expert-options)

[Resources](#resources)

## Running the pipeline

Please see our [installation guide](installation.md) to learn how to set up this pipeline first. 

A basic execution of the pipeline looks as follows:

a) Without a site-specific config file

```bash
nextflow run marchoeppner/gabi -profile singularity --input samples.csv \\
--reference_base /path/to/references \\
--run_name pipeline-test
```

where `path_to_references` corresponds to the location in which you have [installed](installation.md) the pipeline references (this can be omitted to trigger an on-the-fly temporary installation, but is not recommended in production). 

In this example, the pipeline will assume it runs on a single computer with the singularity container engine available. Available options to provision software are:

`-profile singularity`

`-profile docker` 

`-profile podman`

`-profile conda` 

Additional software provisioning tools as described [here](https://www.nextflow.io/docs/latest/container.html) may also work, but have not been tested by us. Please note that conda may not work for all packages on all platforms. If this turns out to be the case for you, please consider switching to one of the supported container engines. In addition, you can set parameters such as maximum number of computing cores, RAM or the type of resource manager used (if any).

b) with a site-specific config file

```bash
nextflow run marchoeppner/gabi -profile lsh --input samples.csv \\
--run_name pipeline-test 
```

In this example, both `--reference_base` and the choice of software provisioning are already set in the local configuration `lsh` and don't have to be provided as command line argument. 

## Choosing an assembly method

How do you choose the assembly method for your data? Well, you don't - the pipeline will take care of that automatically. GABI currently supports three kinds of scenarios:

- Samples with only short reads (Assembler: Shovill)
- Samples with Nanopore reads and **optional** short reads (Assembler: Dragonflye)
- Samples with only Pacbio HiFi reads (Assembler: Flye)

This is why it is important to make sure that all reads coming from the same sample are linked by a common sample ID. 

## Options

### `--input samples.csv` [default = null]

This pipeline expects a CSV-formatted sample sheet to properly pull various meta data through the processes. The required format looks as follow>

```CSV
sample_id,platform,R1,R2
S100,ILLUMINA,/home/marc/projects/gaba/data/S100_R1.fastq.gz,/home/marc/projects/gaba/data/S100_R2.fastq.gz
```

If the pipeline sees more than one set of reads for a given sample ID and platform type, it will merge them automatically at the appropriate time. Based on what types of reads the pipeline sees, it will automatically trigger suitable tool chains. 

Allowed platforms and data types are:

* ILLUMINA (expecting PE Illumina reads in fastq format, fastq.gz)
* NANOPORE (expecting ONT reads in fastq format, fastq.gz)
* PACBIO (expecting Pacbio CCS/HiFi reads in fastq format, fastq.gz)
* TORRENT (expecting single-end IonTorrent reads in fastq format, fastq.gz) (tbd!)

Read data in formats other than FastQ are not currently supported and would have to be converted into the appropriate FastQ format prior to launching the pipeline. If you have a recurring use case where the input must be something other than FastQ, please let us know and we will consider it.

### `--run_name` [ default = null]

A name to use for various output files. This tend to be useful to relate analyses back to individual pipeline runs or projects later on. 

### `--reference_base` [ default = null ]

This option should point to the base directory in which you have installed the pipeline references. See our [installation](installation.md) instructions for details. For users who have contributed a site-specific config file, this option does not need to be set. 

### `--onthq` [ default = true ]

Set this option to true if you believe your ONT data to be of "high quality". This is typically the case for data generated with chemistry version 10.4.1 or later. This option is set to true by default because chemistry version 10.4.1 is the standard kit distributed by ONT at the time of writing. You can disable this option by setting it to `false`. 

### `--build_references` [ default = null ]

This option is only used when installing the pipelines references as described [here](installation.md).

## Expert options

These options are only meant for users who have a specific reason to touch them. For most use cases, the defaults should be fine. 

### `--subsample_reads` [ true|false, default = true]

Perform sub-sampling of (long reads) prior to assembly. This is meant to deal with needlessly deep data sets that could otherwise result in excessive run times or crashes. The degree of sub-sampling is controlled by `--max_coverage` combined with `--genome_size`. 

### `--max_coverage` [ default = '100x']

If sub-sampling (`--subsample_reads`) is enabled, this is the target coverage. This option is combined with `--genome_size`. 

### `--genome_size` [ default = 6Mb ]

If sub-sampling (`--subsample_reads`) is enabled, this is the assumed genome size against which the coverage is measured. Since this pipeline supports processing of diverse species in parallel, the default of 6Mb is a compromise and should at the very least prevent grossly over-sampled data to bring the workflow to its knees. Of course, if you only sequence a single species, you are welcome to set this to that specific genome size. 

### `--reference_fasta` [ default = null ]

GABI internally runs QUAST for assembly QC. For select taxa, we have pre-configured the NCBI reference genome and annotation for this purpose - which the pipeline will select automatically, if possible. If GABI cannot match an assembly to a reference, Quast will run without one.

If you have a run with samples from a single taxon and you wish to use your own reference genome for QUAST analysis, you can specify it with this option. This then also requires a custom annotation in gff3 format (`--reference_gff`, see below). 

### `--reference_gff` [ default = null ]

If you want to run Quast against your own reference genome, you also need to provide a matching annotation in gff3 format with this option. 

## Resources

The following options can be set to control resource usage outside of a site-specific [config](https://github.com/marchoeppner/nf-configs) file.

### `--max_cpus` [ default = 16]

The maximum number of cpus a single job can request. This is typically the maximum number of cores available on a compute node or your local (development) machine. 

### `--max_memory` [ default = 128.GB ]

The maximum amount of memory a single job can request. This is typically the maximum amount of RAM available on a compute node or your local (development) machine, minus a few percent to prevent the machine from running out of memory while running basic background tasks.

### `--max_time`[ default = 240.h ]

The maximum allowed run/wall time a single job can request. This is mostly relevant for environments where run time is restricted, such as in a computing cluster with active resource manager or possibly some cloud environments.  