/*
Include Modules
*/

include { PORECHOP_ABI }                    from './../../modules/porechop/abi'
include { RASUSA }                          from './../../modules/rasusa'
include { CAT_FASTQ  }                      from './../../modules/cat_fastq'
//include { CONTAMINATION }                   from './../contamination'
include { NANOPLOT }                        from './../../modules/nanoplot'

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
    multiqc_files = multiqc_files.mix(PORECHOP_ABI.out.log.map { m, l -> l })

    NANOPLOT(
        PORECHOP_ABI.out.reads
    )
    ch_versions = ch_versions.mix(NANOPLOT.out.versions)
    multiqc_files = multiqc_files.mix(NANOPLOT.out.txt.map { m, r -> r })

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

    /* CONTAMINATION(
        ch_ont_trimmed,
        confindr_db
    )
    ch_versions = ch_versions.mix(CONTAMINATION.out.versions)
 */
    if (params.subsample_reads) {
        RASUSA(
            ch_ont_trimmed.map { m, r -> [ m, r, params.genome_size] },
            params.max_coverage
        )
        ch_versions = ch_versions.mix(RASUSA.out.versions)
        ch_processed_reads = RASUSA.out.reads
    } else {
        ch_processed_reads = ch_ont_trimmed
    }

    emit:
    //confindr_report = CONTAMINATION.out.report
    //confindr_json   = CONTAMINATION.out.json
    reads = ch_processed_reads
    qc = multiqc_files
    versions = ch_versions
    }
