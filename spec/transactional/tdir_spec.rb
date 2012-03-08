require 'spec_helper'

describe Transactional::TDir do
  let(:tdir) { Transactional::TDir.new(filesystem_root, testdir_rpath) }

  before { create_empty_filesytem }

  it "creates a directory" do
    tdir.create
    testdir.should be_present
  end
end
