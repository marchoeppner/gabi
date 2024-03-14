
include { KRAKEN2_DOWNLOAD }                        from './../../modules/kraken2/download'
include { BUSCO_DOWNLOAD as BUSCO_DOWNLOAD_REFS }   from './../../modules/busco/download'

kraken_db_url = params.references["kraken2"].url

workflow BUILD_REFEENCES {

    main:

    KRAKEN2_DOWNLOAD(
        kraken_db_url
    )

}