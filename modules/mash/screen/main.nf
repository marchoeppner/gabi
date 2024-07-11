process MASH_SCREEN {
    tag "$meta.sample_id"
    label 'medium_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mash:2.3--he348c14_1':
        'biocontainers/mash:2.3--he348c14_1' }"

    input:
    tuple val(meta) , path(query)
    tuple val(meta2), path(sequences_sketch)

    output:
    tuple val(meta), path("*.screen"), emit: screen
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample_id}"
    """
    mash \\
        screen \\
        $args \\
        -p $task.cpus \\
        $sequences_sketch \\
        $query \\
        > ${prefix}.screen

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mash: \$( mash --version )
    END_VERSIONS
    """
}
