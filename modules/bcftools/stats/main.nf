process BCFTOOLS_STATS {
    tag "$meta.sample_id"
    label 'short_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.20--h8b25389_0':
        'quay.io/biocontainers/bcftools:1.20--h8b25389_0' }"

    input:
    tuple val(meta),  path(vcf), path(tbi)

    output:
    tuple val(meta), path("*stats.txt"), emit: stats
    path  "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample_id}"

    """
    bcftools stats \\
        $args \\
        $vcf > ${prefix}.bcftools_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}
