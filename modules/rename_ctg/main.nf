process RENAME_CTG {
    tag "$meta.sample_id"
    label 'short_serial'

    input:
    tuple val(meta), path(assembly)
    val file_ext

    output:
    tuple val(meta), path('*')

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''
    prefix       = task.ext.prefix ?: "${meta.sample_id}"
    """
    mv \
        $args \
        ${assembly} \
        ${prefix}.${file_ext}
    """
}
