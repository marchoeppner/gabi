process MULTIQC {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    conda 'bioconda::multiqc=1.19'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.19--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.19--pyhdfd78af_0' }"

    input:
    path('*')

    output:
    path('multiqc_report.html'), emit: html
    path("versions.yml"), emit: versions

    script:

    """
    cp ${params.logo} .
    cp ${baseDir}/assets/multiqc_config.yaml .
    multiqc .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
