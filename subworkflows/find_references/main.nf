include { MASH_SKETCH }     from './../../modules/mash/sketch'
include { MASH_DIST }       from './../../modules/mash/dist'
include { DOWNLOAD_GENOME } from './../../modules/helper/download_genome'

ch_versions = Channel.from([])

workflow FIND_REFERENCES {
    take:
    assembly
    mashdb

    main:

    // Produce a mash sketch from the assembly
    MASH_SKETCH(
        assembly
    )
    ch_versions = ch_versions.mix(MASH_SKETCH.out.versions)

    // Find hits against RefSeq database
    MASH_DIST(
        MASH_SKETCH.out.mash,
        mashdb
    )
    ch_versions = ch_versions.mix(MASH_DIST.out.versions)

    // Get a unique list of best reference genomes
    MASH_DIST.out.dist.map { m, r ->
        gbk = mash_get_best(r)
        m.gbk = gbk
        tuple(m, r)
    }.set { mash_with_gbk }

    mash_with_gbk.map { m, r ->
        m.gbk
    }.unique()
    .set { genome_accessions }

    // Download the best reference genome
    DOWNLOAD_GENOME(
        genome_accessions
    )
    ch_versions = ch_versions.mix(DOWNLOAD_GENOME.out.versions)

    ch_genome_with_gff = DOWNLOAD_GENOME.out.sequence.join(DOWNLOAD_GENOME.out.gff).join(DOWNLOAD_GENOME.out.genbank)

    /*
    We use combine here because several assemblies may
    map to the same reference genome
    */
    mash_with_gbk.map { m, r ->
        tuple(gbk, m, r)
    }.combine(
        ch_genome_with_gff, by: 0
    ).map { g, m, r, s, a, k ->
        def meta = [:]
        meta.sample_id = m.sample_id
        meta.taxon = m.taxon
        meta.domain = m.domain
        meta.db_name = m.db_name
        tuple(meta, s, a, k)
    }.set { meta_with_sequence }

    emit:
    reference = meta_with_sequence
    versions = ch_versions
    }

// Crude method to get the best hit from the mash list
def mash_get_best(report) {
    gbk = ''
    lines = file(report).readLines()
    if (lines.size() > 0 ) {
        def elements = lines[0].trim().split(/\s+/)
        gbk_file = elements[0]
        if (gbk_file.contains('GCF_')) {
            gbk = gbk_file.split('_')[0..1].join('_')
        }
    }

    return gbk
}
