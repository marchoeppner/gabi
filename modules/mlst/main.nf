process MLST {
    tag "${meta.sample_id}|${db}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mlst:2.23.0--hdfd78af_1' :
        'quay.io/biocontainers/mlst:2.23.0--hdfd78af_1' }"

    input:
    tuple val(meta), path(assembly), val(db)

    output:
    tuple val(meta), path('*mlst.tsv')  , emit: report
    tuple val(meta), path('*.json')     , emit: json
    path('versions.yml')                , emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id

    """
    mlst \\
    --scheme $db \\
    $args \\
    --threads ${task.cpus} \\
    --json ${prefix}.${db}.mlst.json \\
    $assembly > ${prefix}.${db}.mlst.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mlst: \$(mlst --version 2>&1 | head -n1 | sed -e "s/mlst //g")
    END_VERSIONS

    """
}
