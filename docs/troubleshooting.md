# Common issues

[Assembly and QC](#assembly-and-qc)

[Pacbio](#pacbio)

[Crashes and performance](#crashes-and-performance)

## Assembly and qc

### The pipeline did not close my assembly, even though I have used both Nanopore and Illumina reads. 

Many reasons can contribute to incomplete assemblies - from the starting material being of poor quality, insufficient sequencing depth, biases in your read data (i.e. loss of certain genomic regions during DNA extraction/preparation) or accidental mix-ups in sample assignment  of a subset of your reads. You can check results from ConfindR to see if all your reads are from the same strain and were not accidentally mixed up or in fact contaminated. 

That said, if you did everything right, it could be that the assembly algorithm we employ in this pipeline simply wasn't up to the task. Please let us know if you suspect that to be the case! We try to use state-of-the-art methods, but are always happy to learn new things. 

## Quast reports many differences and an incomplete assembly

GABI tries to find the best matching reference genome from RefSeq Bacteria for each sample against which Quast then benchmarks the respective assembly. That said, it is not guaranteed that the best match in RefSeq Bacteria is actually very closely related to your specimen, nor that the assembly is in fact "reference grade". Especially when using long reads for assembly, you may find that Quast reports many mismatches and errors. Our best guess is that the given RefSeq genome is more fragmented than your long-read or hybrid de-novo assembly, which then leads to such incongruencies. So most likely nothing wrong with your assembly but GABI simply being unable to match a reference grade genome to your sample. 

## Pacbio

### Why won't the pipeline combine short reads with HiFi reads?!

Please see the available assembly modes [here](usage.md#choosing-an-assembly-method). HiFi reads will almost always be sufficient and possibly superior for assembly than a hybrid approach - which is why we do not support it in GABI. If you disagree, please let us know, preferably with some tangible examples where this assumption was shown to be incorrect. 

### Can I use Pacbio subreads with GABI?

No. The HiFi format has been the defacto standard for Pacbio sequencing for a few years now. If you still have subread data, consider transforming it to CCS/HiFi using available [tools](https://ccs.how/). 

## Crashes and performance

### The pipeline crashes with an out-of-memory error in one of the processes. 

This could simply be an issue with your executing machine not having enough RAM to run some of the tools we put into this pipeline. The exact amount of RAM needed is difficult to predict and can depend on factors like read length and/or sequencing depth - but we suspect that at least 32GB RAM should be available to avoid RAM-related issues (preferably 64GB). 

If this is already the case for you, then it is more likely that you have not set a memory limit for your compute environment via a site-specifig [config file](https://github.com/marchoeppner/nf-configs/) or from the command line - in which case GABI will use the built-in default (128 GB Ram) - which may well exceed the limits of your system. Please check our section on manipulating [resource](usage.md#resources) limits from the command line. 

### Why is the pipeline so slow?

We assume you mean the overall start-up time - the performance of the individual processes is dictated by the capabilities of your hardware and the complexity/depth of your data. If the latter is a concern, you can check out the [usage](usage.md) information and ensure that the `--genome_size` option is not disabled for subsampling. 

Otherwise, if you run this pipeline without a site-specific config file, the pipeline will not know where to cache the various containers or conda environments. In such cases, it will install/download these dependencies into the respective work directory of your pipeline run, every time you run the pipeline. And yes, that is a little slow. Consider adding your own config file to make use of the caching functionality.

### My ONT assembly crashes with an obscure error

Please check if the option `--onthq` is set to `true` (this is the default!). It's possible that this setting is not appropriate for your data, which can lead Dragonflye to exit on an empty Fasta file halfway through the assembly process; you can disable this option by setting `--onthq false` and resume the pipeline (`-resume`).

### The pipeline immediately fails with a "no such file" error

Most likely you saw something like this:

```bash
ERROR ~ No such file or directory: 
```

This is most likely happening because you passed the `reference_base` option from a custom config file via the "-c" argument. There is currently a [known bug](https://github.com/nextflow-io/nextflow/issues/2662) in Nextflow which prevents the correct passing of parameters from a custom config file to the workflow. Please use the command line argument `--reference_base` instead or consider contributing a site-specific [config file](https://github.com/marchoeppner/nf-configs). 
