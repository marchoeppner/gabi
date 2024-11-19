include { MASH_SKETCH }     from './../../modules/mash/sketch'
include { MASH_DIST }       from './../../modules/mash/dist'
include { SOURMASH_SKETCH } from './../../modules/sourmash/sketch'
include { SOURMASH_SEARCH } from './../../modules/sourmash/search'
include { DOWNLOAD_GENOME } from './../../modules/helper/download_genome'

ch_versions = Channel.from([])

workflow FIND_REFERENCES {
    take:
    assembly
    mashdb
    sourmashdb

    main:

    if (params.sourmash)  {

        // sketch the assembly
        SOURMASH_SKETCH(
            assembly
        )
        ch_versions = ch_versions.mix(SOURMASH_SKETCH.out.versions)

        // search sketch against db
        SOURMASH_SEARCH(
            SOURMASH_SKETCH.out.signature,
            sourmashdb
        )
        ch_versions = ch_versions.mix(SOURMASH_SEARCH.out.versions)

        SOURMASH_SEARCH.out.csv.map { m,c ->
            gbk = sourmash_get_acc(c)
            m.gbk = gbk
            tuple(m,c)
        }.set { mash_with_gbk}

    } else {
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
    }
    
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

    meta_with_genbank = meta_with_sequence.map{m,s,a,k -> [m,k]}

    emit:
    gbk = meta_with_genbank
    reference = meta_with_sequence
    versions = ch_versions
    }

// Crude method to get the best hit from the mash list
// Basically we take the top hit as the best and only match
// TODO: Improve this to perhaps look at multiple equally good matches
// and find th least fragmented one - will require touching the actual assemblies and
// counting contigs or similar
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

def sourmash_get_acc(csv) {
    gbk = ''
    lines = file(csv).readLines()
    if (lines.size() > 1 ) {
        def elements = lines[1].trim().split(",")
        gbk_file = elements[3].split(" ")[0]
        if (gbk_file.contains('GCF_')) {
            gbk = gbk_file.replace('"','')
        }
    }

    return gbk
}