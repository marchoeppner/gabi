process BUSCO_BUSCO {
    tag "$meta.sample_id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/busco:5.3.0--pyhdfd78af_0':
        'quay.io/biocontainers/busco:5.3.0--pyhdfd78af_0' }"

    input:
    tuple val(meta),path(assembly)
    val(lineage)
    path(db)

    output:
    tuple val(meta),path(busco_summary)     , emit: summary
    tuple val(meta),path(busco_json)        , emit: json
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample_id}"
    busco_summary = "short_summary_" + meta.sample_id + ".txt"
    busco_json = "short_summary_" + meta.sample_id + ".json"
    def options = ""
    if (db) {
        options = "--download_path $db"
    }
    """

    busco -m genome -i $assembly \\
    $options \\
    $args \\
    -l $lineage \\
    -o busco_${prefix} \\
    -c ${task.cpus} \\
    --offline
    
    cp busco_${prefix}/short_summary.specific*.txt $busco_summary
    cp busco_${prefix}/short_summary.specific*.json $busco_json
    rm -Rf busco_${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(echo \$(busco -version 2>&1) | cut -f2 -d " " ))
    END_VERSIONS
    """
}
