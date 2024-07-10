include { BUSCO_BUSCO }         from './../../modules/busco/busco'
include { BUSCO_DOWNLOAD }      from './../../modules/busco/download'
include { QUAST }               from './../../modules/quast'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow ASSEMBLY_QC {
    take:
    assembly
    busco_lineage
    busco_db_path

    main:

    QUAST(
        assembly
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

    assembly.map { m,s,r,g -> tuple(m,s) }.set { ch_assembly_clean }
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
    report = BUSCO_BUSCO.out.summary
    versions = ch_versions
    }
