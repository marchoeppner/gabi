include { KRAKEN2_KRAKEN2 }     from './../../modules/kraken2/kraken2'

ch_versions = Channel.from([])

workflow TAXONOMY_PROFILING {
    take:
    reads
    kraken2_db

    main:

    KRAKEN2_KRAKEN2(
        reads,
        kraken2_db,
        false,
        false
    )
    ch_versions = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions)

    KRAKEN2_KRAKEN2.out.report.map { m, r ->
        newMeta = [:]
        newMeta.sample_id = m.sample_id
        newMeta.platform = m.platform
        newMeta.single_end = m.single_end
        (taxon, domain, fraction) = extract_taxon(r)
        newMeta.taxon = taxon
        newMeta.domain = domain
        newMeta.fraction = fraction
        [ newMeta, r ]
    }.set { report_with_taxon }

    report_with_taxon.branch { m,r ->
        pass: m.fraction >= 75.0
        fail: m.fraction < 75.0
    }.set { report_with_taxon_status }

    report_with_taxon_status.fail.subscribe { m,r ->
        log.warn "${m.sample_id} - weak taxonomic assignment (${m.fraction})!"
    }

    emit:
    report = report_with_taxon
    versions = ch_versions
    }

/* This reads the Kraken taxonomy assignment file to:
- find the most probable species assignment
- find the most probable domain assignment
using the first occurence of a species assignment (which is the most abundant hit)
Yes, this is crude.
*/
def extract_taxon(aFile) {
    def taxon = 'unknown'
    def domain = 'unknown'
    def fraction = 0.0

    aFile.eachLine { line ->
        def elements = line.trim().split(/\s+/)

        // Kraken2 has a laughable data format, let's try to find the first species-level assignment...
        if (elements[3] == 'S' && taxon == 'unknown') {
            
            //if (fraction >= 30.0) {
                taxon = elements[5..-1].join(' ').trim()
                
                fraction = Float.parseFloat(elements[0])
            //}
        }
        if (elements[3] == 'D' && domain == 'unknown') {
            //if (fraction >= 40) {
                domain = elements[5..-1].join(' ').trim()
            //}
        }
    }
    return [ taxon, domain, fraction ]
}
