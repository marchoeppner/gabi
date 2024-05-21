
include { GABI_SUMMARY }    from './../../modules/helper/gabi_summary'

ch_versions = Channel.from([])

workflow REPORT {
    take:
    reports

    main:

    GABI_SUMMARY(
        reports
    )
    ch_versions = ch_versions.mix(GABI_SUMMARY.out.versions)

    emit:
    json = GABI_SUMMARY.out.json
    versions = ch_versions
}
