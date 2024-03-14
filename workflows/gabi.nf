// Modules
include { INPUT_CHECK }                 from './../modules/input_check'
include { MULTIQC }                     from './../modules/multiqc'
include { UNICYCLER }                   from './../modules/unicycler'
include { SHOVILL }                     from './../modules/shovill'
include { RENAME_CTG as RENAME_SHOVILL_CTG } from './../modules/rename_ctg'
include { RENAME_CTG as RENAME_DRAGONFLYE_CTG } from './../modules/rename_ctg'
include { SRST2_SRST2 }                 from './../modules/srst2/srst2'
include { DRAGONFLYE }                  from './../modules/dragonflye'
include { PROKKA }                      from './../modules/prokka'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './../modules/custom/dumpsoftwareversions'

// Subworkflows
include { GROUP_READS }                 from './../subworkflows/group_reads'
include { QC_ILLUMINA }                 from './../subworkflows/qc_illumina'
include { QC_NANOPORE }                 from './../subworkflows/qc_nanopore'
include { AMR_PROFILING }               from './../subworkflows/amr_profiling'

// Default channels
samplesheet = params.input ? Channel.fromPath(file(params.input, checkIfExists:true)) : Channel.value([])

ch_multiqc_config = params.multiqc_config   ? Channel.fromPath(params.multiqc_config, checkIfExists: true).collect()    : []
ch_multiqc_logo   = params.multiqc_logo     ? Channel.fromPath(params.multiqc_logo, checkIfExists: true).collect()      : []

ch_prokka_proteins = params.prokka_proteins ? Channel.fromPath(params.prokka_proteins, checkIfExists: true).collect()   : []
ch_prokka_prodigal = params.prokka_prodigal ? Channel.fromPath(params.prokka_prodigal, checkIfExists:true ).collect()   : []

tools = params.tools ? params.tools.split(',').collect { tool -> clean_tool(tool) } : []

amrfinderdb = params.reference_base ? params.references["amrfinderdb"].db : []
kraken_db   = params.reference_base ? params.references["kraken2_db"].db : []

ch_versions     = Channel.from([])
multiqc_files   = Channel.from([])
ch_assemblies   = Channel.from([])

workflow GABI {
    main:

    INPUT_CHECK(samplesheet)

    // Divide reads up into their sequencing technologies
    INPUT_CHECK.out.reads.branch { meta, reads ->
        illumina: meta.platform == 'ILLUMINA'
        ont: meta.platform == 'NANOPORE'
        pacbio: meta.platform == 'PACBIO'
    }.set { ch_reads }

    // Trim Illumina reads
    QC_ILLUMINA(
        ch_reads.illumina
    )
    ch_illumina_trimmed = QC_ILLUMINA.out.reads
    ch_versions = ch_versions.mix(QC_ILLUMINA.out.versions)
    multiqc_files = multiqc_files.mix(QC_ILLUMINA.out.qc)

    // Trim nanopore reads
    QC_NANOPORE(
        ch_reads.ont
    )
    ch_ont_trimmed = QC_NANOPORE.out.reads
    ch_versions = ch_versions.mix(QC_NANOPORE.out.versions)
    multiqc_files = multiqc_files.mix(QC_NANOPORE.out.qc)

    // -----
    // See which samples are Illumina-only, ONT-only or have a mix of both for hybrid assembly
    // -----
    GROUP_READS(
        ch_illumina_trimmed,
        ch_ont_trimmed,
        ch_reads.pacbio
    )
    ch_hybrid_reads = GROUP_READS.out.hybrid_reads
    // Dragonflye supports mixed ONT inputs with or without illumina reads. 
    ch_dragonflye = GROUP_READS.out.dragonflye
    ch_short_reads_only = GROUP_READS.out.illumina_only

    // Unicycler - hybrid assembly
    if ('unicycler' in tools) {
        UNICYCLER(
            ch_hybrid_reads
        )
        ch_versions = ch_versions.mix(UNICYCLER.out.versions)
        ch_assemblies = ch_assemblies.mix(UNICYCLER.out.scaffolds)
    }

    // Shovill - Illumina short-read assembly
    if ('shovill' in tools) {
        SHOVILL(
            ch_short_reads_only
        )
        ch_versions = ch_versions.mix(SHOVILL.out.versions)

        //Shovill generates generic output names, must rename to sample id
        RENAME_SHOVILL_CTG(
            SHOVILL.out.contigs,
            "fasta"
        )
        ch_assemblies = ch_assemblies.mix(RENAME_SHOVILL_CTG.out)
    }

    // Flye - ONT or hybrid assembly
    if ('dragonflye' in tools) {
        DRAGONFLYE(
            ch_dragonflye
        )
        ch_versions = ch_versions.mix(DRAGONFLYE.out.versions)

        // Dragonflye generates generic output names, must rename to sample id
        RENAME_DRAGONFLYE_CTG(
            DRAGONFLYE.out.contigs,
            "fasta"
        )
        ch_assemblies = ch_assemblies.mix(RENAME_DRAGONFLYE_CTG.out)
    }

    // IPA - Pacbio HiFi assembly

    ch_assemblies.map { m,f ->
        def newMeta = [:]
        newMeta.sample_id = m.sample_id
        tuple(newMeta,f)
    }.set { ch_assemblies_clean }

    // Determine which species this assembly is from

    // BIOBLOOMTOOLS_CATEGORIZER(
    //    ch_assemblies
    //)

    //BIOBLOOMTOOLS_CATEGORIZER.out.tsv.map { m,fasta,t ->
    //    newMeta = [:]
    //    newMeta.taxon = extract_taxon(t)
    //    newMeta.sample_id = m.sample_id
    //    tuple(newMeta,fasta)
    //}.set { ch_assemblies_with_taxon}

    // ch_assemblies_with_taxon.branch { m,f ->
    //    unknown: m.taxon == "unknown"
    //    known: !m.taxon == "unknown"
    //}.set { ch_assemblies_filtered }

    // Annotate assembly using Prokka
    PROKKA(
        ch_assemblies_clean,
        ch_prokka_proteins,
        ch_prokka_prodigal
    )
    ch_versions = ch_versions.mix(PROKKA.out.versions)

    // AMR Profiling
    AMR_PROFILING(
        ch_assemblies_clean,
        amrfinderdb
    )
    ch_versions = ch_versions.mix(AMR_PROFILING.out.versions)
    amr_report  = AMR_PROFILING.out.report

    // Quality control of assembly

    // BUSCO

    // PUNKPOP

    // CGMLST


    // MLTST


    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    multiqc_files = multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml)

    MULTIQC(
        multiqc_files.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )

    emit:
    qc = MULTIQC.out.html
    }

def clean_tool(String tool) {
    return tool.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '')
}

def extract_taxon(Map meta, File file) {
    def taxon = "unknown"
    new File(file).eachLine { line ->

    }
    return taxon
}

