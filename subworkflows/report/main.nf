
include { GABI_SUMMARY }    from './../../modules/helper/gabi_summary'
include { GABI_REPORT }     from './../../modules/helper/gabi_report'

ch_versions = Channel.from([])

workflow REPORT {
    take:
    reports
    template
    refs
    yml

    main:

    GABI_SUMMARY(
        reports
    )
    ch_versions = ch_versions.mix(GABI_SUMMARY.out.versions)

    GABI_REPORT(
        GABI_SUMMARY.out.json.collect(),
        template,
        refs,
        yml
    )
    ch_versions = ch_versions.mix(GABI_REPORT.out.versions)

    emit:
    html = GABI_REPORT.out.html
    json = GABI_SUMMARY.out.json
    versions = ch_versions
}
