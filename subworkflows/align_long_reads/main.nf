include { MINIMAP2_ALIGN }    from './../../modules/minimap2/align'

ch_versions = Channel.from([])
ch_bam      = Channel.from([])

workflow ALIGN_LONG_READS {

    take:
    ch_reads_with_assembly

    main:

    MINIMAP2_ALIGN(
        ch_reads_with_assembly
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)
    ch_bam      = ch_bam.mix(MINIMAP2_ALIGN.out.bam)

    emit:
    versions = ch_versions
    bam = ch_bam
}