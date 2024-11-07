
include { KRAKEN2_DOWNLOAD }                                from './../modules/kraken2/download'
include { CONFINDR_INSTALL  }                               from './../modules/helper/confindr_install'
include { BUSCO_DOWNLOAD as BUSCO_INSTALL }                 from './../modules/busco/download'
include { AMRFINDERPLUS_UPDATE as AMRFINDERPLUS_INSTALL }   from './../modules/amrfinderplus/update'
include { PYMLST_WGMLST_INSTALL }                           from './../modules/pymlst/wgmlst_install'
include { CHEWBBACA_DOWNLOADSCHEMA }                        from './../modules/chewbbaca/downloadschema'
include { GUNZIP as GUNZIP_MASHDB }                                   from './../modules/gunzip'

kraken_db_url       = Channel.fromPath(params.references['kraken2'].url)
confindr_db_url     = Channel.fromPath(params.references['confindr'].url)
ch_busco_lineage    = Channel.from(['bacteria_odb10'])
mashdb              = Channel.fromPath(file(params.references['mashdb'].url)).map { f -> [ [target: 'MashDB'], f] }

// The IDs currently mapped to Chewbbaca schemas
chewie_ids = Channel.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])

workflow BUILD_REFERENCES {
    main:

    /*
    Download MashDB refseq database
    */
    GUNZIP_MASHDB(
        mashdb
    )

    /*
    Download the latest version of the AMRfinderplus DB
    This is not ideal since we cannot select specific versions -  but it works
    since we use a frozen version, and the last release of the DB for that version
    */
    AMRFINDERPLUS_INSTALL()

    /*
    Download the default Busco lineages
    */
    BUSCO_INSTALL(
        ch_busco_lineage
    )

    /*
    Download the Kraken MiniDB
    This should be good enough for our purposes
    */
    KRAKEN2_DOWNLOAD(
        kraken_db_url
    )

    /*
    Download a ConfindR database
    */
    CONFINDR_INSTALL(
        confindr_db_url
    )

    /*
    Install cgMLST schemas
    */
    PYMLST_WGMLST_INSTALL()

    /*
    Install Chewbbaca schemas based on schema ID
    */
    CHEWBBACA_DOWNLOADSCHEMA(
        chewie_ids.map { i ->
            [
                [ sample_id: i],
                i
            ]
        }
    )
}

if (params.build_references) {
    workflow.onComplete = {
        log.info 'Installation complete - deleting staged files. '
        workDir.resolve("stage-${workflow.sessionId}").deleteDir()
    }
}
