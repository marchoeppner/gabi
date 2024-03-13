
include { PYMLST_IMPORT_CGMLST }

schemas = []

params.references.cgmlst.keySet().each { s ->
    schemas << params.references.cgmlst[s].db_name
}

ch_cgmlst_schemas = Channel.from(schemas)

workflow BUILD_REFEENCES {

    main:

    PYMLST_IMPORT_CGMLST(
        ch_cgmlst_schemas
    )


}