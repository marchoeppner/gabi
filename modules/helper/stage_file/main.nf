process STAGE_FILE {
    label 'short_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.23--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0' }"

    input:
    path(f)

    output:
    path(f)                 , emit: staged_file

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    touch dummy.txt
    
    """
}
