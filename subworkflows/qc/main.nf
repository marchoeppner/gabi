include { QC_ILLUMINA }     from './../qc_illumina'
include { QC_NANOPORE }     from './../qc_nanopore'
include { QC_PACBIO }       from './../qc_pacbio'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow QC {

    take:
    reads
    confindr_db

    main:

    // Divide reads up into their sequencing technologies
    reads.branch { meta, reads ->
        illumina: meta.platform == 'ILLUMINA'
        ont: meta.platform == 'NANOPORE'
        pacbio: meta.platform == 'PACBIO'
    }.set { ch_reads }

    /*
    Trim and QC Illumina reads
    */
    QC_ILLUMINA(
        ch_reads.illumina,
        confindr_db
    )
    ch_illumina_trimmed = QC_ILLUMINA.out.reads
    ch_versions         = ch_versions.mix(QC_ILLUMINA.out.versions)
    multiqc_files       = multiqc_files.mix(QC_ILLUMINA.out.qc)

    /*
    Trim and QC nanopore reads
    */
    QC_NANOPORE(
        ch_reads.ont,
        confindr_db
    )
    ch_ont_trimmed      = QC_NANOPORE.out.reads
    ch_versions         = ch_versions.mix(QC_NANOPORE.out.versions)
    multiqc_files       = multiqc_files.mix(QC_NANOPORE.out.qc)

    /* 
    Trim and QC Pacbio HiFi reads
    */
    QC_PACBIO(
        ch_reads.pacbio,
        confindr_db
    )
    ch_pacbio_trimmed   = QC_PACBIO.out.reads
    ch_versions         = ch_versions.mix(QC_PACBIO.out.versions)

    emit:
    
    illumina = ch_illumina_trimmed
    ont = ch_ont_trimmed
    pacbio = ch_pacbio_trimmed
    versions = ch_versions
    qc = multiqc_files
}