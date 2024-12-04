/*
----------------------
Import Modules
----------------------
*/
include { INPUT_CHECK }                 from './../modules/input_check'
include { MULTIQC }                     from './../modules/multiqc'
include { MULTIQC as MULTIQC_ILLUMINA } from './../modules/multiqc'
include { MULTIQC as MULTIQC_NANOPORE } from './../modules/multiqc'
include { MULTIQC as MULTIQC_PACBIO }   from './../modules/multiqc'
include { SHOVILL }                     from './../modules/shovill'
include { RENAME_CTG as RENAME_SHOVILL_CTG } from './../modules/rename_ctg'
include { RENAME_CTG as RENAME_DRAGONFLYE_CTG } from './../modules/rename_ctg'
include { DRAGONFLYE }                  from './../modules/dragonflye'
include { FLYE }                        from './../modules/flye'
include { BIOBLOOM_CATEGORIZER }        from './../modules/biobloom/categorizer'
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
include { REPORT }                      from './../subworkflows/report'
include { FIND_REFERENCES }             from './../subworkflows/find_references'
include { SEROTYPING }                  from './../subworkflows/serotyping'
include { COVERAGE }                    from './../subworkflows/coverage'
include { VARIANTS }                    from './../subworkflows/variants'

/*
--------------------
Set default channels
--------------------
*/
samplesheet = params.input ? Channel.fromPath(file(params.input, checkIfExists:true)) : Channel.value([])

/*
Check that the reference directory is actually present
and only populate variables if we are actually running the main
workflow - else this will break on a fresh install 
*/
if (params.input) {
    refDir = file(params.reference_base + "/gabi/${params.reference_version}")
    if (!refDir.exists()) {
        log.info 'The required reference directory was not found on your system, exiting!'
        System.exit(1)
    }

    ch_multiqc_config = params.multiqc_config   ? Channel.fromPath(params.multiqc_config, checkIfExists: true).collect()    : []
    ch_multiqc_logo   = params.multiqc_logo     ? Channel.fromPath(params.multiqc_logo, checkIfExists: true).collect()      : []

    ch_report_template = params.template        ? Channel.fromPath(params.template, checkIfExists: true).collect()          : []
    ch_report_refs     = params.report_refs     ? Channel.fromPath(params.report_refs, checkIfExists: true).collect()          : []

    ch_prokka_proteins = params.prokka_proteins ? Channel.fromPath(params.prokka_proteins, checkIfExists: true).collect()   : []
    ch_prokka_prodigal = params.prokka_prodigal ? Channel.fromPath(params.prokka_prodigal, checkIfExists:true).collect()    : []

    amrfinder_db    = params.reference_base ? file(params.references['amrfinderdb'].db, checkIfExists:true)   : []
    kraken2_db      = params.reference_base ? file(params.references['kraken2'].db, checkIfExists:true)       : []

    sourmashdb      = params.reference_base ? file(params.references['sourmashdb'].db, checkIfExists:true)    : []

    busco_db_path   = params.reference_base ? file(params.references['busco'].db, checkIfExists:true)         : []
    busco_lineage   = params.busco_lineage

    confindr_db     = params.confindr_db ? params.confindr_db : file(params.references['confindr'].db, checkIfExists: true)

    ch_bloom_filter = params.reference_base ? Channel.from([ file(params.references["host_genome"].db + ".bf", checkIfExists: true), file(params.references["host_genome"].db + ".txt", checkIfExists: true)]).collect() : []

}

ch_versions     = Channel.from([])
multiqc_files   = Channel.from([])
ch_assemblies   = Channel.from([])
ch_report       = Channel.from([])
ch_multiqc_illumina = Channel.from([])
ch_multiqc_nanopore = Channel.from([])
ch_multiqc_pacbio   = Channel.from([])

