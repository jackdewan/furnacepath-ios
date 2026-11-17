# Never log tokens, key material, or exception objects containing request headers.
require 'spaceship'
require 'openssl'
require 'base64'

begin
  token = Spaceship::ConnectAPI::Token.create(
    key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'),
    filepath: ENV.fetch('ASC_KEY_PATH'), in_house: false
  )
  Spaceship::ConnectAPI.token = token
  team = ENV['TEAM_ID'].to_s
  if team.empty?
    teams = Spaceship::ConnectAPI::Certificate.all.filter_map do |cert|
      next unless cert.certificate_content
      certificate = OpenSSL::X509::Certificate.new(Base64.decode64(cert.certificate_content))
      certificate.subject.to_a.find { |entry| entry[0] == 'OU' }&.[](1)
    end.uniq
    abort 'Cannot uniquely discover signing team. Set repository variable APPLE_TEAM_ID or dispatch input team_id.' unless teams.length == 1
    team = teams.first
  end
  abort 'Invalid Apple Developer Team ID.' unless team.match?(/\A[A-Z0-9]{10}\z/)
  File.open(ENV.fetch('GITHUB_ENV'), 'a') { |f| f.puts "TEAM_ID=#{team}" }
  puts 'App Store Connect authentication and signing team prepared.'
rescue StandardError
  abort 'App Store Connect signing preparation failed. Check API key validity, provisioning permissions, and Apple Developer membership.'
end
