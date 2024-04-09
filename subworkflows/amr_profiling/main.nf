/*
Include Modules
*/
include { AMRFINDERPLUS_RUN }               from './../../modules/amrfinderplus/run'
include { AMRFINDERPLUS_UPDATE }            from './../../modules/amrfinderplus/update'
include { HAMRONIZATION_AMRFINDERPLUS }     from './../../modules/hamronization/amrfinderplus'
include { HAMRONIZATION_ABRICATE }          from './../../modules/hamronization/abricate'
include { HAMRONIZATION_SUMMARIZE }         from './../../modules/hamronization/summarize'
include { ABRICATE_RUN }                    from './../../modules/abricate/run'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])
ch_hamronization_input = Channel.from([])

workflow AMR_PROFILING {
    take:
    assembly
    db

    main:

    /*
    Run AMRFinderPlus and make JSON report
    */

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

    HAMRONIZATION_AMRFINDERPLUS(
        AMRFINDERPLUS_RUN.out.report,
        'json',
        AMRFINDERPLUS_RUN.out.tool_version,
        AMRFINDERPLUS_RUN.out.db_version
    )
    ch_hamronization_input = ch_hamronization_input.mix(HAMRONIZATION_AMRFINDERPLUS.out.json)
    ch_versions = HAMRONIZATION_AMRFINDERPLUS.out.versions

    /*
    Run Abricate and make JSON report
    */
    ABRICATE_RUN(
        assembly
    )
    ch_versions = ch_versions.mix(ABRICATE_RUN.out.versions)

    HAMRONIZATION_ABRICATE(
        ABRICATE_RUN.out.report,
        'json',
        '1.0.1',
        '2021-Mar-27'
    )
    ch_versions = ch_versions.mix(HAMRONIZATION_ABRICATE.out.versions)
    ch_hamronization_input = ch_hamronization_input.mix(HAMRONIZATION_ABRICATE.out.json)

    /*
    Summarize reports across tools
    */
    HAMRONIZATION_SUMMARIZE(
        ch_hamronization_input.map { m, j -> j }.collect(),
        params.arg_hamronization_summarizeformat
    )
    ch_versions = ch_versions.mix(HAMRONIZATION_SUMMARIZE.out.versions)

    emit:
    report = HAMRONIZATION_SUMMARIZE.out.json
    versions = ch_versions
    qc = multiqc_files
}
