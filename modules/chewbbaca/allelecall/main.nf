process CHEWBBACA_ALLELECALL {
    maxForks 1

    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/chewbbaca:3.3.4--pyhdfd78af_0' :
        'quay.io/biocontainers/chewbbaca:3.3.4--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(assemblies, stageAs: 'assemblies/'), val(db)

    output:
    tuple val(meta), path(results)                          , emit: report
    tuple val(meta), path("${results}/results_alleles.tsv") , emit: profile
    path('versions.yml')                                    , emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    def db_name = file(db).getSimpleName()
    results = "results_${prefix}_${db_name}"

    """
    chewBBACA.py AlleleCall \\
    -i assemblies \\
    -g $db \\
    -o $results \\
    --hash-profiles true \\
    --cpu ${task.cpus} $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chewBBACA: \$(chewBBACA.py --version 2>&1 | sed -e "s/chewBBACA version: //g")
    END_VERSIONS

    """
}
