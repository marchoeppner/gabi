# Quickstart guide

This guide is for the impatient to get you up and running as quickly as possible. Make sure to read the [full](usage.md) guide to learn about all the options that the pipeline exposes. 

## Choosing a software provisioning framework

GABI provides software on-the-fly. Use whatever profile (`-profile`) is appropriate for your system:

- conda
- apptainer
- singularity
- docker
- podman

We will use `-profile apptainer` for the examples below. Use a container framework over conda, if at all possible. 

## Three steps

Follow these three steps to run the integrated test and verify your installation:

### Install references

```bash
nextflow run bio-raum/gabi -profile apptainer \
--reference_base /path/to/references \
--build_references \\
--run_name build
-r main
```

This will download and install the pipeline references to `/path/to/references` (choose an appropriate path here).

### Run test

```bash
nextflow run bio-raum/gabi -profile apptainer,test \
--reference_base /path/to/references \
-r main
``` 
The integrated test simply downloads a set of Illumina WGS reads from ENA and assembles them. 

Or, if you want to test the ONT workflow:

```bash
nextflow run bio-raum/gabi -profile apptainer,test_ont \
--reference_base /path/to/references \
-r main
``` 

### Step three

There is no step three. Continue with our full [user guide](usage.md), read more about the [outputs](output.md) and also  make sure to double-check the [installation](installation.md) guide to learn how to set up a more specific profile for your local system. 

