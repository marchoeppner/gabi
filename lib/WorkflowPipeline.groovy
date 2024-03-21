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
        if (!params.valid_ont_version.contains(params.ont_version)) {
            log.info "Provided an invalid ONT version. Allowed options are ${params.valid_ont_version.join(',')}"
            System.exit(1)
        }
    }

}
