SPEC_HOME = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(SPEC_HOME, "..", "lib")
$: << lib_dir

require 'fileutils'
require 'transactional'
