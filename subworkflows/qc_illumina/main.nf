include { FASTP }                       from './../../modules/fastp'
include { CAT_FASTQ }                   from './../../modules/cat_fastq'
include { FASTQC }                      from './../../modules/fastqc'

include { CONTAMINATION }               from './../contamination'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow QC_ILLUMINA {
    take:
    reads
    confindr_db

    main:

    // Short read trimming and QC
    FASTP(
        reads
    )
    ch_versions = ch_versions.mix(FASTP.out.versions)
    //multiqc_files = multiqc_files.mix(FASTP.out.json)

    // Split trimmed reads by sample to find multi-lane data set
    FASTP.out.reads.groupTuple().branch { meta, reads ->
        single: reads.size() == 1
            return [ meta, reads.flatten()]
        multi: reads.size() > 1
            return [ meta, reads.flatten()]
    }.set { ch_reads_illumina }

    // Concatenate samples with multiple PE files
    CAT_FASTQ(
        ch_reads_illumina.multi
    )

    // The trimmed files, reduced to [ meta, [ read1, read2 ] ]
    ch_illumina_trimmed = ch_reads_illumina.single.mix(CAT_FASTQ.out.reads)

    FASTQC(
        FASTP.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions)
    multiqc_files = multiqc_files.mix(FASTQC.out.zip.map {m,z -> z})

    CONTAMINATION(
        ch_illumina_trimmed,
        confindr_db
    )
    ch_versions = ch_versions.mix(CONTAMINATION.out.versions)

    emit:
    confindr_report = CONTAMINATION.out.report
    reads = ch_illumina_trimmed
    versions = ch_versions
    qc = multiqc_files
    }
