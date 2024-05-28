include { PYMLST_CLAMLST }                  from './../../modules/pymlst/clamlst'
include { PYMLST_WGMLST_ADD }               from './../../modules/pymlst/wgmlst/add'
include { PYMLST_WGMLST_DISTANCE }          from './../../modules/pymlst/wgmlst/distance'
include { CHEWBBACA_ALLELECALL }            from './../../modules/chewbbaca/allelecall'
include { CHEWBBACA_ALLELECALLEVALUATOR }   from './../../modules/chewbbaca/allelecallevaluator'

ch_versions = Channel.from([])

workflow MLST_TYPING {
    take:
    assembly

    main:

    assembly.branch { m, a ->
        annotated: m.taxon != 'unknown'
        unknown: m.taxon == 'unknown'
    }.set { ch_assembly_filtered }

    /*
    We use the previously attempted taxonomic classification to
    choose the appropriate MLST schema, if any
    */
    ch_assembly_filtered.annotated.map { m, a ->
        (genus,species) = m.taxon.toLowerCase().split(' ')
        def db = null
        if (params.mlst[genus]) {
            db = params.mlst[genus]
        } else if (params.mlst["${genus}_${species}"]) {
            db = params.mlst["${genus}_${species}"]
        } else {
            db = null
        }
        tuple(m, a, db)
    }.set { assembly_with_db }

    /*
    We use the previously attempted taxonomic classification
    to choose the appropriate cgMLST schema, if any
    */
    ch_assembly_filtered.annotated.map { m, a ->
        (genus,species) = m.taxon.toLowerCase().split(' ')
        def cg_db = null
        if (params.cgmlst[genus]) {
            cg_db = params.cgmlst[genus]
            m.db_name = genus
        } else if (params.cgmlst["${genus}_${species}"]) {
            cg_db = params.cgmlst["${genus}_${species}"]
            m.db_name = "${genus}_${species}"
        } else {
            cg_db = null
        }
        tuple(m, a, cg_db)
    }.set { assembly_with_cg_db }

    /*
    We use the previously attempted taxonomic classification
    to choose the appropriate Chewbbaca cgMLST schema, if any
    Assemblies are grouped by taxon to create a multi-sample
    call matrix per species
    */
    ch_assembly_filtered.annotated.map  { m,a ->
        def tax = m.taxon.toLowerCase().replaceAll(" ","_")
        tuple(tax,a)
    }.groupTuple()
    .map { taxon, assemblies ->
        def meta = [:]
        meta.taxon = taxon
        meta.sample_id = taxon
        tuple(meta,assemblies)
    }.map { m, a ->
        (genus,species) = m.taxon.toLowerCase().split('_')
        def chewie_db = null
        if (params.chewbbaca[genus]) {
            chewie_db = params.chewbbaca[genus]
            m.db_name = genus
        } else if (params.chewbbaca["${genus}_${species}"]) {
            chewie_db = params.chewbbaca["${genus}_${species}"]
            m.db_name = "${genus}_${species}"
        } else {
            chewie_db = null
        }
        tuple(m, a, chewie_db)
    }.set { assembly_with_chewie_db }

    /*
    Run claMLST on assemblies for which we have taxonomic information
    and a matching MLST schema configured
    */
    PYMLST_CLAMLST(
        assembly_with_db.filter { a -> a.last() }
    )
    ch_versions = ch_versions.mix(PYMLST_CLAMLST.out.versions)

    /*
    Run wgMLST on assemblies for which we have taxonomic information
    and a matching cgMLST schema configured
    */
    PYMLST_WGMLST_ADD(
        assembly_with_cg_db.filter { a -> a.last() }
    )
    ch_versions = ch_versions.mix(PYMLST_WGMLST_ADD.out.versions)

    PYMLST_WGMLST_ADD.out.report.map { m, t ->
        [
            [ sample_id: m.db_name, taxon: m.taxon , db_name: m.db_name ],
            t
        ]
    }.groupTuple()
    .map { m, r ->
        db = params.cgmlst[m.db_name]
        tuple(m, db)
    }
    .set { assemblies_for_cgmlst }

    /*
    Perform clustering on the given database
    */
    PYMLST_WGMLST_DISTANCE(
        assemblies_for_cgmlst
    )
    ch_versions = ch_versions.mix(PYMLST_WGMLST_DISTANCE.out.versions)

    /*
    Perform cgMLST calling with Chewbbaca
    */
    CHEWBBACA_ALLELECALL(
        assembly_with_chewie_db.filter { a -> a.last() }
    )
    ch_versions = ch_versions.mix(CHEWBBACA_ALLELECALL.out.versions)

    CHEWBBACA_ALLELECALLEVALUATOR(
        CHEWBBACA_ALLELECALL.out.report_with_db
    )
    ch_versions = ch_versions.mix(CHEWBBACA_ALLELECALLEVALUATOR.out.versions)

    emit:
    versions = ch_versions
    report = PYMLST_CLAMLST.out.report
    }
