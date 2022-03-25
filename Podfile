platform :ios, '14.0'

target 'Wefox Pokedex' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  inhibit_all_warnings!
  
  pod 'Moya'
  pod 'Haneke', :git => 'https://github.com/ronanociosoig/Haneke.git'
  pod 'JGProgressHUD', :git => 'https://github.com/ronanociosoig/JGProgressHUD.git'

  # Pods for Wefox Pokedex

  target 'Wefox PokedexTests' do
    inherit! :search_paths
    # Pods for testing
  end
  
end

target 'Wefox PokedexUITests' do
  use_frameworks!
  inhibit_all_warnings!
  
  pod 'Haneke', :git => 'https://github.com/ronanociosoig/Haneke.git'
  pod 'JGProgressHUD', :git => 'https://github.com/ronanociosoig/JGProgressHUD.git'
  pod 'Moya'
end

