process ECTYPER {
    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ectyper:1.0.0--pyhdfd78af_1' :
        'quay.io/biocontainers/ectyper:1.0.0--pyhdfd78af_1' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path('*trimmed.fastq.gz'), emit: reads
    path("*.json"), emit: json
    path('versions.yml'), emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    """
    ectyper -i $fasta \\
    -c ${task.cpus} \\
    -o $prefix

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ectyper: \$(ectyper --version 2>&1 | cut -f2 -d " ")
    END_VERSIONS

    """
}
