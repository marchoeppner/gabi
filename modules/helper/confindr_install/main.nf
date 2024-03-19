process CONFINDR_INSTALL {
    label 'medium_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    path(url)

    output:
    path("confindr")         , emit: db

    script:
    archive = url.toString().split('/')[-1]
    db_name = archive.replace('.tar.gz', '')

    """
    tar -xvf $url
    rm *.tar.gz
    """
}
