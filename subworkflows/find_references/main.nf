include { MASH_SKETCH }     from './../../modules/mash/sketch'
include { MASH_DIST }       from './../../modules/mash/dist'
include { DOWNLOAD_GENOME } from './../../modules/helper/download_genome'

ch_versions = Channel.from([])

workflow FIND_REFERENCES {
    take:
    assembly
    mashdb

    main:

    MASH_SKETCH(
        assembly
    )
    ch_versions = ch_versions.mix(MASH_SKETCH.out.versions)

    MASH_DIST(
        MASH_SKETCH.out.mash,
        mashdb
    )
    ch_versions = ch_versions.mix(MASH_DIST.out.versions)

    MASH_DIST.out.dist.map { m,r ->
        gbk = mash_get_best(r)
        m.gbk = gbk
        tuple(m,r)
    }.set { mash_with_gbk}

    mash_with_gbk.map { m,r ->
        m.gbk
    }.unique()
    .set { genome_accessions }

    DOWNLOAD_GENOME(
        genome_accessions
    )
    ch_versions = ch_versions.mix(DOWNLOAD_GENOME.out.versions)

    mash_with_gbk.map { m,r ->
        tuple(gbk,m,r)
    }.join(
        DOWNLOAD_GENOME.out.sequence
    ).map { g,m,r,s ->
        tuple(m,s)
    }.set { meta_with_sequence }

    meta_with_sequence.view()

    emit:
    versions = ch_versions
}

def mash_get_best(report) {
    gbk = ""
    lines = file(report).readLines()
    if (lines.size() > 0 ) {
        def elements = lines[0].trim().split(/\s+/)
        gbk_file = elements[0]
        if (gbk_file.contains("GCF_")) {
            gbk = gbk_file.split("_")[0..1].join("_")
        }
    }
   
    return gbk
}