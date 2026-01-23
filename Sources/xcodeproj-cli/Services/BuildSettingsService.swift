//
// BuildSettingsService.swift
// xcodeproj-cli
//

import Foundation
@preconcurrency import XcodeProj

/// Service for build settings management
@MainActor
final class BuildSettingsService {
  private let pbxproj: PBXProj
  private let cacheManager: CacheManager
  private let profiler: PerformanceProfiler?

  init(
    pbxproj: PBXProj,
    cacheManager: CacheManager,
    profiler: PerformanceProfiler? = nil
  ) {
    self.pbxproj = pbxproj
    self.cacheManager = cacheManager
    self.profiler = profiler
  }

  // MARK: - Build Settings Management

  func setBuildSetting(key: String, value: String, targets: [String], configuration: String? = nil)
  {
    for targetName in targets {
      guard let target = cacheManager.getTarget(targetName),
        let configList = target.buildConfigurationList
      else {
        print("⚠️  Target '\(targetName)' not found")
        continue
      }

      for config in configList.buildConfigurations {
        if let filterConfig = configuration, config.name != filterConfig {
          continue
        }
        config.buildSettings[key] = .string(value)
        print("⚙️  Set \(key) = \(value) for \(targetName) - \(config.name)")
      }
    }
  }

  func getBuildSettings(for targetName: String, configuration: String? = nil) -> [String: [String:
    Any]]
  {
    guard let target = cacheManager.getTarget(targetName),
      let configList = target.buildConfigurationList
    else {
      print("⚠️  Target '\(targetName)' not found")
      return [:]
    }

    var result: [String: [String: Any]] = [:]

    for config in configList.buildConfigurations {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }
      result[config.name] = config.buildSettings
    }

