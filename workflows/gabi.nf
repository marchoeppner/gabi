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
include { TAXONOMY_PROFILING }          from './../subworkflows/taxonomy_profiling'
include { ASSEMBLY_QC }                 from './../subworkflows/assembly_qc'

// Default channels
samplesheet = params.input ? Channel.fromPath(file(params.input, checkIfExists:true)) : Channel.value([])

ch_multiqc_config = params.multiqc_config   ? Channel.fromPath(params.multiqc_config, checkIfExists: true).collect()    : []
ch_multiqc_logo   = params.multiqc_logo     ? Channel.fromPath(params.multiqc_logo, checkIfExists: true).collect()      : []

ch_prokka_proteins = params.prokka_proteins ? Channel.fromPath(params.prokka_proteins, checkIfExists: true).collect()   : []
ch_prokka_prodigal = params.prokka_prodigal ? Channel.fromPath(params.prokka_prodigal, checkIfExists:true ).collect()   : []

tools = params.tools ? params.tools.split(',').collect { tool -> clean_tool(tool) } : []

amrfinder_db    = params.reference_base ? params.references["amrfinderdb"].db : []
kraken2_db      = params.reference_base ? params.references["kraken2"].db : []

busco_db_path   = params.reference_base ? params.references["busco"].db : []
busco_lineage   = params.busco_lineage

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

    // Taxonomy
    TAXONOMY_PROFILING(
        ch_ont_trimmed.mix(ch_illumina_trimmed),
        kraken2_db
    )
    ch_taxon = TAXONOMY_PROFILING.out.report

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

    PROKKA(
        ch_assemblies_clean,
        ch_prokka_proteins,
        ch_prokka_prodigal
    )
    ch_versions = ch_versions.mix(PROKKA.out.versions)
    faa = PROKKA.out.faa
    gff = PROKKA.out.gff

    // Create a channel with joint proteins and gff files for AMRfinderplus
    faa.join(gff).map { m,f,g ->
        m.is_proteins = true
        tuple(m,f,g)
    }.set { ch_amr_input }

    // AMR Profiling
    AMR_PROFILING(
        ch_amr_input,
        amrfinder_db
    )
    ch_versions = ch_versions.mix(AMR_PROFILING.out.versions)
    amr_report  = AMR_PROFILING.out.report

    // Quality control of assembly

    // BUSCO
    ASSEMBLY_QC(
        ch_assemblies_clean,
        busco_lineage,
        busco_db_path
    )
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)
    multiqc_files = multiqc_files.mix(ASSEMBLY_QC.out.report.map {m,r -> r})

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



