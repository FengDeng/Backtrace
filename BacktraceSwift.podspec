Pod::Spec.new do |s|
  s.name             = 'Backtrace'
  s.version          = '0.1.0'
  s.summary          = 'backtrace for iOS thread.'
  s.description      = <<-DESC
backtrace for iOS thread with swift.
                       DESC

  s.homepage         = 'https://github.com/FengDeng/Backtrace'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '邓锋' => 'raisechestnut@gmail.com' }
  s.source           = { :git => 'https://github.com/FengDeng/Backtrace.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.swift_versions = ['5', '5.1', '5.2']

  s.source_files = 'Backtrace/Classes/**/*'
  
end
