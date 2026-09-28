# Adiciona ao Runner.xcodeproj os targets CallBlockerExtension e QuickNotesWidget,
# com os arquivos que já estão em ios/<target>/, e embute os dois no Runner.
# Substitui a configuração manual no Xcode. Idempotente: não mexe no que já existe.
#
# Uso (em um Mac ou no runner macOS do CI): cd ios && bundle exec ruby scripts/add_extension_targets.rb
require "xcodeproj"

IOS_DIR = File.expand_path("..", __dir__)
APP_ID = "com.ramonmachadocarmo.mobileUtils"
DEPLOYMENT_TARGET = "14.0"
EXTENSIONS = %w[CallBlockerExtension QuickNotesWidget].freeze

project = Xcodeproj::Project.open(File.join(IOS_DIR, "Runner.xcodeproj"))
runner = project.targets.find { |t| t.name == "Runner" } or abort "Target Runner não encontrado"

def file_ref(group, path)
  group.files.find { |f| f.real_path.to_s == path } || group.new_file(path)
end

# Runner: entitlements com o App Group.
runner_group = project.main_group["Runner"]
file_ref(runner_group, File.join(IOS_DIR, "Runner/Runner.entitlements"))
runner.build_configurations.each do |config|
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Runner.entitlements"
end

ext_xcconfig = file_ref(project.main_group["Flutter"], File.join(IOS_DIR, "Flutter/Extension.xcconfig"))

embed = runner.copy_files_build_phases.find { |p| p.name == "Embed Foundation Extensions" } ||
        runner.new_copy_files_build_phase("Embed Foundation Extensions")
embed.symbol_dst_subfolder_spec = :plug_ins

EXTENSIONS.each do |name|
  if project.targets.any? { |t| t.name == name }
    puts "#{name}: já existe, pulando"
    next
  end

  target = project.new_target(:app_extension, name, :ios, DEPLOYMENT_TARGET, project.products_group, :swift)

  # O Flutter usa Debug/Release/Profile; o xcodeproj só cria Debug/Release.
  project.build_configurations.each do |config|
    next if target.build_configurations.any? { |c| c.name == config.name }
    target.add_build_configuration(config.name, :release)
  end

  dir = File.join(IOS_DIR, name)
  group = project.main_group[name] || project.main_group.new_group(name, dir)
  Dir.glob(File.join(dir, "*")).sort.each do |path|
    ref = file_ref(group, path)
    target.add_file_references([ref]) if path.end_with?(".swift")
  end

  target.build_configurations.each do |config|
    config.base_configuration_reference = ext_xcconfig
    config.build_settings.merge!(
      "PRODUCT_BUNDLE_IDENTIFIER" => "#{APP_ID}.#{name}",
      "PRODUCT_NAME" => "$(TARGET_NAME)",
      "INFOPLIST_FILE" => "#{name}/Info.plist",
      "GENERATE_INFOPLIST_FILE" => "YES",
      "CODE_SIGN_ENTITLEMENTS" => "#{name}/#{name}.entitlements",
      "CODE_SIGN_STYLE" => "Automatic",
      "IPHONEOS_DEPLOYMENT_TARGET" => DEPLOYMENT_TARGET,
      # A App Store exige que as extensions tenham a mesma versão do app.
      "MARKETING_VERSION" => "$(FLUTTER_BUILD_NAME)",
      "CURRENT_PROJECT_VERSION" => "$(FLUTTER_BUILD_NUMBER)",
      "SWIFT_VERSION" => "5.0",
      "TARGETED_DEVICE_FAMILY" => "1,2",
      "SKIP_INSTALL" => "YES",
      "APPLICATION_EXTENSION_API_ONLY" => "YES",
      "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
    )
  end

  runner.add_dependency(target)
  embed.add_file_reference(target.product_reference, true).settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
  puts "#{name}: target criado"
end

# O embed das extensions precisa vir antes do "Thin Binary" do Flutter, senão o
# Xcode acusa ciclo de dependência.
phases = runner.build_phases
phases.delete(embed)
thin_binary = phases.index { |p| p.respond_to?(:name) && p.name == "Thin Binary" } || phases.size
phases.insert(thin_binary, embed)

project.save
puts "Runner.xcodeproj salvo"
