include { SNIPPY_RUN }      from './../../modules/snippy/run'
include { TABIX_TABIX }     from './../../modules/tabix/tabix'
include { BCFTOOLS_STATS }  from './../../modules/bcftools/stats'

ch_versions = Channel.from([])
multiqc_files = Channel.from([])

/*
Call variants against the assembled genome
to check how many sites are polymorphic and indicative
of e.g. conatmination or errors
*/
workflow VARIANTS {

    take:
    reads_with_assembly

    main:

    SNIPPY_RUN(
        reads_with_assembly
    )
    ch_versions = ch_versions.mix(SNIPPY_RUN.out.versions)

    TABIX_TABIX(
        SNIPPY_RUN.out.vcf_gz
    )
    ch_versions = ch_versions.mix(TABIX_TABIX.out.versions)

    BCFTOOLS_STATS(
        SNIPPY_RUN.out.vcf_gz.join(
            TABIX_TABIX.out.tbi
        )
    )
    ch_versions = ch_versions.mix(BCFTOOLS_STATS.out.versions)
    multiqc_files = multiqc_files.mix(BCFTOOLS_STATS.out.stats.map { m,s -> s })

    emit:
    vcf = SNIPPY_RUN.out.vcf
    qc  = multiqc_files
    stats = BCFTOOLS_STATS.out.stats
    versions = ch_versions
}