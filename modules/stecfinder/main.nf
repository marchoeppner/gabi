process STECFINDER {
    tag "$meta.sample_id"
    label 'short_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/stecfinder:1.1.0--pyhdfd78af_0':
        'quay.io/biocontainers/stecfinder:1.1.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(seqs)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample_id}"
    """
    stecfinder \\
        -i $seqs \\
        $args \\
        -t $task.cpus > ${prefix}.stecfinder.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stecfinder: \$(echo \$(stecfinder --version 2>&1) | sed 's/^.*STECFinder version: //;' )
    END_VERSIONS
    """
}
