include { PYMLST_CLAMLST }                  from './../../modules/pymlst/clamlst'
include { PYMLST_WGMLST_ADD }               from './../../modules/pymlst/wgmlst/add'
include { PYMLST_WGMLST_DISTANCE }          from './../../modules/pymlst/wgmlst/distance'
include { CHEWBBACA_ALLELECALL }            from './../../modules/chewbbaca/allelecall'
include { CHEWBBACA_ALLELECALL as CHEWBBACA_ALLELECALL_SINGLE }            from './../../modules/chewbbaca/allelecall'
include { CHEWBBACA_JOINPROFILES }          from './../../modules/chewbbaca/joinprofiles'
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
        def (genus,species) = m.taxon.toLowerCase().split(' ')
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
        def (genus,species) = m.taxon.toLowerCase().split(' ')
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

    ch_assembly_filtered.annotated.map { m, a ->
        def (genus,species) = m.taxon.toLowerCase().split(' ')
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
    and a matching MLST schema configured, i.e. the last element must
    not be null
    */
    PYMLST_CLAMLST(
        assembly_with_db.filter { a -> a.last() }
    )
    ch_versions = ch_versions.mix(PYMLST_CLAMLST.out.versions)

    if (!params.skip_cgmlst) {

        /*
        Inform users about to-be-skipped samples due to a lack of a matching cgMLST database
        */
        assembly_with_cg_db.filter( a -> !a.last() ).subscribe { m,s,d ->
            log.warn "${m.sample_id} - could not match a pyMLST cgMLST database to ${m.taxon}."
        }
        assembly_with_chewie_db.filter( a -> !a.last() ).subscribe { m,s,d ->
            log.warn "${m.sample_id} - could not match a Chewbbaca cgMLST database to ${m.taxon}."
        }

        /*
        Run wgMLST on assemblies for which we have taxonomic information
        and a matching cgMLST schema configured, i.e. the last element must
        not be null
        */
        PYMLST_WGMLST_ADD(
            assembly_with_cg_db.filter { a -> a.last() }
        )
        ch_versions = ch_versions.mix(PYMLST_WGMLST_ADD.out.versions)

        /*
        Get the databases for which we have assemblies to 
        perform cgMLST clustering
        */
        assembly_with_cg_db.filter { a -> a.last() }
        .map { m,a,d -> tuple(m,d) }
        .groupTuple(by: 1)
        .map { metas, db ->
            def meta = [:]
            meta.db_name = file(db).getSimpleName()
            meta.sample_id = file(db).getSimpleName()
            tuple(meta,db)
        }.set { ch_cgmlst_database }
        /*
        Perform clustering on the given database
        */
        PYMLST_WGMLST_DISTANCE(
            ch_cgmlst_database
        )
        ch_versions = ch_versions.mix(PYMLST_WGMLST_DISTANCE.out.versions)

        /*
        Perform cgMLST calling with Chewbbaca
        Part one consists of a joint allele calling approach in which all samples belonging to the same species are jointly call
        In addition, each sample is called invidivually to support downstream analysis of samples from across runs
        */
        CHEWBBACA_ALLELECALL_SINGLE(
            assembly_with_chewie_db.filter { a -> a.last() }
        )
        ch_versions = ch_versions.mix(CHEWBBACA_ALLELECALL_SINGLE.out.versions)

        ch_profiles = CHEWBBACA_ALLELECALL_SINGLE.out.profile.map { m, r ->
                def meta = [:]
                meta.db_name = m.db_name
                meta.sample_id = m.db_name
                tuple(meta, r)
            }.groupTuple()

        /*
        Join profiles, assuming we have more than one
        */
        CHEWBBACA_JOINPROFILES(
            ch_profiles.filter{ m,reports -> reports.size() > 1 }
        )
        ch_versions = ch_versions.mix(CHEWBBACA_JOINPROFILES.out.versions)

        /* Join assemblies and databases to generate
        [ meta, [ assemblies ], db ] and filter out all 
        cases where # assemblies is < 3 (no point to compute relationships)
        */

        assembly_with_chewie_db.filter { a -> a.last() }
        .map { m, a, d ->
            def meta = [:]
            meta.sample_id = m.db_name
            meta.db_name = m.db_name
            tuple(meta,a,d)
        }.groupTuple(by: [0,2])
        .filter { m,a,d -> a.size() > 2 }
        .set { ch_assemblies_chewie_call }
        
        CHEWBBACA_ALLELECALL(
            ch_assemblies_chewie_call
        )
        ch_versions = ch_versions.mix(CHEWBBACA_ALLELECALL.out.versions)
        CHEWBBACA_ALLELECALLEVALUATOR(
            CHEWBBACA_ALLELECALL.out.report.map { m, r ->
                def chewie_db = params.chewbbaca[m.db_name]
                tuple(m, r, chewie_db)
            }
        )
        ch_versions = ch_versions.mix(CHEWBBACA_ALLELECALLEVALUATOR.out.versions)
    }

    emit:
    versions = ch_versions
    report = PYMLST_CLAMLST.out.report
    }
