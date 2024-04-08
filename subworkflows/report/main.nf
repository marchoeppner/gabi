
include { GABI_SUMMARY }    from './../../modules/helper/gabi_summary'

ch_versions = Channel.from([])

workflow REPORT {

    take:
    ch_kraken
    ch_mlst
    ch_quast

    main:

    ch_kraken.map { m,k -> 
        [ m.sample_id, k ] 
    }.join(
        ch_mlst.map { m,t ->
            [ m.sample_id,t]
        }, 
        remainder: true
    ).set { ch_kraken_mlst }

    ch_kraken_mlst.join(
        ch_quast.map { m,a ->
            [ m.sample_id, a ]
        }, remainder: true
    ).map { key,k,m,q ->
        meta = [:]
        meta.sample_id = key
        tuple(meta,k,m,q)
    }.set { ch_kraken_mlst_quast }

    GABI_SUMMARY(
        ch_kraken_mlst_quast
    )
    ch_versions = ch_versions.mix(GABI_SUMMARY.out.versions)

    emit:
    json = GABI_SUMMARY.out.json
    versions = ch_versions
}