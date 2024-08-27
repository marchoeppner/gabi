process DOWNLOAD_MASHDB {
    label 'medium_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    path(dbfile)

    output:
    path(dbfile)         , emit: db

    script:
    sketch = dbfile.getName()

    '''
    echo "Download complete"
    '''
}
