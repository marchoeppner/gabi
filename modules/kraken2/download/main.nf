process KRAKEN2_DOWNLOAD {
    label 'medium_serial'

    publishDir "${params.outdir}/gabi/kraken2", mode: 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04'

    input:
    path(url)

    output:
    path(db_name)         , emit: db
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    archive = url.split("/")[-1]
    db_name = archive.replace(".tgz", "")
    """
    wget $url

    tar -xvf $archive
    rm *.tgz

    """
}
