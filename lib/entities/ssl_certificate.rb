module Intrigue
module Entity
class SslCertificate < Intrigue::Model::Entity

  def self.metadata
    {
      :name => "SslCertificate",
      :description => "An SSL Certificate",
      :user_creatable => false
    }
  end

  def validate_entity
    name =~ /^.*$/
  end

  def detail_string
    "#{details["issuer"]}"
  end
end
end
end
