process MOSDEPTH {
    tag "$meta.sample_id"
    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mosdepth:0.3.8--hd299d5a_0' :
        'quay.io/biocontainers/mosdepth:0.3.8--hd299d5a_0'}"

    input:
    tuple val(meta),  path(bam), path(bai)

    output:
    tuple val(meta), path('*.global.dist.txt')      , emit: global_txt
    tuple val(meta), path('*.summary.txt')          , emit: summary_txt
    path  "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample_id}.${meta.platform}"

    """
    mosdepth \\
        --threads $task.cpus \\
        $args \\
        $prefix \\
        $bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mosdepth: \$(mosdepth --version 2>&1 | sed 's/^.*mosdepth //; s/ .*\$//')
    END_VERSIONS
    """

}
