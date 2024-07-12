include { ECTYPER }     from './../../modules/ectyper'
include { SEQSERO2 }    from './../../modules/seqsero2'

ch_versions = Channel.from([])

workflow SEROTYPING {

    take:
    assembly // [ meta, assembly ]

    main:

    assembly.branch { m,a ->
        ecoli: m.taxon ==~ /^Escherichia.*/
        salmonella: m.taxon ==~ /^Salmonella.*/
    }.set { assembly_by_taxon }

    ECTYPER(
        assembly_by_taxon.ecoli
    )
    ch_versions = ch_versions.mix(ECTYPER.out.versions)

    SEQSERO2(
        assembly_by_taxon.salmonella
    )
    ch_versions = ch_versions.mix(SEQSERO2.out.versions)

    emit:
    versions = ch_versions

}