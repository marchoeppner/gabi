process MULTIQC {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.19--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.19--pyhdfd78af_0' }"

    input:
    path('*')
    path(config)
    path(logo)

    output:
    path('*multiqc_report.html'), emit: html
    path("versions.yml"), emit: versions

    script:

    """

    multiqc -n ${params.run_name}_multiqc_report .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
