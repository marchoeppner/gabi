/*
----------------------
Import Modules
----------------------
*/
include { INPUT_CHECK }                 from './../modules/input_check'
include { MULTIQC }                     from './../modules/multiqc'
include { MULTIQC as MULTIQC_ILLUMINA}  from './../modules/multiqc'
include { MULTIQC as MULTIQC_NANOPORE}  from './../modules/multiqc'
include { MULTIQC as MULTIQC_PACBIO}    from './../modules/multiqc'
include { SHOVILL }                     from './../modules/shovill'
include { RENAME_CTG as RENAME_SHOVILL_CTG } from './../modules/rename_ctg'
include { RENAME_CTG as RENAME_DRAGONFLYE_CTG } from './../modules/rename_ctg'
include { DRAGONFLYE }                  from './../modules/dragonflye'
include { FLYE }                        from './../modules/flye'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './../modules/custom/dumpsoftwareversions'

/*
-------------------
Import Subworkflows
-------------------
*/
include { GROUP_READS }                 from './../subworkflows/group_reads'
include { QC }                          from './../subworkflows/qc'
include { AMR_PROFILING }               from './../subworkflows/amr_profiling'
include { TAXONOMY_PROFILING }          from './../subworkflows/taxonomy_profiling'
include { ASSEMBLY_QC }                 from './../subworkflows/assembly_qc'
include { PLASMIDS }                    from './../subworkflows/plasmids'
include { ANNOTATE }                    from './../subworkflows/annotate'
include { MLST_TYPING }                 from './../subworkflows/mlst'

/*
--------------------
Set default channels
--------------------
*/
samplesheet = params.input ? Channel.fromPath(file(params.input, checkIfExists:true)) : Channel.value([])

ch_multiqc_config = params.multiqc_config   ? Channel.fromPath(params.multiqc_config, checkIfExists: true).collect()    : []
ch_multiqc_logo   = params.multiqc_logo     ? Channel.fromPath(params.multiqc_logo, checkIfExists: true).collect()      : []

ch_prokka_proteins = params.prokka_proteins ? Channel.fromPath(params.prokka_proteins, checkIfExists: true).collect()   : []
ch_prokka_prodigal = params.prokka_prodigal ? Channel.fromPath(params.prokka_prodigal, checkIfExists:true).collect()   : []

tools = params.tools ? params.tools.split(',').collect { tool -> clean_tool(tool) } : []

amrfinder_db    = params.reference_base ? params.references['amrfinderdb'].db : []
kraken2_db      = params.reference_base ? params.references['kraken2'].db : []

busco_db_path   = params.reference_base ? params.references['busco'].db : []
busco_lineage   = params.busco_lineage

confindr_db     = params.reference_base ? Channel.fromPath(params.references['confindr'].db).collect() : []

ch_versions     = Channel.from([])
multiqc_files   = Channel.from([])
ch_assemblies   = Channel.from([])

