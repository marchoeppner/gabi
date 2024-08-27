process CONFINDR2JSON {
    tag "${meta.sample_id}"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.23--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(report)

    output:
    tuple val(meta), path('*.json'), emit: json
    path 'versions.yml'             , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: report.getSimpleName()
    result = prefix + '.json'

    """
    confindr2json.py --confindr $report \
    --sample ${meta.sample_id} \
    $args \
    --output $result

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version  | sed -e "s/Python //")
    END_VERSIONS
    """
}
