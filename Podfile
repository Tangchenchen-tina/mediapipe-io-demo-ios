platform :ios, '17.0'

target 'MediaPipeIODemo' do
  use_frameworks!

  # TextSummarizer, TextProofreader, TextEmbedder all live in this one pod.
  pod 'MediaPipeTasksText'

  # Deliberately NOT giving MediaPipeIODemoTests its own `inherit! :search_paths` link to this
  # pod: the unit tests only exercise pure-Swift logic (WordDiff, VectorIndex) via
  # `@testable import`, which already pulls in the app module (and therefore MediaPipeTasksText)
  # transitively. Linking it a second time directly into the test bundle causes MediaPipe's
  # native calculators to register themselves twice, crashing with "Function with name
  # FlowLimiterCalculator already registered" before any test runs.
end
