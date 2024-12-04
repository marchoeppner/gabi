include { FASTP }                       from './../../modules/fastp'
include { CAT_FASTQ }                   from './../../modules/cat_fastq'
include { FASTQC }                      from './../../modules/fastqc'
include { RASUSA }                      from './../../modules/rasusa'
include { CONTAMINATION }               from './../contamination'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow QC_ILLUMINA {
    take:
    reads
    confindr_db

    main:

    // Split trimmed reads by sample to find multi-lane data set
    reads.groupTuple().branch { meta, reads ->
        single: reads.size() == 1
            return [ meta, reads.flatten()]
        multi: reads.size() > 1
            return [ meta, reads.flatten()]
    }.set { ch_reads_illumina }

    // Concatenate samples with multiple PE files
    CAT_FASTQ(
        ch_reads_illumina.multi
    )

    ch_reads_merged = ch_reads_illumina.single.mix(CAT_FASTQ.out.reads)
 
    // Short read trimming and QC
    FASTP(
        ch_reads_merged
    )
    ch_versions = ch_versions.mix(FASTP.out.versions)
    multiqc_files = multiqc_files.mix(FASTP.out.json)

    FASTQC(
        FASTP.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions)
    multiqc_files = multiqc_files.mix(FASTQC.out.zip.map { m, z -> z })

    CONTAMINATION(
        FASTP.out.reads,
        confindr_db
    )
    ch_versions = ch_versions.mix(CONTAMINATION.out.versions)
    ch_reads_decont = CONTAMINATION.out.reads

    if (params.genome_size) {
        RASUSA(
            ch_reads_decont
        )
        ch_versions = ch_versions.mix(RASUSA.out.versions)
        ch_processed_reads = RASUSA.out.reads
    } else {
        ch_processed_reads = ch_reads_decont
    }

    emit:
    confindr_report = CONTAMINATION.out.report
    confindr_json   = CONTAMINATION.out.confindr_json
    confindr_qc = CONTAMINATION.out.qc
    reads = ch_processed_reads
    versions = ch_versions
    qc = multiqc_files
    }
