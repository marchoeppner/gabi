process BIOBLOOM_MAKER {
    tag "$meta.sample_id"

    label 'medium_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biobloomtools:2.3.5--hdcf5f25_5' :
        'quay.io/biocontainers/biobloomtools:2.3.5--hdcf5f25_5' }"

    input:
    path(fasta)

    output:
    tuple path('*.bf'), path('*.txt')  , emit: index
    path 'versions.yml'                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "host_genomes"
    """
    biobloommaker -p $prefix \\
    -f $fasta \\
    -t $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        biobloommaker: \$( biobloommaker --version 2>&1 | head -n1 | cut -f3 -d ' ')
    END_VERSIONS
    """
}
