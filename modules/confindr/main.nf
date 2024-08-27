process CONFINDR {
    tag "$meta.sample_id"
    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/confindr:0.8.1--pyhdfd78af_1' :
        'quay.io/biocontainers/confindr:0.8.1--pyhdfd78af_1' }"

    input:
    tuple val(meta), path(reads, stageAs: 'input_dir/*')
    path db

    output:
    tuple val(meta), path('confindr_results/*contamination.csv'),   emit: csv, optional: true
    tuple val(meta), path('confindr_results/*confindr_log.txt'),    emit: log
    tuple val(meta), path('confindr_results/*confindr_report.csv'), emit: report
    tuple val(meta), path('confindr_results/*_rmlst.csv'),          emit: rmlst, optional: true
    path 'versions.yml',                                            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample_id}_${meta.platform}"
    def db_options = db ? "-d ${db}" : ''
    """
    confindr.py \\
        -Xmx ${task.memory.toGiga()}G \\
        --threads $task.cpus \\
        -i input_dir \\
        -o confindr_results \\
        $args $db_options

    mv confindr_results/confindr_log.txt confindr_results/${prefix}_confindr_log.txt
    mv confindr_results/confindr_report.csv confindr_results/${prefix}_confindr_report.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        confindr: \$(confindr.py --version 2>&1 | sed -e "s/ConFindr //g")
    END_VERSIONS
    """
}
