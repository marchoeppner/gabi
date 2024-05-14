include { BBMAP_SENDSKETCH }        from './../../modules/bbmap/sendsketch'
include { FILTER_SKETCHES }         from './../../modules/helper/filter_sketches'
include { DOWNLOAD_REFERENCES }     from './../../modules/helper/download_references'

ch_versions = Channel.from([])

workflow FIND_REFERENCES {
    take:
    assembly

    main:

    BBMAP_SENDSKETCH(
        assembly
    )
    ch_versions = ch_versions.mix(BBMAP_SENDSKETCH.out.versions)

    FILTER_SKETCHES(
        BBMAP_SENDSKETCH.out.hits
    )
    ch_versions = ch_versions.mix(FILTER_SKETCHES.out.versions)

    FILTER_SKETCHES.out.txt.view()

    FILTER_SKETCHES.out.txt
    .map { m, t -> t }
    .splitText()
    .map { it.replace('\n', '') }
    .collect()
    .toSortedList()
    .flatten()
    .unique()
    .set { ch_taxa }

    ch_taxa.view()

    DOWNLOAD_REFERENCES(
        ch_taxa
    )

    emit:
    taxa = ch_taxa
    versions = ch_versions
}
