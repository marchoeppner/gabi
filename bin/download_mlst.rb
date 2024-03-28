require 'optparse'
require 'ostruct'
require 'rest_client'
require 'json'

def rest_get(url)
    $request_counter ||= 0   # Initialise if unset
    $last_request_time ||= 0 # Initialise if unset

    # Rate limiting: Sleep for the remainder of a second since the last request on every third request
    $request_counter += 1
    if $request_counter == 15 
        diff = Time.now - $last_request_time
        sleep(1-diff) if diff < 1
        $request_counter = 0
    end

    begin
        response = RestClient.get "#{$server}/#{url}", {:accept => :json}

        $last_request_time = Time.now
        JSON.parse(response)
    rescue RestClient::Exception => e
        puts "Failed for #{url}! #{response ? "Status code: #{response}. " : ''}Reason: #{e.message}"

        # Sleep for specified number of seconds if there is a Retry-After header
        if e.response.headers[:retry_after]
            sleep(e.response.headers[:retry_after].to_f)
            retry # This retries from the start of the begin block
        else
            abort("Quitting... #{e.inspect}")
        end
    end
end

def clean_url(url)
    return url.gsub("https://rest.pubmlst.org/","")
end
### Get the script arguments and open relevant files
options = OpenStruct.new()
opts = OptionParser.new()
opts.on("-s","--set_id", "=SETID","Get info for this set") {|argument| options.set_id = argument }
opts.on("-o","--outfile", "=OUTFILE","Output file") {|argument| options.outfile = argument }
opts.on("-h","--help","Display the usage information") {
    puts opts
    exit
}

opts.parse! 

$server = 'https://rest.pubmlst.org/'

info = rest_get("db")

banned = [ "rMLST", "test"]

info.each do |i|
    
    full_name = i["description"]
    name = i["name"]
    
    warn "#{name} | #{full_name}"

    next if banned.include?(name)

    databases = i["databases"].select{|d| d["href"].include?("seqdef") }

    databases.each do |database|

        entry = rest_get(clean_url(database["href"]))

        schemas = rest_get(clean_url(entry["schemes"]))
    
        mlsts = schemas["schemes"].select{|s| s["description"].include?("MLST") }

        mlsts.each do |this_mlst|

            schema = rest_get(clean_url(this_mlst["scheme"]))

            desc = schema["description"]

            mlst = desc.gsub(" ", "_").gsub(/[(,)]/, "").gsub("/", "").downcase

            profile_name = "#{name}_#{mlst}"

            next if mlst.include?("gmlst")

            command = "wget -O #{name}_#{mlst}_profiles_csv #{schema['profiles_csv']}"

            puts command

            loci = schema["loci"]

            list = []

            loci.each do |locus|

                l = rest_get(clean_url(locus))

                locus_name = l["id"]

                fasta = locus_name + ".fasta"

                list << fasta
                
                command = "wget -O #{fasta} #{l["alleles_fasta"]}"
                puts command

            end

            command = "claMLST create #{profile_name} #{profile_name}_profiles_csv #{list.join(' ')}"
            puts command

        end
    end

end
