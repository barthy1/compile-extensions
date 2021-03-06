require 'spec_helper'
require 'open3'

describe 'default_version_for' do
  def default_version_for(buildpack_directory, manifest_path, dependency_name)
    Open3.capture3("#{buildpack_directory}/compile-extensions/bin/default_version_for #{manifest_path} #{dependency_name}")
  end

  let(:buildpack_directory)    { Dir.mktmpdir }
  let(:dependency_name)        { 'Testlang' }
  let(:manifest_path)          { File.join(buildpack_directory, 'manifest.yml') }
  let(:defaults_error_message) { "The buildpack manifest is misconfigured for defaults. " +
                                 "Contact your Cloud Foundry operator/admin. For more information, " +
                                 "see https://docs.cloudfoundry.org/buildpacks/specifying-default-versions" }

  before do
    base_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
    `cp -a #{base_dir} #{buildpack_directory}/compile-extensions`
    File.open(manifest_path, 'w') do |file|
      file.write(manifest_contents)
    end
  end

  context "manifest with correct default for the requested dependency" do
    let(:manifest_contents) { <<-MANIFEST
---
default_versions:
  - name: Testlang
    version: 11.0.1
  - name: SomethingElse
    version: 0.0.1

dependencies:
  - name: Testlang
    version: 1.0.1
  - name: Testlang
    version: 5.0.1
  - name: Testlang
    version: 11.0.1
      MANIFEST
    }

    it 'returns the default version set in the manifest for the dependency' do
      default_version, _, status = default_version_for(buildpack_directory, manifest_path, dependency_name)
      expect(status.exitstatus).to eq 0
      expect(default_version).to eq '11.0.1'
    end
  end

  shared_examples_for "erroring with helpful defaults misconfiguration message" do
    it 'errors out with a helpful buildpack manifest defaults is misconfigured message' do
      _, error_message, status = default_version_for(buildpack_directory, manifest_path, dependency_name)
      expect(status.exitstatus).to eq 1
      expect(error_message).to include defaults_error_message
    end
  end

  context "manifest with multiple defaults for the requested dependency" do
    let(:manifest_contents) { <<-MANIFEST
---
default_versions:
  - name: Testlang
    version: 11.0.1
  - name: Testlang
    version: 11.0.2
  - name: SomethingElse
    version: 0.0.1

dependencies:
  - name: Testlang
    version: 1.0.1
  - name: Testlang
    version: 5.0.1
  - name: Testlang
    version: 11.0.1
      MANIFEST
    }

    it_behaves_like "erroring with helpful defaults misconfiguration message"
  end

  context "manifest with a default that has no matching dependency" do
    context "where the name is missing" do
      let(:manifest_contents) { <<-MANIFEST
---
default_versions:
  - name: Testlang
    version: 11.0.1
  - name: SomethingElse
    version: 0.0.1

dependencies:
  - name: SomethingElse
    version: 0.0.1
      MANIFEST
      }

      it_behaves_like "erroring with helpful defaults misconfiguration message"
    end

    context "where the version is missing" do
      let(:manifest_contents) { <<-MANIFEST
---
default_versions:
  - name: Testlang
    version: 11.0.1
  - name: SomethingElse
    version: 0.0.1

dependencies:
  - name: Testlang
    version: 11.0.2
  - name: SomethingElse
    version: 0.0.1
      MANIFEST
      }

      it_behaves_like "erroring with helpful defaults misconfiguration message"
    end
  end

  context "manifest with no default for the requested dependency" do
    let(:manifest_contents) { <<-MANIFEST
---
default_versions:
  - name: SomethingElse
    version: 0.0.1

dependencies:
  - name: Testlang
    version: 11.0.2
  - name: SomethingElse
    version: 0.0.1
      MANIFEST
    }

    it_behaves_like "erroring with helpful defaults misconfiguration message"
  end
end
