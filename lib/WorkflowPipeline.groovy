//
// This file holds several functions specific to the workflow/esga.nf in the nf-core/esga pipeline
//

class WorkflowPipeline {

    //
    // Check and validate parameters
    //
    public static void initialise(params,  log) {
        if (!params.run_name) {
            log.info 'Must provide a run_name (--run_name)'
            System.exit(1)
        }
        if (!params.reference_base) {
            log.info "No --reference_base specified, cannot proceed!"
            System.exit(1)
        }
        if (params.reference_fasta && !params.reference_gff || !params.reference_fasta && params.reference_gff ) {
            log.info "You need to provide both a reference FASTA file and reference GFF file for Quast."
            System.exit(1)
        }
    }

}
