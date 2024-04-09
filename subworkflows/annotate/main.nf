include { PROKKA }          from './../../modules/prokka'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

workflow ANNOTATE {
    take:
    assembly
    ch_prokka_proteins
    ch_prokka_prodigal

    main:

    PROKKA(
        assembly,
        ch_prokka_proteins,
        ch_prokka_prodigal
    )
    ch_versions = ch_versions.mix(PROKKA.out.versions)
    multiqc_files = multiqc_files.mix(PROKKA.out.txt)

    emit:
    fna         = PROKKA.out.fna
    faa         = PROKKA.out.faa
    gbk         = PROKKA.out.gbk
    gff         = PROKKA.out.gff
    versions    = ch_versions
    qc          = multiqc_files
}
