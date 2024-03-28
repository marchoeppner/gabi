process PYMLST_CLAMLST_INSTALL {

    label 'short_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pymlst:2.1.6--pyhdfd78af_0' :
        'quay.io/biocontainers/pymlst:2.1.6--pyhdfd78af_0' }"

    output:
    path("db"), emit: db

    script:

    """
    mkdir -p db
    download_pymlst_clamlst.sh
    """

}