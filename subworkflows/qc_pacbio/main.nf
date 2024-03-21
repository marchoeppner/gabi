
include { RASUSA }                          from './../../modules/rasusa'
include { CAT_FASTQ  }                      from './../../modules/cat_fastq'
include { CONFINDR as CONFINDR_PACBIO }     from './../../modules/confindr'
include { FASTQC }                          from './../../modules/fastqc'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow QC_PACBIO {
    take:
    reads
    confindr_db

    main:

    // Merge Nanopore reads per sample
    reads.groupTuple().branch { meta, reads ->
        single: reads.size() == 1
            return [ meta, reads.flatten()]
        multi: reads.size() > 1
            return [ meta, reads.flatten()]
    }.set { ch_reads_pb }

    CAT_FASTQ(
        ch_reads_pb.multi
    )

    // The trimmed ONT reads, concatenated by sample
    ch_pb_trimmed = ch_reads_pb.single.mix(CAT_FASTQ.out.reads)

    FASTQC(
        reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions)
    multiqc_files = multiqc_files.mix(FASTQC.out.zip.map{m,z -> z})

    CONFINDR_PACBIO(
        ch_pb_trimmed,
        confindr_db
    )
    ch_versions = ch_versions.mix(CONFINDR_PACBIO.out.versions)

    if (params.subsample_reads) {
        RASUSA(
            ch_pb_trimmed.map { m, r -> [ m, r, params.genome_size] },
            params.max_coverage
        )
        ch_versions = ch_versions.mix(RASUSA.out.versions)
        ch_processed_reads = RASUSA.out.reads
    } else {
        ch_processed_reads = ch_pb_trimmed
    }

    emit:
    confindr_report = CONFINDR_PACBIO.out.report
    reads = ch_processed_reads
    qc = multiqc_files
    versions = ch_versions
    }
