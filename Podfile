# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'gaios' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Green
  pod 'PromiseKit', '6.2.3'
  pod 'NVActivityIndicatorView', '4.6.1'
  target 'gaiosTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'gaiosUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
    end
  end
end
