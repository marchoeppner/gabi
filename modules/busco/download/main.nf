process BUSCO_DOWNLOAD {
    label 'short_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/busco:5.3.0--pyhdfd78af_0' :
        'quay.io/biocontainers/busco:5.3.0--pyhdfd78af_0' }"

    input:
    val(busco_tax)

    output:
    tuple val(lineage_folder), path('busco_downloads'), emit: db
    path(lineage_folder)
    path 'versions.yml'           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    lineage_folder = "busco_downloads/lineages/${busco_tax}"

    """
    busco --download $busco_tax

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(echo \$(wget --version 2>&1) | cut -f3 -d " " ))
    END_VERSIONS
    """
}
