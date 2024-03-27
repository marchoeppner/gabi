include { BUSCO_BUSCO }         from './../../modules/busco/busco'
include { BUSCO_DOWNLOAD }      from './../../modules/busco/download'
include { QUAST }               from './../../modules/quast'

ch_versions = Channel.from([])

workflow ASSEMBLY_QC {
    take:
    assembly
    busco_lineage
    busco_db_path

    main:

    assembly.branch { m,a ->
        annotated: m.taxon != "unknown"
        unknown: m.taxon == "unknown"
    }.set { ch_assembly_filtered }

    /*
    We use the previously attempted taxonomic classification to 
    choose the appropriate reference genome, if any
    */
    ch_assembly_filtered.annotated.map { m, a ->
        (genus,species) = m.taxon.toLowerCase().split(" ")
        if (params.genomes[genus]) {
            db = params.genomes[genus]
            ref = file(db.fasta)
            gff = file(db.gff)
        } else if (params.genomes["${genus}_${species}"]) {
            db = params.genomes["${genus}_${species}"]
            ref = file(db.fasta)
            gff = file(db.gff)
        } else {
            db = null
            ref = []
            gff = []
        }
        tuple(m,a,ref,gff)
    }.set { assembly_with_db }

    if (!busco_db_path) {
        BUSCO_DOWNLOAD(
            busco_lineage
        )
        busco_db_path = BUSCO_DOWNLOAD.out.db
    }
    BUSCO_BUSCO(
        assembly,
        busco_lineage,
        busco_db_path
    )
    ch_versions = ch_versions.mix(BUSCO_BUSCO.out.versions)

    emit:
    report = BUSCO_BUSCO.out.summary
    versions = ch_versions
}