workflow GABI {
    main:

    INPUT_CHECK(samplesheet)

    // If we pass existing assemblies instead of raw reads:
    ch_assemblies = ch_assemblies.mix(INPUT_CHECK.out.assemblies)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Run read trimming and contamination check(s)
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
    multiqc_files       = multiqc_files.mix(QC.out.qc)
    ch_report           = ch_report.mix(QC.out.confindr_reports)

    ch_multiqc_illumina = ch_multiqc_illumina.mix(QC.out.qc_illumina)
    ch_multiqc_nanopore = ch_multiqc_nanopore.mix(QC.out.qc_nanopore)
    ch_multiqc_pacbio   = ch_multiqc_pacbio.mix(QC.out.qc_pacbio)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Clean reads against a bloom filter to remove any
    potential host contaminations - currently: horse, from
    blood medium used during growth of campylobacter
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    if (params.remove_host) {
        BIOBLOOM_CATEGORIZER(
            ch_illumina_trimmed,
            ch_bloom_filter
        )
        ch_illumina_clean = BIOBLOOM_CATEGORIZER.out.reads
        ch_versions = ch_versions.mix(BIOBLOOM_CATEGORIZER.out.versions)
    } else {
        ch_illumina_clean = ch_illumina_trimmed
    }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: See which samples are Illumina-only, ONT-only, Pacbio-only
    or have a mix of both for hybrid assembly
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    GROUP_READS(
        ch_illumina_clean,
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
    SUB: Predict taxonomy from read data
    One set of reads per sample, preferrably Illumina
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ch_reads_for_taxonomy = ch_hybrid_reads.map { m, i, n -> [m, i ] }
    ch_reads_for_taxonomy = ch_reads_for_taxonomy.mix(ch_short_reads_only, ch_ont_reads_only, ch_pb_reads_only)

    TAXONOMY_PROFILING(
        ch_reads_for_taxonomy,
        kraken2_db
    )
    ch_taxon        = TAXONOMY_PROFILING.out.report
    ch_versions     = ch_versions.mix(TAXONOMY_PROFILING.out.versions)
    ch_report       = ch_report.mix(TAXONOMY_PROFILING.out.report)
    multiqc_files   = multiqc_files.mix(TAXONOMY_PROFILING.out.report.map { m, r -> r })

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Assemble reads based on what data is available
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
    ch_versions     = ch_versions.mix(DRAGONFLYE.out.versions)
    ch_assemblies   = ch_assemblies.mix(DRAGONFLYE.out.contigs)

    /*
    Option: Pacbio HiFi reads
    Flye
    */
    FLYE(
        ch_pb_reads_only
    )
    ch_versions     = ch_versions.mix(FLYE.out.versions)
    ch_assemblies   = ch_assemblies.mix(FLYE.out.fasta)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Tag and optionally remove highly fragmented assemblies
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ch_assemblies.branch { m, f ->
        fail: f.countFasta() > params.max_contigs
        pass: f.countFasta() <= params.max_contigs
    }.set { ch_assemblies_status }

    ch_assemblies_status.fail.subscribe { m, f ->
        log.warn "${m.sample_id} - assembly is highly fragmented!"
    }

    if (params.skip_failed) {
        ch_assemblies_filtered = ch_assemblies_status.pass
    } else {
        ch_assemblies_filtered = ch_assemblies
    }
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Clean the meta data object to remove stuff we don't need anymore
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ch_assemblies_filtered.map { m, f ->
        def newMeta = [:]
        newMeta.sample_id = m.sample_id
        tuple(newMeta, f)
    }.set { ch_assemblies_clean }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Calculate coverage against assembled genome
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    COVERAGE(
        ch_assemblies_clean,
        ch_illumina_trimmed,
        ch_ont_trimmed,
        ch_pacbio_trimmed
    )
    ch_versions   = ch_versions.mix(COVERAGE.out.versions)
    ch_multiqc_illumina = ch_multiqc_illumina.mix(
        COVERAGE.out.report.filter { m,r -> 
            m.platform == "ILLUMINA"
        }.map { m,r -> r}
    )
    ch_multiqc_nanopore = ch_multiqc_nanopore.mix(
        COVERAGE.out.report.filter { m,r ->
            m.platform == "NANOPORE"
        }.map { m,r -> r }
    )
    ch_multiqc_pacbio = ch_multiqc_pacbio.mix(
        COVERAGE.out.report.filter { m,r ->
            m.platform == "PACBIO"
        }.map { m,r -> r }
    )
    multiqc_files = multiqc_files.mix(
        COVERAGE.out.report.filter { m,r ->
            m.platform == "ALL"
        }.map { m,r -> r }
    )
    ch_report = ch_report.mix(COVERAGE.out.summary)

    ch_report = ch_report.mix(
        COVERAGE.out.summary.filter {m,r ->
            m.platform != "ALL"
        }
    )

    ch_report = ch_report.mix(COVERAGE.out.bam_stats)
    
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Identify and analyse plasmids from draft assemblies
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    PLASMIDS(
        ch_assemblies_clean
    )
    ch_versions = ch_versions.mix(PLASMIDS.out.versions)
    ch_assembly_without_plasmids = PLASMIDS.out.chromosome

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Map Illumina reads to chromosome assembly to check 
    for polymorphic positions as indication of read or assembly
    errors
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    
    VARIANTS(
        ch_illumina_trimmed.map { m,r ->
            tuple(m.sample_id,m,r)
        }.join(
            ch_assembly_without_plasmids.map { m,a ->
                tuple(m.sample_id,a)
            }
        ).map { s,m,r,a ->
            tuple(m,r,a)
        }
    )
    ch_versions     = ch_versions.mix(VARIANTS.out.versions)
    multiqc_files   = multiqc_files.mix(VARIANTS.out.qc)
    ch_report       = ch_report.mix(VARIANTS.out.stats)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Find the appropriate reference genome+annotation for each assembly
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    FIND_REFERENCES(
        ch_assembly_without_plasmids,
        sourmashdb
    )
    ch_versions     = ch_versions.mix(FIND_REFERENCES.out.versions)
    ch_report       = ch_report.mix(FIND_REFERENCES.out.gbk)

    /*
    Combine the assembly with the best reference genome and annotation
    Here we use only the chromosomal assembly, since Plasmids may skew the metrics
    */
    ch_assembly_without_plasmids.map { m, s ->
        tuple(m.sample_id, s)
    }.join(
        FIND_REFERENCES.out.reference.map { m, r, g, k ->
            tuple(m.sample_id, m, r, g, k)
        }
    ).map { i,s, m, r, g, k ->
        tuple(m, s, r, g, k)
    }.set { ch_assemblies_with_reference_and_gbk }

    // and we create a channel with taxon-enriched metadata and assembly for other analyses
    ch_assemblies_with_reference_and_gbk.map { m,s, r, g, k ->
        tuple(m,s)
    }.set { ch_assemblies_without_plasmids_with_taxa }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Perform serotyping of assemblies
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    SEROTYPING(
        ch_assemblies_without_plasmids_with_taxa
    )
    ch_versions     = ch_versions.mix(SEROTYPING.out.versions)
    ch_report       = ch_report.mix(SEROTYPING.out.reports)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Perform MLST typing of assemblies
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    if (!params.skip_mlst) {
        MLST_TYPING(
            ch_assemblies_without_plasmids_with_taxa
        )
        ch_mlst = MLST_TYPING.out.report
        ch_versions = ch_versions.mix(MLST_TYPING.out.versions)
        ch_report = ch_report.mix(MLST_TYPING.out.report)
    }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Predict gene models
    We use taxonomy-enriched meta hashes to add
    genus/species to the Prokka output(s)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ANNOTATE(
        ch_assemblies_without_plasmids_with_taxa,
        ch_prokka_proteins,
        ch_prokka_prodigal
    )
    ch_versions = ch_versions.mix(ANNOTATE.out.versions)
    fna = ANNOTATE.out.fna
    faa = ANNOTATE.out.faa
    gff = ANNOTATE.out.gff
    multiqc_files = multiqc_files.mix(ANNOTATE.out.qc.map { m, r -> r })

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Identify antimocrobial resistance genes
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    if (!params.skip_amr) {
        AMR_PROFILING(
            ch_assemblies_clean,
            amrfinder_db
        )
        ch_versions = ch_versions.mix(AMR_PROFILING.out.versions)
        ch_report   = ch_report.mix(AMR_PROFILING.out.amrfinder_report)
    }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Gauge quality of the assembly
    This does not include the plasmids. 
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    ASSEMBLY_QC(
        ch_assemblies_with_reference_and_gbk,
        busco_lineage,
        busco_db_path
    )
    ch_versions     = ch_versions.mix(ASSEMBLY_QC.out.versions)
    ch_assembly_qc  = ASSEMBLY_QC.out.quast
    multiqc_files   = multiqc_files.mix(ASSEMBLY_QC.out.qc.map { m, r -> r })
    ch_report       = ch_report.mix(ch_assembly_qc)
    ch_report       = ch_report.mix(ASSEMBLY_QC.out.busco_json)

    /*
    Gather all version information
    */

    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUB: Make summary report
    This is optonal in case of unforseen
    issues.
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    if (!params.skip_report) {
        // standardize the meta hash to enable downstream grouping
        ch_report.map { m, r ->
            def meta = [:]
            meta.sample_id = m.sample_id
            tuple(meta, r)
        }.groupTuple().map { meta,r ->
            tuple(meta.sample_id,r)
        }.join(
            FIND_REFERENCES.out.taxon.map { m ->
                tuple(m.sample_id,m)
            }
        ).map { sid,r,meta ->
            tuple (meta,r)
        }.set { ch_reports_grouped }

        REPORT(
            ch_reports_grouped,
            ch_report_template,
            ch_report_refs,
            CUSTOM_DUMPSOFTWAREVERSIONS.out.yml
        )
    }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Generate QC reports
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    multiqc_files = multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml)

    MULTIQC(
        multiqc_files.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Platform-specific MultiQC reports
    since different technologies are difficult to
    display jointly (scale etc)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    MULTIQC_ILLUMINA(
        ch_multiqc_illumina.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )
    MULTIQC_NANOPORE(
        ch_multiqc_nanopore.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )
    MULTIQC_PACBIO(
        ch_multiqc_pacbio.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )

    emit:
    qc = MULTIQC.out.report
}
