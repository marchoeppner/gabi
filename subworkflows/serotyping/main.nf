include { ECTYPER }     from './../../modules/ectyper'
include { SEQSERO2 }    from './../../modules/seqsero2'
include { LISSERO }     from './../../modules/lissero'

ch_versions = Channel.from([])
ch_reports = Channel.from([])

workflow SEROTYPING {

    take:
    assembly // [ meta, assembly ]

    main:

    assembly.branch { m,a ->
        ecoli: m.taxon ==~ /^Escherichia.*/
        salmonella: m.taxon ==~ /^Salmonella.*/
        listeria: m.taxon ==~ /^Listeria.*/
    }.set { assembly_by_taxon }

    /*
    Run Ectyper - Serotyping of E. coli
    */
    ECTYPER(
        assembly_by_taxon.ecoli
    )
    ch_versions = ch_versions.mix(ECTYPER.out.versions)
    ch_reports = ch_reports.mix(ECTYPER.out.tsv)

    /*
    Run SeqSero2 - Serotyping for Salonella
    */
    SEQSERO2(
        assembly_by_taxon.salmonella
    )
    ch_versions = ch_versions.mix(SEQSERO2.out.versions)
    ch_reports = ch_reports.mix(SEQSERO2.out.tsv)

    /*
    Run LisSero - Serotyping L. monocytogenes
    */
    LISSERO(
        assembly_by_taxon.listeria
    )
    ch_versions = ch_versions.mix(LISSERO.out.versions)
    ch_reports  = ch_reports.mix(LISSERO.out.tsv)

    emit:
    versions = ch_versions
    reports = ch_reports

}