process AMRFINDERPLUS_UPDATE {
    tag "update"
    label 'short_serial'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ncbi-amrfinderplus:3.11.18--h283d18e_0':
        'quay.io/biocontainers/ncbi-amrfinderplus:3.11.18--h283d18e_0' }"

    output:
    path "amrfinderdb.tar.gz", emit: db
    path "versions.yml"      , emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    amrfinder_update -d amrfinderdb
    tar czvf amrfinderdb.tar.gz -C amrfinderdb/\$(readlink amrfinderdb/latest) ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrfinderplus: \$(amrfinder --version)
    END_VERSIONS
    """
}
