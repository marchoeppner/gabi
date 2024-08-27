process CONFINDR2MQC_SUMMARY {
    tag params.run_name

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.23--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0' }"

    input:
    path(reports)

    output:
    path('*_mqc.json')      , emit: json
    path 'versions.yml'     , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: params.run_name
    result = prefix + '_confindr_mqc.json'

    """
    confindr2summary_mqc.py $args \
    --output $result

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version  | sed -e "s/Python //")
    END_VERSIONS
    """
}
