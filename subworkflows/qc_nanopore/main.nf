
include { PORECHOP_ABI }                    from './../../modules/porechop/abi'
include { RASUSA }                          from './../../modules/rasusa'
include { CAT_FASTQ  }                      from './../../modules/cat_fastq'
include { CONFINDR as CONFINDR_NANOPORE }   from './../../modules/confindr'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow QC_NANOPORE {

    take:
    reads
    confindr_db

    main:

    // Nanopore read trimming
    PORECHOP_ABI(
        reads
    )
    ch_versions = ch_versions.mix(PORECHOP_ABI.out.versions)

    // Merge Nanopore reads per sample
    PORECHOP_ABI.out.reads.groupTuple().branch { meta, reads ->
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

    CONFINDR_NANOPORE(
        ch_ont_trimmed,
        confindr_db
    )

    if (params.nanopore_subsample) {
        RASUSA(
            ch_ont_trimmed.map { m,r -> [ m, r , params.rasusa_genome_size]},
            params.rasusa_coverage
        )
        ch_processed_reads = RASUSA.out.reads
    } else {
        ch_processed_reads = ch_ont_trimmed
    }

    emit:
    reads = ch_processed_reads
    qc = multiqc_files
    versions = ch_versions

}