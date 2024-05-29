process CHEWBBACA_ALLELECALLEVALUATOR {
    maxForks 1

    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.4--pyhdfd78af_0' :
        'quay.io/biocontainers/chewbbaca:3.3.4--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(calls), val(db)

    output:
    tuple val(meta), path(results)      , emit: report
    path('versions.yml')                , emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    results = "evaluate_${prefix}"

    """
    chewBBACA.py AlleleCallEvaluator \\
    -i $calls \\
    -g $db \\
    -o $results \\
    --cpu ${task.cpus} $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewBBACA: \$(chewBBACA.py --version 2>&1 | sed -e "s/chewBBACA version: //g")
    END_VERSIONS

    """
}
