include { MOBSUITE_RECON }  from './../../modules/mobsuite/recon'

ch_versions = Channel.from([])

workflow PLASMIDS {

    take:
    ch_assemblies

    main:

    MOBSUITE_RECON(
        ch_assemblies
    )
    ch_versions = ch_versions.mix(MOBSUITE_RECON.out.versions)

    emit:
    plasmids = MOBSUITE_RECON.out.plasmids

}