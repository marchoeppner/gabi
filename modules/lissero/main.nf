process LISSERO {
    tag "${meta.sample_id}"

    label 'short_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/lissero:0.4.9--py_0' :
        'quay.io/biocontainers/lissero:0.4.9--py_0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    path('versions.yml'), emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    """
    lissero $fasta > ${prefix}.lissero.tsv $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        LisSero: \$(lissero --version 2>&1 | cut -f2 -d " ")
    END_VERSIONS

    """
}
