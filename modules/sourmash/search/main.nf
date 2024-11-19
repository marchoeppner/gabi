process SOURMASH_SEARCH {
    tag "$meta.sample_id"
    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sourmash:4.8.4--hdfd78af_0':
        'quay.io/biocontainers/sourmash:4.8.4--hdfd78af_0' }"

    input:
    tuple val(meta), path(sig)
    path(db)

    output:
    tuple val(meta), path("*.csv"), emit: csv
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // required defaults for the tool to run, but can be overridden
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.sample_id}"
    """
    sourmash search \\
        $args \\
        -o ${prefix}.csv \\
        $sig \\
        $db

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sourmash: \$(echo \$(sourmash --version 2>&1) | sed 's/^sourmash //' )
    END_VERSIONS
    """
}