    return result
  }

  func listBuildConfigurations(for targetName: String? = nil) {
    if let targetName = targetName {
      guard let target = cacheManager.getTarget(targetName) else {
        print("⚠️  Target '\(targetName)' not found")
        return
      }

      print("🔧 Build configurations for \(targetName):")
      if let configList = target.buildConfigurationList {
        for config in configList.buildConfigurations {
          print("  - \(config.name)")
        }
      }
    } else {
      // List all project configurations
      print("🔧 Project build configurations:")
      if let configList = pbxproj.rootObject?.buildConfigurationList {
        for config in configList.buildConfigurations {
          print("  - \(config.name)")
        }
      }
    }
  }

  func removeBuildSetting(key: String, targets: [String], configuration: String? = nil) {
    for targetName in targets {
      guard let target = cacheManager.getTarget(targetName),
        let configList = target.buildConfigurationList
      else {
        print("⚠️  Target '\(targetName)' not found")
        continue
      }

      for config in configList.buildConfigurations {
        if let filterConfig = configuration, config.name != filterConfig {
          continue
        }
        config.buildSettings.removeValue(forKey: key)
        print("🗑️  Removed \(key) from \(targetName) - \(config.name)")
      }
    }
  }

  func updateBuildSettings(targets: [String], update: (inout BuildSettings) -> Void) {
    for targetName in targets {
      guard let target = cacheManager.getTarget(targetName),
        let configList = target.buildConfigurationList
      else {
        print("⚠️  Target '\(targetName)' not found")
        continue
      }

      for config in configList.buildConfigurations {
        var settings = config.buildSettings
        update(&settings)
        config.buildSettings = settings
      }
    }
  }

  // MARK: - Build Settings Display

  func listBuildSettings(
    targetName: String? = nil, configuration: String? = nil, showInherited: Bool = false,
    outputJSON: Bool = false, showAll: Bool = false
  ) {
    if outputJSON {
      outputJSONBuildSettings(
        targetName: targetName, configuration: configuration,
        showInherited: showInherited, showAll: showAll
      )
      return
    }

    outputConsoleBuildSettings(
      targetName: targetName, configuration: configuration,
      showInherited: showInherited, showAll: showAll
    )
  }

  // MARK: - Private Helper Methods

  private func outputJSONBuildSettings(
    targetName: String? = nil, configuration: String? = nil,
    showInherited: Bool = false, showAll: Bool = false
  ) {
    listBuildSettingsJSON(
      targetName: targetName, configuration: configuration,
      showInherited: showInherited, showAll: showAll
    )
  }

  private func outputConsoleBuildSettings(
    targetName: String? = nil, configuration: String? = nil,
    showInherited: Bool = false, showAll: Bool = false
  ) {
    if showAll {
      listAllBuildSettings(configuration: configuration, showInherited: showInherited)
      return
    }

    if let targetName = targetName {
      outputTargetBuildSettings(
        targetName: targetName, configuration: configuration, showInherited: showInherited
      )
    } else {
      outputProjectBuildSettings(configuration: configuration)
    }
  }

  private func listBuildSettingsJSON(
    targetName: String? = nil, configuration: String? = nil,
    showInherited: Bool = false, showAll: Bool = false
  ) {
    // JSON output implementation would go here
    // For now, use dictionary output
    if let targetName = targetName {
      let settings = getBuildSettings(for: targetName, configuration: configuration)
      let jsonSafeSettings = convertBuildSettingsForJSON(settings)

      // Don't output empty JSON if no settings found
      guard !jsonSafeSettings.isEmpty else { return }

      if let jsonData = try? JSONSerialization.data(
        withJSONObject: jsonSafeSettings, options: [.prettyPrinted, .sortedKeys]),
        let jsonString = String(data: jsonData, encoding: .utf8)
      {
        print(jsonString)
      }
    } else {
      // Output project settings
      let settings = collectProjectBuildSettings(configuration: configuration)
      let jsonSafeSettings = convertBuildSettingsForJSON(settings.settingsData)

      // Don't output empty JSON if no settings found
      guard !jsonSafeSettings.isEmpty else { return }

      if let jsonData = try? JSONSerialization.data(
        withJSONObject: jsonSafeSettings, options: [.prettyPrinted, .sortedKeys]),
        let jsonString = String(data: jsonData, encoding: .utf8)
      {
        print(jsonString)
      }
    }
  }

  private func listAllBuildSettings(configuration: String?, showInherited: Bool) {
    print("🔧 Build Settings for All Targets")
    print("=" + String(repeating: "=", count: 80))

    for target in pbxproj.nativeTargets {
      outputTargetBuildSettings(
        targetName: target.name, configuration: configuration, showInherited: showInherited)
      print("")
    }
  }

  private func outputTargetBuildSettings(
    targetName: String, configuration: String? = nil, showInherited: Bool = false
  ) {
    guard let target = cacheManager.getTarget(targetName) else {
      print("⚠️  Target '\(targetName)' not found")
      print("Available targets: \(pbxproj.nativeTargets.map { $0.name }.joined(separator: ", "))")
      return
    }

    print("🎯 Build Settings for Target: \(targetName)")
    print("─" + String(repeating: "─", count: 80))

    guard let configList = target.buildConfigurationList else {
      print("  No build configurations found")
      return
    }

    for config in configList.buildConfigurations {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      print("\n📋 Configuration: \(config.name)")
      print("  " + String(repeating: "─", count: 78))

      let sortedKeys = config.buildSettings.keys.sorted()
      for key in sortedKeys {
        if let value = config.buildSettings[key] {
          print("  \(key) = \(formatBuildSettingValue(value))")
        }
      }
    }
  }

  private func outputProjectBuildSettings(configuration: String?) {
    print("🏗️  Project Build Settings")
    print("=" + String(repeating: "=", count: 80))

    guard let configList = pbxproj.rootObject?.buildConfigurationList else {
      print("  No build configurations found")
      return
    }

    var foundMatchingConfig = false
    for config in configList.buildConfigurations {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      foundMatchingConfig = true
      print("\n📋 Configuration: \(config.name)")
      print("  " + String(repeating: "─", count: 78))

      let sortedKeys = config.buildSettings.keys.sorted()
      for key in sortedKeys {
        if let value = config.buildSettings[key] {
          print("  \(key) = \(formatBuildSettingValue(value))")
        }
      }
    }

    if let filterConfig = configuration, !foundMatchingConfig {
      print("  No build configuration found matching '\(filterConfig)'")
    }
  }

  private func collectProjectBuildSettings(
    configuration: String? = nil
  ) -> (settingsData: [String: [String: Any]], allKeys: Set<String>, activeConfigs: [String]) {
    guard let configList = pbxproj.rootObject?.buildConfigurationList else {
      return ([:], [], [])
    }

    let configs = configList.buildConfigurations
    let configNames = configs.map { $0.name }

    var allSettingKeys = Set<String>()
    var settingsData: [String: [String: Any]] = [:]

    for config in configs {
      if let filterConfig = configuration, config.name != filterConfig {
        continue
      }

      settingsData[config.name] = config.buildSettings
      allSettingKeys.formUnion(config.buildSettings.keys)
    }

    return (settingsData, allSettingKeys, configNames)
  }

  private func convertBuildSettingsForJSON(_ settings: [String: [String: Any]]) -> [String: [String:
    Any]]
  {
    var result: [String: [String: Any]] = [:]

    for (configName, configSettings) in settings {
      var jsonSafeSettings: [String: Any] = [:]

      for (key, value) in configSettings {
        // Convert BuildSetting enum to JSON-compatible types
        if let buildValue = value as? BuildSetting {
          switch buildValue {
          case .string(let str):
            jsonSafeSettings[key] = str
          case .array(let arr):
            jsonSafeSettings[key] = arr
          }
        } else {
          // Regular values pass through
          jsonSafeSettings[key] = value
        }
      }

      result[configName] = jsonSafeSettings
    }

    return result
  }

  private func formatBuildSettingValue(_ value: Any) -> String {
    if let stringValue = value as? String {
      return stringValue
    } else if let arrayValue = value as? [String] {
      return arrayValue.joined(separator: ", ")
    } else {
      return "\(value)"
    }
  }
}
