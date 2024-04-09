include { QC_ILLUMINA }     from './../qc_illumina'
include { QC_NANOPORE }     from './../qc_nanopore'
include { QC_PACBIO }       from './../qc_pacbio'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])
ch_confindr_reports = Channel.from([])

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
        torrent: meta.platform == 'TORRENT'
    }.set { ch_reads }

    ch_reads.torrent.subscribe { m, r ->
        log.warn "Torrent data not yet supported, skipping ${meta.sample_id}..."
    }

    /*
    Trim and QC Illumina reads
    */
    QC_ILLUMINA(
        ch_reads.illumina,
        confindr_db
    )
    ch_illumina_trimmed = QC_ILLUMINA.out.reads
    ch_confindr_reports = ch_confindr_reports.mix(QC_ILLUMINA.out.confindr_json)
    ch_versions         = ch_versions.mix(QC_ILLUMINA.out.versions)

    /*
    Trim and QC nanopore reads
    */
    QC_NANOPORE(
        ch_reads.ont,
        confindr_db
    )
    ch_ont_trimmed      = QC_NANOPORE.out.reads
    ch_versions         = ch_versions.mix(QC_NANOPORE.out.versions)
    ch_confindr_reports = ch_confindr_reports.mix(QC_NANOPORE.out.confindr_json)

    /*
    Trim and QC Pacbio HiFi reads
    */
    QC_PACBIO(
        ch_reads.pacbio,
        confindr_db
    )
    ch_pacbio_trimmed   = QC_PACBIO.out.reads
    ch_confindr_reports = ch_confindr_reports.mix(QC_PACBIO.out.confindr_json)
    ch_versions         = ch_versions.mix(QC_PACBIO.out.versions)

    emit:
    qc_confindr = ch_confindr_reports
    qc_illumina = QC_ILLUMINA.out.qc
    qc_nanopore = QC_NANOPORE.out.qc
    qc_pacbio = QC_PACBIO.out.qc
    illumina = ch_illumina_trimmed
    ont = ch_ont_trimmed
    pacbio = ch_pacbio_trimmed
    versions = ch_versions
    qc = multiqc_files
    }
