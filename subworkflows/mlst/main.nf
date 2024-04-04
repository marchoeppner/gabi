include { PYMLST_CLAMLST }      from './../../modules/pymlst/clamlst'

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
    Run claMLST on assemblies for which we have taxonomic information
    and a matching MLST schema configured
    */
    PYMLST_CLAMLST(
        assembly_with_db.filter { a -> a.last() }
    )
    ch_versions = ch_versions.mix(PYMLST_CLAMLST.out.versions)

    emit:
    versions = ch_versions
    }
