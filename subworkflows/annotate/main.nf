include { PROKKA }          from './../../modules/prokka'

ch_versions = Channel.from([])

workflow ANNOTATE {

    take:
    assembly

    main:

    PROKKA(
        assembly
    )
    ch_versions = ch_versions.mix(PROKKA.out.versions)
    
    emit:
    faa         = PROKKA.out.faa
    gbk         = PROKKA.out.gbk
    gff         = PROKKA.out.gff
    versions    = ch_versions
}