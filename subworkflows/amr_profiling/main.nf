include { AMRFINDERPLUS_RUN }       from './../../modules/amrfinderplus/run'
include { AMRFINDERPLUS_UPDATE }    from './../../modules/amrfinderplus/update'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow AMR_PROFILING {
    take:
    assembly
    db

    main:

    // if no local DB is defined, we download it on the flye
    if (!params.reference_base) {
        AMRFINDERPLUS_UPDATE()
        ch_amrfinderplus_db = AMRFINDERPLUS_UPDATE.out.db
        ch_versions = ch_versions.mix(AMRFINDERPLUS_UPDATE.out.versions)
    } else {
        ch_amrfinderplus_db = Channel.from(db)
    }

    AMRFINDERPLUS_RUN(
        assembly,
        ch_amrfinderplus_db.collect()
    )
    ch_versions = ch_versions.mix(AMRFINDERPLUS_RUN.out.versions)
    amrfinder_report = AMRFINDERPLUS_RUN.out.report

    emit:
    report = amrfinder_report
    versions = ch_versions
    qc = multiqc_files
}
