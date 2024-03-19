
include { KRAKEN2_DOWNLOAD }                                from './../modules/kraken2/download'
include { CONFINDR_INSTALL  }                               from './../modules/helper/confindr_install'
include { BUSCO_DOWNLOAD as BUSCO_INSTALL }                 from './../modules/busco/download'
include { AMRFINDERPLUS_UPDATE as AMRFINDERPLUS_INSTALL }   from './../modules/amrfinderplus/update'

kraken_db_url       = Channel.fromPath(params.references['kraken2'].url)
confindr_db_url     = Channel.fromPath(params.references['confindr'].url)
ch_busco_lineage    = Channel.from(['bacteria_odb10'])

workflow BUILD_REFERENCES {
    main:

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
}
