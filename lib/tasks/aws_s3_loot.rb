module Intrigue
module Task
class AwsS3Loot < BaseTask

  include Intrigue::Task::Web

  def self.metadata
    {
      :name => "aws_s3_loot",
      :pretty_name => "AWS S3 Loot",
      :authors => ["jcran"],
      :description => "This task takes an S3 bucket and gathers all URIs.",
      :references => [],
      :type => "enrichment",
      :passive => true,
      :allowed_types => ["AwsS3Bucket"],
      :example_entities => [
        {"type" => "AwsS3Bucket", "details" => {"name" => "https://s3.amazonaws.com/bucket"}}
      ],
      :allowed_options => [
        {:name => "flag_large_files", :type => "Boolean", :regex => "boolean", :default => true },
        {:name => "large_file_size", :type => "Integer", :regex => "integer", :default => 25}
      ],
      :created_types => ["DnsRecord"]
    }
  end

  ## Default method, subclasses must override this
  def run
    super

    # TODO - HMM... capitalization matters. grab the uri for now, but
    # we should think about how to handle this...
    bucket_uri = _get_entity_attribute "uri" || _get_entity_name
    bucket_uri.chomp!("/")

    unless bucket_uri =~ /s3.amazonaws.com/
      _log_error "Not an Amazon S3 link?"
      return
    end

    # DO THE BRUTEFORCE
    # TODO - this is very naive right now, and will miss
    # large swaths of files that have similar names. make a point
    # of making this much smarter without doing too much bruting...
    # we'll need to be smart about how we expand the brute set
    contents = []
    [*('a'..'z'),*('A'..'Z'),*('0'..'9')].each do |letter|
      result = get_contents_unauthenticated(bucket_uri,letter)
      contents.concat(result) if result
    end

    @entity.set_detail("contents", contents.sort.uniq)
  end

  def get_contents_unauthenticated(s3_uri, prefix)
    full_uri = "#{s3_uri}?prefix=#{prefix}&max-keys=1000"

    result = http_get_body("#{full_uri}")
    return unless result

    doc = Nokogiri::HTML(result)
    if  ( doc.xpath("//code").text =~ /NoSuchBucket/ ||
          doc.xpath("//code").text =~ /InvalidBucketName/ ||
          doc.xpath("//code").text =~ /AllAccessDisabled/ ||
          doc.xpath("//code").text =~ /AccessDenied/
          doc.xpath("//code").text =~ /PermanentRedirect/ )
      _log_error "Got response: #{doc.xpath("//code").text} (#{s3_uri})"
    else
      contents = []
      doc.xpath("//contents").each do |item|

        key = item.xpath("key").text
        size = item.xpath("size").text.to_i
        item_uri = "#{s3_uri}/#{key}"
        _log "Got: #{item_uri} (#{size*1.0/1000000}MB)"

        if _get_option "flag_large_files"
          flag_file_size = _get_option("large_file_size")
          if size * 1.0 / 1000000 > flag_file_size
            _log_good "Flagging large file of size #{size}: #{key}"
            # create an entity
            _create_entity "Uri", {
              "name" => "#{item_uri}",
              "uri" => "#{item_uri}",
              "file_size"=> size,
              "comment" => "Created by aws_s3_loot, size greater than #{flag_file_size}"
            }
          end
        end

        contents << "#{item_uri}"
      end
    end

  contents # will be nil if we got nothing
  end

end
end
end
