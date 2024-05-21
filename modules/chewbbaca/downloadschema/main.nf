process CHEWBBACA_DOWNLOADSCHEMA {
    maxForks 1

    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.4--pyhdfd78af_0' :
        'quay.io/biocontainers/chewbbaca:3.3.4--pyhdfd78af_0' }"

    input:
    tuple val(meta), val(id)

    output:
    tuple val(meta), path('schema_*')   , emit: schema
    path('versions.yml')                , emit: versions

    script:

    def args = task.ext.args ?: ''

    """
    chewBBACA.py DownloadSchema \\
    -sp $id \\
    -sc 1 \\
    -o schema_${id} $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewBBACA: \$(chewBBACA.py --version 2>&1 | sed -e "s/*.wersion: //g")
    END_VERSIONS

    """
}
