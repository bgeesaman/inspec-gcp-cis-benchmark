# encoding: utf-8
# Copyright 2019 The inspec-gcp-cis-benchmark Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

title 'Ensure Encryption keys are rotated within a period of 365 days'

gcp_project_id = attribute('gcp_project_id')
cis_version = attribute('cis_version')
cis_url = attribute('cis_url')
control_id = "1.8"
control_abbrev = "iam"
kms_rotation_period_seconds = attribute('kms_rotation_period_seconds')

control "cis-gcp-#{control_id}-#{control_abbrev}" do
  impact 1.0

  title "[#{control_abbrev.upcase}] Ensure Encryption keys are rotated within a period of 365 days"

  desc "Google Cloud Key Management Service stores cryptographic keys in a hierarchical structure designed for useful and elegant access control management. Access to resources.

The format for the rotation schedule depends on the client library that is used. For the gcloud command-line tool, the next rotation time must be in ISO or RFC3339 format, and the rotation period must be in the form INTEGER[UNIT], where units can be one of seconds (s), minutes (m), hours (h) or days (d)."

  desc "rationale", "Set a key rotation period and starting time. A key can be created with a specified rotation period, which is the time between when new key versions are generated automatically. A key can also be created with a specified next rotation time. A key is a named object representing a cryptographic key used for a specific purpose. The key material, the actual bits used for encryption, can change over time as new key versions are created.

A key is used to protect some corpus of data. You could encrypt a collection of files with the same key, and people with decrypt permissions on that key would be able to decrypt those files. Hence it's necessary to make sure rotation period is set to specific time."

  tag cis_scored: true
  tag cis_level: 1
  tag cis_gcp: "#{control_id}"
  tag cis_version: "#{cis_version}"
  tag project: "#{gcp_project_id}"

  ref "CIS Benchmark", url: "#{cis_url}"
  ref "GCP Docs", url: "https://cloud.google.com/kms/docs/key-rotation#frequency_of_key_rotation"

  # Get all "normal" regions and add "global"
  locations = google_compute_regions(project: gcp_project_id).region_names
  locations << 'global'
 
  locations.each do |location|
    google_kms_key_rings(project: gcp_project_id, location: location).key_ring_names.each do |keyring|
      google_kms_crypto_keys(project: gcp_project_id, location: location, key_ring_name: keyring).crypto_key_names.each do |keyname|
        key = google_kms_crypto_key(project: gcp_project_id, location: location, key_ring_name: keyring, name: keyname)
        if key.primary_state == "ENABLED"
          describe "[#{gcp_project_id}] #{key.name.to_s.sub('projects/', '').sub('locations/','').sub('keyRings/','')}" do
            subject { key }
            its('rotation_period_seconds') { should be <= kms_rotation_period_seconds }
            its('next_rotation_time_date') { should be <= (Time.now + kms_rotation_period_seconds) }
          end
        end
      end
    end
  end
end
