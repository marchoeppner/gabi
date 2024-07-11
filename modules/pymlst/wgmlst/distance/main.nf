process PYMLST_WGMLST_DISTANCE {
    
    maxForks 1

    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pymlst:2.1.6--pyhdfd78af_0' :
        'quay.io/biocontainers/pymlst:2.1.6--pyhdfd78af_0' }"

    input:
    tuple val(meta), val(db)

    output:
    tuple val(meta), path('*cgmlst.txt')  , emit: report
    path('versions.yml')                , emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id

    """
    wgMLST \\
    distance \\
    --output ${prefix}.cgmlst.txt \\
    $db $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyMLST: \$(claMLST --version 2>&1 | head -n1 | sed -e "s/Version: //g")
    END_VERSIONS

    """
}
