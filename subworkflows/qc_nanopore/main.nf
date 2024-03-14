
include { PORECHOP_PORECHOP }           from './../../modules/porechop/porechop'
include { CAT_FASTQ  }                  from './../../modules/cat_fastq'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow QC_NANOPORE {

    take:
    reads

    main:

    // Nanopore read trimming
    PORECHOP_PORECHOP(
        reads
    )
    ch_versions = ch_versions.mix(PORECHOP_PORECHOP.out.versions)

    // Merge Nanopore reads per sample
    PORECHOP_PORECHOP.out.reads.groupTuple().branch { meta, reads ->
        single: reads.size() == 1
            return [ meta, reads.flatten()]
        multi: reads.size() > 1
            return [ meta, reads.flatten()]
    }.set { ch_reads_ont }

    CAT_FASTQ(
        ch_reads_ont.multi
    )

    // The trimmed ONT reads, concatenated by sample
    ch_ont_trimmed = ch_reads_ont.single.mix(CAT_FASTQ.out.reads)

    emit:
    reads = ch_ont_trimmed
    qc = multiqc_files
    versions = ch_versions

}