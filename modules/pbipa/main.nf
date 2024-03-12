process PBIPA {
    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pbipa:1.8.0--h6ead514_2'' :
        'quay.io/biocontainers/pbipa:1.8.0--h6ead514_2' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*trimmed.fastq.gz'), emit: reads
    path("*.json"), emit: json
    path('versions.yml'), emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: reads[0].getBaseName()

    r1 = reads[0]

    suffix = '_trimmed.fastq.gz'

    json = prefix + '.fastp.json'
    html = prefix + '.fastp.html'

    """

    """
}