workflow GABI {
    main:

    INPUT_CHECK(samplesheet)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Run read trimming and contamination check(s)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    QC(
        INPUT_CHECK.out.reads,
        confindr_db
    )
    ch_versions         = ch_versions.mix(QC.out.versions)

    ch_illumina_trimmed = QC.out.illumina
    ch_ont_trimmed      = QC.out.ont
    ch_pacbio_trimmed   = QC.out.pacbio

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Platform specific MultiQC reports
    since different technologies are difficult to 
    display jointly (scale etc)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    MULTIQC_ILLUMINA(
        QC.out.qc_illumina.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )
    MULTIQC_NANOPORE(
        QC.out.qc_nanopore.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )
    MULTIQC_PACBIO(
        QC.out.qc_pacbio.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    See which samples are Illumina-only, ONT-only, Pacbio-only
    or have a mix of both for hybrid assembly
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    GROUP_READS(
        ch_illumina_trimmed,
        ch_ont_trimmed,
        ch_pacbio_trimmed
    )
    ch_hybrid_reads     = GROUP_READS.out.hybrid_reads
    ch_dragonflye       = GROUP_READS.out.dragonflye
    ch_short_reads_only = GROUP_READS.out.illumina_only
    ch_ont_reads_only   = GROUP_READS.out.ont_only
    ch_pb_reads_only    = GROUP_READS.out.pacbio_only

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Predict taxonomy from read data
    One set of reads per sample, preferrably Illumina
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ch_reads_for_taxonomy = ch_hybrid_reads.map { m, i, n -> [m, i ] }
    ch_reads_for_taxonomy = ch_reads_for_taxonomy.mix(ch_short_reads_only, ch_ont_reads_only, ch_pb_reads_only)

    TAXONOMY_PROFILING(
        ch_reads_for_taxonomy,
        kraken2_db
    )
    ch_taxon = TAXONOMY_PROFILING.out.report
    ch_versions = ch_versions.mix(TAXONOMY_PROFILING.out.versions)
    //multiqc_files = multiqc_files.mix(TAXONOMY_PROFILING.out.report.map { m, r -> r })

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Assemble reads based on what data is available
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    /*
    Option: Short reads only
    Shovill
    */
    SHOVILL(
        ch_short_reads_only
    )
    ch_versions = ch_versions.mix(SHOVILL.out.versions)

    //Shovill generates generic output names, must rename to sample id
    RENAME_SHOVILL_CTG(
        SHOVILL.out.contigs,
        'fasta'
    )
    ch_assemblies = ch_assemblies.mix(RENAME_SHOVILL_CTG.out)

    /*
    Option: Nanopore reads with optional short reads
    Dragonflye
    */
    DRAGONFLYE(
        ch_dragonflye
    )
    ch_versions = ch_versions.mix(DRAGONFLYE.out.versions)
    ch_assemblies = ch_assemblies.mix(DRAGONFLYE.out.contigs)

    /*
    Option: Pacbio HiFi reads
    Flye
    */
    FLYE(
        ch_pb_reads_only
    )
    ch_versions = ch_versions.mix(FLYE.out.versions)
    ch_assemblies = ch_assemblies.mix(FLYE.out.fasta)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Clean the meta data object to remove stuff we don't need anymore
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ch_assemblies.map { m, f ->
        def newMeta = [:]
        newMeta.sample_id = m.sample_id
        tuple(newMeta, f)
    }.set { ch_assemblies_clean }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Identify and analyse plasmids from draft assemblies
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    PLASMIDS(
        ch_assemblies_clean
    )
    ch_versions = ch_versions.mix(PLASMIDS.out.versions)

    /*
    Join the assembly channel with taxonomic assignment information
    [ meta, assembly ] <-> [ meta, taxreport]
    */
    ch_assemblies_clean_grouped = ch_assemblies_clean.map { m, f -> [ m.sample_id, m, f] }
    ch_assemblies_clean_grouped_tax = ch_assemblies_clean_grouped.join(ch_taxon.map { m, t -> [ m.sample_id, m] })
    ch_assemblies_clean_grouped_tax.map { s, m, f, t ->
        m.taxon = t.taxon
        m.domain = t.domain
        tuple(m, f)
    }.set { ch_assemblies_with_taxa }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Perform MLST typing of assemblies
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    MLST_TYPING(
        ch_assemblies_with_taxa
    )
    ch_versions = ch_versions.mix(MLST_TYPING.out.versions)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Predict gene models
    We use taxonomy-enriched meta hashes to add
    genus/species to the Prokka output(s)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ANNOTATE(
        ch_assemblies_with_taxa,
        ch_prokka_proteins,
        ch_prokka_prodigal
    )
    ch_versions = ch_versions.mix(ANNOTATE.out.versions)
    faa = ANNOTATE.out.faa
    gff = ANNOTATE.out.gff

    // Create a channel with joint proteins and gff files for AMRfinderplus
    faa.join(gff).map { m, f, g ->
        m.is_proteins = true
        tuple(m, f, g)
    }.set { ch_amr_input }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Identify antimocrobial resistance genes
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    AMR_PROFILING(
        ch_amr_input,
        amrfinder_db
    )
    ch_versions = ch_versions.mix(AMR_PROFILING.out.versions)
    amr_report  = AMR_PROFILING.out.report

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Gauge quality of the assembly
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ASSEMBLY_QC(
        ch_assemblies_with_taxa,
        busco_lineage,
        busco_db_path
    )
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)
    multiqc_files = multiqc_files.mix(ASSEMBLY_QC.out.qc.map { m, r -> r })

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Generate QC reports 
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

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
    qc = MULTIQC.out.report
    }

def clean_tool(String tool) {
    return tool.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '')
}
