include { KRAKEN2_KRAKEN2 }     from "./../../modules/kraken2/kraken2"

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

    KRAKEN2_KRAKEN2.out.report.map { m,r ->
        newMeta = [:]
        newMeta.sample_id = m.sample_id
        newMeta.platform = m.platform
        newMeta.single_end = m.single_end
        (taxon, domain) = extract_taxon(r)
        newMeta.taxon = taxon
        newMeta.domain = domain
        [ newMeta, r ]
    }.set { report_with_taxon }
        
    emit:
    report = report_with_taxon
}

def extract_taxon(aFile) {
    taxon = "unknown"
    domain = "unknown"
    aFile.eachLine { line ->
        def elements = line.trim().split(/\s+/)

        // Kraken2 has a laughable data format, let's try to find the first species-level assignment...
        if (elements[3] == "S" && taxon == "unknown") {
            def fraction = Float.parseFloat(elements[0])
            if (fraction >= 60.0) {
                taxon = elements[5..-1].join(" ")
            }
        }
        if (elements[3] == "D" && domain == "unknown") {
            def fraction = Float.parseFloat(elements[0])
            if (fraction >= 60) {
                domain = elements[5..-1].join(" ")
            }
        }
    }
    return [ taxon, domain ]
}