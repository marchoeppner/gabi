process GABI_SUMMARY {

    tag "${meta.sample_id}"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/perl-json-xs:4.03--pl5321h4ac6f70_2' :
        'quay.io/biocontainers/perl-json-xs:4.03--pl5321h4ac6f70_2' }"

    input:
    tuple val(meta), path(kraken),path(mlst),path(quast)

    output:
    path('*.json')          , emit: json
    path 'versions.yml'     , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    result = prefix + '.json'

    def options = ""
    if (kraken) {
        options = options.concat(" --kraken $kraken")
    }
    if (mlst) {
        options = options.concat(" --mlst $mlst")
    }
    if (quast) {
        options = options.concat(" --quast $quast")
    }

    """
    gabi_summary.pl --sample ${meta.sample_id} \
    $options \
    $args \
    --outfile $result

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        perl: \$(perl --version  | head -n2 | tail -n1 | sed -e "s/.*(//" -e "s/).*//")
    END_VERSIONS
    """
}
