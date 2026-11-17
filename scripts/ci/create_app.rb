# produce currently does not support API keys. Check capability explicitly so
# runners never fall back to an interactive Apple ID/password login.
require 'produce'
require 'spaceship'
require 'yaml'

begin
  options = Produce::Options.available_options.map(&:key)
  unless options.include?(:api_key)
    abort 'Missing App Store Connect app record. Installed fastlane produce does not support API key authentication. Create FurnacePath in App Store Connect with the project bundle ID, then dispatch again.'
  end
  project = YAML.load_file('project.yml')
  bundle_id = project.fetch('targets').fetch('FurnacePath').fetch('settings').fetch('base').fetch('PRODUCT_BUNDLE_IDENTIFIER')
  Produce.config = FastlaneCore::Configuration.create(Produce::Options.available_options, {
    api_key: {key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'),
              filepath: ENV.fetch('ASC_KEY_PATH'), in_house: false},
    app_identifier: bundle_id, app_name: 'FurnacePath', sku: bundle_id,
    language: 'English', skip_devcenter: true
  })
  Produce::Manager.start
rescue StandardError
  abort 'App record creation with fastlane produce failed; no interactive credentials will be requested.'
end
