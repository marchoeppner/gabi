include { BUSCO_BUSCO }         from './../../modules/busco/busco'
include { BUSCO_DOWNLOAD }      from './../../modules/busco/download'

ch_versions = Channel.from([])

workflow ASSEMBLY_QC {

    take:
    assembly
    busco_lineage
    busco_db_path

    main:

    if (!busco_db_path) {
        BUSCO_DOWNLOAD(
            busco_lineage
        )
        busco_db_path = BUSCO_DOWNLOAD.out.db
    }
    BUSCO_BUSCO(
        assembly,
        busco_lineage,
        busco_db_path
    )
    ch_versions = ch_versions.mix(BUSCO_BUSCO.out.versions)

    emit:
    report = BUSCO_BUSCO.out.summary
    versions = ch_versions
}