# Usage information

Please fist check out our [installation guide](installation.md), if you haven't already done so. 

[Running the pipeline](#running-the-pipeline)

[Options](#options)

[Specialist options](#specialist-options)

## Running the pipeline

Please see our [installation guide](installation.md) to learn how to set up this pipeline first. 

A basic execution of the pipeline looks as follows:

a) Without a site-specific config file

```bash
nextflow run marchoeppner/gabi -profile standard,singularity --input samples.csv \\
--reference_base /path/to/references \\
--run_name pipeline-test
```

where `path_to_references` corresponds to the location in which you have [installed](installation.md) the pipeline references (this can be omitted to trigger an on-the-fly temporary installation, but is not recommended in production). 

In this example, the pipeline will assume it runs on a single computer with the singularity container engine available. Available options to provision software are:

`-profile standard,singularity`

`-profile standard,docker` 

`-profile standard,podman` 

`-profile standard,conda` 

Additional software provisioning tools as described [here](https://www.nextflow.io/docs/latest/container.html) may also work, but have not been tested by us. Please note that conda may not work for all packages on all platforms. If this turns out to be the case for you, please consider switching to one of the supported container engines. 

b) with a site-specific config file

```bash
nextflow run marchoeppner/gabi -profile lsh --input samples.csv \\
--run_name pipeline-test 
```

In this example, both `--reference_base` and the choice of software provisioning are already set in the local configuration `lsh` and don't have to be provided as command line argument. 

## Options

### `--input samples.csv` [default = null]

This pipeline expects a CSV-formatted sample sheet to properly pull various meta data through the processes. The required format looks as follow>

```CSV
sample_id,platform,R1,R2
S100,ILLUMINA,/home/marc/projects/gaba/data/S100_R1.fastq.gz,/home/marc/projects/gaba/data/S100_R2.fastq.gz
```

If the pipeline sees more than one set of reads for a given sample ID and platform type, it will merge them automatically at the appropriate time. Based on what types of reads the pipeline sees, it will automatically trigger suitable tool chains. 

Allowed platforms are:

* ILLUMINA (expecting PE Illumina reads in fastq format, fastq.gz)
* NANOPORE (expecting ONT reads in fastq format, fastq.gz)
* PACBIO (expecting Pacbio CCS reads in fastq format, fastq.gz)
* TORRENT (expecting single-end IonTorrent reads in fastq format, fastq.gz)
