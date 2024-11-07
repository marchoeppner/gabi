include { BUSCO_BUSCO }         from './../../modules/busco/busco'
include { BUSCO_DOWNLOAD }      from './../../modules/busco/download'
include { QUAST }               from './../../modules/quast'
include { MUMMER2CIRCOS }       from './../../modules/mummer2circos'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow ASSEMBLY_QC {
    take:
    assembly        // [ meta, assembly, reference_fa, reference_gff, reference_gbk ]
    busco_lineage   // lineage
    busco_db_path   // db_path

    main:

    /*
    Generate a circos plot against
    the designated reference genome
    Currently, assemblies with more than 200 contigs are not supported!
    */

    assembly.branch { m, s, r, g, k ->
        pass: s.countFasta() < 200 && r.countFasta() < 200
        fail: s.countFasta() >= 200 || r.countFasta() >= 200
    }.set { assembly_by_completeness }

   
    if (!params.skip_circos) {

        assembly_by_completeness.fail.subscribe { m, s, r, g, k ->
            log.warn "${m.sample_id} - skipping circos plot, assembly or reference too fragmented!"
        }
        MUMMER2CIRCOS(
            assembly_by_completeness.pass
        )
        ch_versions = ch_versions.mix(MUMMER2CIRCOS.out.versions)
    }

    /*
    Assembly quality using Quast
    */
    QUAST(
        assembly.map {  m, s, r, g, k -> tuple(m, s, r, g) }
    )
    ch_versions = ch_versions.mix(QUAST.out.versions)
    multiqc_files = multiqc_files.mix(QUAST.out.tsv)

    /*
    Gauging assembly completeness using
    Busco
    */
    if (!busco_db_path) {
        BUSCO_DOWNLOAD(
            busco_lineage
        )
        busco_db_path = BUSCO_DOWNLOAD.out.db
    }

    assembly.map { m, s, r, g, k -> tuple(m, s) }.set { ch_assembly_clean }
    BUSCO_BUSCO(
        ch_assembly_clean,
        busco_lineage,
        busco_db_path
    )
    ch_versions = ch_versions.mix(BUSCO_BUSCO.out.versions)
    multiqc_files = multiqc_files.mix(BUSCO_BUSCO.out.summary)

    emit:
    qc = multiqc_files
    quast = QUAST.out.tsv
    busco_json = BUSCO_BUSCO.out.json
    report = BUSCO_BUSCO.out.summary
    versions = ch_versions
    }
