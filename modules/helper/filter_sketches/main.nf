process FILTER_SKETCHES {

    tag "${meta.sample_id}"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/perl-json-xs:4.03--pl5321h4ac6f70_2' :
        'quay.io/biocontainers/perl-json-xs:4.03--pl5321h4ac6f70_2' }"

    input:
    tuple val(meta), path(report)

    output:
    tuple val(meta),path(result)    , emit: txt
    tuple val(meta),env(ACCESSION)  , emit: acc
    path 'versions.yml'             , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    result = prefix + '.taxon.txt'

    """
    filter_sketches.pl --infile $report --outfile $result

    ACCESSION="\$(cat $result)"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        perl: \$(perl --version  | head -n2 | tail -n1 | sed -e "s/.*(//" -e "s/).*//")
    END_VERSIONS
    """
}
