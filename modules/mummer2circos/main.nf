process MUMMER2CIRCOS {
    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mummer2circos:1.4.2--pyhdfd78af_0' :
        'quay.io/biocontainers/mummer2circos:1.4.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(fasta), path(ref), path(gff), path(gbk)

    output:
    tuple val(meta), path('*.png'), emit: png, optional: true
    tuple val(meta), path('*.svg'), emit: svg, optional: true
    path('versions.yml'), emit: versions

    script:
    // Couldnt find a way to read out mummer2circos version, hard-coding it instead. 
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    """
    mummer2circos -l -r $ref \
    -q $fasta \
    -gb $gbk \
    -o $prefix $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mummer2circos: 1.4.2
    END_VERSIONS

    """
}
